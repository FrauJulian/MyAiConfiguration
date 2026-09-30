#!/usr/bin/env python3
"""Remove the last exact instruction block added to a client overlay."""

import argparse
import os
import stat
import tempfile
from pathlib import Path


def remove_instruction(path: Path, instruction: str) -> bool:
    if not path.exists():
        return False
    if path.is_symlink() or not path.is_file():
        raise ValueError(f'Instruction path is not a regular file: {path}')

    raw = path.read_bytes()
    encoding = 'utf-8-sig' if raw.startswith(b'\xef\xbb\xbf') else 'utf-8'
    lines = raw.decode(encoding).splitlines(keepends=True)
    wanted = instruction.rstrip('\r\n').splitlines()
    values = [line.rstrip('\r\n') for line in lines]
    offset = next((i for i in range(len(values) - len(wanted), -1, -1)
                   if values[i:i + len(wanted)] == wanted), None)
    if offset is None:
        return False

    updated = ''.join(lines[:offset] + lines[offset + len(wanted):])
    if not updated:
        path.unlink()
        return True

    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.instruction-', delete=False) as file:
            temporary = Path(file.name)
            file.write(updated.encode(encoding))
        os.chmod(temporary, stat.S_IMODE(path.stat().st_mode))
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client', choices=('codex', 'claude', 'both'), required=True)
    parser.add_argument('--instruction', required=True)
    parser.add_argument('--home', required=True)
    args = parser.parse_args()
    if not args.instruction.strip() or len(args.instruction) > 65536:
        parser.error('Instruction must contain between 1 and 65536 characters.')
    home = Path(args.home)
    if not home.is_absolute():
        parser.error('Home path must be absolute.')
    directory = home / '.my-ai-configuration' / 'instructions'
    if (home / '.my-ai-configuration').is_symlink() or directory.is_symlink():
        parser.error('Instruction directory must not be a link.')
    try:
        inside_home = os.path.commonpath((home.resolve(), directory.resolve())) == str(home.resolve())
    except ValueError:
        inside_home = False
    if not inside_home:
        parser.error('Instruction directory must remain inside the home directory.')

    targets = ('codex', 'claude') if args.client == 'both' else (args.client,)
    paths = [(target, directory / f'{target}.md') for target in targets]
    for _, path in paths:
        if path.is_symlink():
            parser.error('Instruction path must not be a link.')
        if path.exists() and not path.is_file():
            parser.error('Instruction path must be a regular file.')
    for target, path in paths:
        if remove_instruction(path, args.instruction):
            print(f'Instruction removed for {target}.')
        else:
            print(f'Instruction not found for {target}.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
