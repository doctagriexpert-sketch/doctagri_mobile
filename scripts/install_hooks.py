#!/usr/bin/env python3
"""Activate repository hooks in this clone, preserving existing hook files."""
from pathlib import Path
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    existing = subprocess.run(['git', 'config', '--get', 'core.hooksPath'], cwd=ROOT,
                              capture_output=True, text=True)
    if existing.returncode not in (0, 1):
        print('Impossible de lire la configuration Git.', file=sys.stderr)
        return 1
    if existing.stdout.strip() not in ('', 'hooks'):
        print('core.hooksPath personnalise deja present ; aucune modification.', file=sys.stderr)
        return 1
    for name in ('pre-commit', 'pre-push'):
        path = ROOT / 'hooks' / name
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    subprocess.run(['git', 'config', '--local', 'core.hooksPath', 'hooks'], cwd=ROOT, check=True)
    print('Hooks actifs pour ce clone. Les anciens fichiers .git/hooks sont conserves.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
