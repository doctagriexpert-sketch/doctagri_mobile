#!/usr/bin/env python3
"""Check maintained Markdown links and project skill frontmatter without packages."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]


def main():
    files = [ROOT / name for name in ('AGENTS.md', 'CONTRIBUTING.md', 'README.md', 'docs/README.md',
             'docs/getting-started.md', 'docs/project-status.md', 'docs/technical-debt.md')]
    for folder in ('rules', 'skills', 'docs/decisions', 'docs/contracts'):
        files.extend((ROOT / folder).rglob('*.md'))
    errors = []
    for path in files:
        if not path.is_file():
            errors.append(f'{path.relative_to(ROOT)}: fichier manquant')
            continue
        text = path.read_text(encoding='utf-8')
        for target in re.findall(r'\[[^\]]*\]\(([^\s)]+)\)', text):
            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target) or target.startswith('#'):
                continue
            target = unquote(target.split('#')[0])
            if target and not (path.parent / target).exists():
                errors.append(f'{path.relative_to(ROOT)}: lien local absent: {target}')
        if path.name == 'SKILL.md':
            match = re.match(r'^---\nname: ([a-z0-9-]+)\ndescription: (.+)\n---\n', text)
            if not match or match[1] != path.parent.name or len(match[1]) > 64:
                errors.append(f'{path.relative_to(ROOT)}: frontmatter invalide')
    for error in errors:
        print(error)
    if not errors:
        print('Liens maintenus et skills: OK')
    return int(bool(errors))


if __name__ == '__main__':
    sys.exit(main())
