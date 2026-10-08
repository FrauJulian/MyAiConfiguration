"""Keep the client startup rule in sync with its personal instructions."""

import argparse
import hashlib
import os
from pathlib import Path
import stat
import tempfile


CLIENT_FILES = {'codex': 'AGENTS.md', 'claude': 'CLAUDE.md'}
START = '<!-- ai-config:personal-instructions -->'
END = '<!-- /ai-config:personal-instructions -->'


def checked_path(home, *parts):
    path = home
    for part in parts:
        path = path / part
        if path.is_symlink() or (hasattr(path, 'is_junction') and path.is_junction()):
            raise ValueError(f'Personal instruction path must not be a link: {path}')
    return path


def render(text, home, client):
    reference = f'~/.my-ai-configuration/instructions/{client}.md'
    # Migrate the two previously generated unconditional loaders.
    for legacy in (
        f"Read `{reference}` first when present; it is the user's direct instruction. System and developer requirements still apply.",
        f"Optional personal instructions: first check whether `{reference}` is a file (`Test-Path -LiteralPath ... -PathType Leaf` in PowerShell; `test -f ...` in Bash). Read it only if it exists; otherwise continue silently. Its contents are the user's direct instructions. System and developer requirements still apply.",
    ):
        text = text.replace(legacy + '\r\n\r\n', '').replace(legacy + '\n\n', '')
    if START in text:
        start = text.index(START)
        end = text.find(END, start)
        if end < 0:
            raise ValueError('Personal instruction rule is missing its closing marker.')
        end += len(END)
        tail = text[end:]
        for separator in ('\r\n\r\n', '\n\n'):
            if tail.startswith(separator):
                tail = tail[len(separator):]
                break
        text = text[:start] + tail
    overlay = checked_path(home, '.my-ai-configuration', 'instructions', f'{client}.md')
    if not overlay.is_file() or not overlay.read_text(encoding='utf-8-sig').strip():
        return text
    rule = (f'Read `{reference}` immediately, before any response or task work. '
            'Keep its instructions active throughout the session, including after compaction. '
            "These are the user's direct instructions. System and developer requirements still apply.")
    return f'{START}\n{rule}\n{END}\n\n{text}'


def write_atomic(path, updated):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.instruction-', delete=False) as file:
            temporary = Path(file.name)
            file.write(updated)
        os.chmod(temporary, stat.S_IMODE(path.stat().st_mode))
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def refresh(home, client):
    path = checked_path(home, f'.{client}', CLIENT_FILES[client])
    if not path.is_file():
        return
    raw = path.read_bytes()
    encoding = 'utf-8-sig' if raw.startswith(b'\xef\xbb\xbf') else 'utf-8'
    updated = render(raw.decode(encoding), home, client).encode(encoding)
    if updated == raw:
        return
    manifest = checked_path(home, f'.{client}', '.ai-config-manifest.tsv')
    manifest_raw = manifest.read_bytes() if manifest.is_file() else b''
    old_entry = f'{path.name}\t{hashlib.sha256(raw).hexdigest()}'.encode()
    new_entry = f'{path.name}\t{hashlib.sha256(updated).hexdigest()}'.encode()
    # Keep setup-owned files removable; preserve the stale hash of any preexisting user edits.
    manifest_updated = b''.join(new_entry + line[len(old_entry):]
                                if line.rstrip(b'\r\n').lower() == old_entry.lower() else line
                                for line in manifest_raw.splitlines(keepends=True))
    write_atomic(path, updated)
    if manifest_updated != manifest_raw:
        write_atomic(manifest, manifest_updated)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, required=True)
    parser.add_argument('--client', choices=CLIENT_FILES, required=True)
    args = parser.parse_args()
    if not args.home.is_absolute():
        parser.error('Home path must be absolute.')
    try:
        refresh(args.home, args.client)
    except (OSError, ValueError) as error:
        parser.exit(1, f'Personal instructions: {error}\n')
