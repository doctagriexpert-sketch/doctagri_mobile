#!/usr/bin/env python3
"""Shared local/CI checks. No install, autofix, deployment or Git mutation."""
import argparse
import ast
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(command, cwd=ROOT):
    executable = shutil.which(command[0])
    if not executable:
        print(f'OUTIL ABSENT: {command[0]}', flush=True)
        return 2
    print('> ' + ' '.join(command), flush=True)
    return subprocess.run([executable, *command[1:]], cwd=cwd).returncode


def python_syntax():
    failures = 0
    for directory in ('scripts', 'hooks', 'ml/pipeline'):
        for path in sorted((ROOT / directory).glob('*.py')):
            try:
                ast.parse(path.read_text(encoding='utf-8-sig'), filename=str(path))
            except (SyntaxError, UnicodeError) as error:
                print(f'{path.relative_to(ROOT)}: {type(error).__name__}')
                failures += 1
    return int(bool(failures))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('suite', choices=('repository', 'flutter', 'dashboard', 'python', 'all'))
    args = parser.parse_args()
    suites = ('repository', 'flutter', 'dashboard', 'python') if args.suite == 'all' else (args.suite,)
    failures = []
    for suite in suites:
        commands = []
        if suite == 'repository':
            commands = [
                ([sys.executable, 'hooks/check.py', '--all'], ROOT),
                ([sys.executable, 'scripts/check_docs.py'], ROOT),
                ([sys.executable, '-m', 'unittest', 'discover', '-s', 'hooks/tests', '-v'], ROOT),
            ]
        elif suite == 'flutter':
            commands = [
                (['flutter', 'analyze', '--no-pub'], ROOT),
            ]
            sources = sorted(str(p.relative_to(ROOT)) for folder in ('lib', 'test')
                             for p in (ROOT / folder).rglob('*.dart')
                             if not p.name.endswith(('.g.dart', '.freezed.dart'))
                             and p.name != 'injection_container.config.dart')
            for offset in range(0, len(sources), 25):
                commands.append((['dart', 'format', '--output=none', '--set-exit-if-changed',
                                  *sources[offset:offset + 25]], ROOT))
            commands.append((['flutter', 'test', '--no-pub'], ROOT))
        elif suite == 'dashboard':
            commands = [(['npm', 'run', task], ROOT / 'doctagri-dashboard') for task in ('lint', 'test', 'build')]
        elif suite == 'python':
            if python_syntax():
                failures.append('python syntax')
        for command, cwd in commands:
            if run(command, cwd):
                failures.append(' '.join(command))
    if failures:
        print('\nECHECS (non masques):\n- ' + '\n- '.join(failures))
        return 1
    print('\nControles demandes reussis ; aucun deploiement effectue.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
