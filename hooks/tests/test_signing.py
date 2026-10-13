import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('signing', Path(__file__).parents[2] / 'scripts/prepare_android_signing.py')
signing = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(signing)


class SigningTests(unittest.TestCase):
    def test_java_properties_escape_special_characters(self):
        self.assertEqual(signing.property_value(' a\\b\né'), r'\ a\\b\n\u00e9')

    def test_existing_signature_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            values = dict(KEYSTORE_BASE64='dGVzdA==', STORE_PASSWORD='test', KEY_PASSWORD='test', KEY_ALIAS='test')
            signing.prepare(root, values)
            original = (root / 'android/app/release.jks').read_bytes()
            with self.assertRaises(FileExistsError):
                signing.prepare(root, values)
            self.assertEqual((root / 'android/app/release.jks').read_bytes(), original)

    def test_missing_configuration_creates_no_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(ValueError):
                signing.prepare(root, {})
            self.assertEqual(list(root.iterdir()), [])
