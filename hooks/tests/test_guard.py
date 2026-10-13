import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('guard', Path(__file__).parents[1] / 'check.py')
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


class GuardTests(unittest.TestCase):
    def setUp(self):
        # Git hooks may export the real repository/index. Fixture repositories
        # must never inherit those paths or stage the contributor's own files.
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith('GIT_')}
        isolated = patch.dict(os.environ, environment, clear=True)
        isolated.start()
        self.addCleanup(isolated.stop)

    def test_private_configuration_and_signing_material_are_rejected(self):
        for path in ('.env', 'app/.env.production', 'android/key.properties', 'release.jks'):
            self.assertTrue(guard.problems(path, b'example'))
        self.assertEqual(guard.problems('.env.example', b'SUPABASE_URL=https://example.com'), [])

    def test_service_role_token_is_rejected_but_public_anon_is_allowed(self):
        for role, expected in [('service_role', True), ('anon', False)]:
            payload = base64.urlsafe_b64encode(json.dumps({'role': role}).encode()).decode().rstrip('=')
            token = ('eyJhbGciOiJIUzI1NiJ9.' + payload + '.signature').encode()
            self.assertEqual(bool(guard.problems('config.dart', token)), expected)

    def test_private_key_is_rejected_without_disclosing_it(self):
        key = ('-----BEGIN ' + 'PRIVATE KEY-----\nsecret-body').encode()
        errors = guard.problems('config.txt', key)
        self.assertTrue(errors)
        self.assertNotIn('secret-body', str(errors))

    def test_binary_asset_is_not_decoded_as_secret_text(self):
        self.assertEqual(guard.problems('model.tflite', b'\x00\xff\xfe'), [])

    def test_index_content_is_checked_not_unstaged_replacement(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', directory], check=True)
            target = root / 'config.txt'
            target.write_text('-----BEGIN ' + 'PRIVATE KEY-----\nsecret-body', encoding='utf-8')
            subprocess.run(['git', 'add', '--', 'config.txt'], cwd=root, check=True)
            target.write_text('now harmless but not staged', encoding='utf-8')
            self.assertTrue(guard.inspect(root, staged=True))
            self.assertEqual(guard.inspect(root, staged=False), [])

    def test_deletion_of_committed_migration_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', directory], check=True)
            path = root / 'supabase/migrations/20260101000000_test.sql'
            path.parent.mkdir(parents=True)
            path.write_text('SELECT 1;', encoding='utf-8')
            subprocess.run(['git', 'add', '.'], cwd=root, check=True)
            subprocess.run(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                            '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'fixture'], cwd=root, check=True)
            subprocess.run(['git', 'rm', '-q', '--', str(path.relative_to(root))], cwd=root, check=True)
            self.assertTrue(any('migration' in error for error in guard.inspect(root, staged=True)))


if __name__ == '__main__':
    unittest.main()
