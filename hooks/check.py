#!/usr/bin/env python3
"""Read-only checks of Git blobs, including partially staged files."""
import argparse
import base64
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def git(*args, root=ROOT):
    return subprocess.run(
        ['git', *args], cwd=root, check=True, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def problems(path, content):
    """Return descriptions only: never include potentially secret values."""
    name = PurePosixPath(path).name.lower()
    errors = []
    if ((name == '.env' or name.startswith('.env.')) and name != '.env.example') or (
        name == 'key.properties' or name.endswith(('.jks', '.keystore', '.p12', '.pfx'))
    ):
        errors.append('configuration privee ou signature interdite dans Git')
    if len(content) > 50 * 1024 * 1024:
        errors.append('fichier superieur a 50 Mio : utiliser un stockage adapte')
    if b'\0' in content:
        return errors
    text = content.decode('utf-8', errors='replace')
    private_header = r'-----BEGIN (?:RSA |EC |OPENSSH )?' + r'PRIVATE KEY-----'
    if re.search(private_header, text):
        errors.append('cle privee probable')
    if re.search(r'\bsb_secret_[A-Za-z0-9_-]{20,}', text):
        errors.append('cle Supabase privilegiee probable')
    for token in re.findall(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', text):
        try:
            payload = token.split('.')[1]
            claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
            if isinstance(claims, dict) and claims.get('role') == 'service_role':
                errors.append('JWT service_role interdit dans le client/depot')
                break
        except (ValueError, UnicodeError):
            pass
    return errors


def is_migration(path):
    return path.startswith(('supabase/migrations/', 'dashboard/supabase/migrations/')) and path.endswith('.sql')


def inspect(root, staged=False, base=None):
    if staged:
        paths = git('diff', '--cached', '--name-only', '--diff-filter=ACM', '--no-renames', '-z', root=root)
    else:
        paths = git('ls-files', '--cached', '--others', '--exclude-standard', '-z', root=root)
    errors = []
    for raw in sorted(set(paths.split(b'\0')) - {b''}):
        path = raw.decode('utf-8')
        try:
            if staged:
                content = git('show', ':' + path, root=root)
            else:
                target = root / path
                if not target.is_file() or target.is_symlink():
                    continue
                content = target.read_bytes()
            errors.extend(f'{path}: {message}' for message in problems(path, content))
        except (OSError, subprocess.CalledProcessError) as error:
            errors.append(f'{path}: lecture impossible ({type(error).__name__})')
    if staged or base:
        comparison = ['--cached'] if staged else [base, 'HEAD']
        modified = git('diff', *comparison, '--name-only', '--diff-filter=MD', '--no-renames', '-z', root=root)
        for path in modified.decode('utf-8').split('\0'):
            if is_migration(path):
                errors.append(f'{path}: migration versionnee modifiee/supprimee ; ajouter une migration corrective')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--staged', action='store_true')
    mode.add_argument('--all', action='store_true')
    args = parser.parse_args()
    try:
        base = os.environ.get('QUALITY_BASE_SHA', '')
        if base and (not re.fullmatch(r'[0-9a-fA-F]{40}', base) or set(base) == {'0'}):
            base = None
        errors = inspect(ROOT, staged=args.staged, base=base or None)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f'Controle impossible : {type(error).__name__}', file=sys.stderr)
        return 2
    for error in errors:
        print(error, file=sys.stderr)
    if not errors:
        print('Repository guard: OK (controle limite, pas un audit de securite).')
    return int(bool(errors))


if __name__ == '__main__':
    sys.exit(main())
