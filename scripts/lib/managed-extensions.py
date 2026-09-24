import argparse
import csv
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.request
import zipfile


def linked(path):
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        return False
    return stat.S_ISLNK(metadata.st_mode) or bool(getattr(metadata, 'st_file_attributes', 0) & 0x400)


def safe_path(home, relative):
    parts = PurePosixPath(relative).parts
    if not parts or PurePosixPath(relative).is_absolute() or any(p in ('.', '..') or ':' in p or '\\' in p for p in parts):
        raise ValueError('Invalid managed extension path.')
    target = home.joinpath(*parts)
    for item in (target, *target.parents):
        if item == home:
            break
        if linked(item):
            raise ValueError('Managed extension path contains a link.')
    return target


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def run_command(arguments, summary=False, home=None):
    executable = shutil.which(arguments[0])
    if executable is None:
        raise ValueError(f'{arguments[0]} CLI is required to manage plugins.')
    environment = os.environ.copy()
    if home is not None:
        environment.update(HOME=str(home), USERPROFILE=str(home), CODEX_HOME=str(home / '.codex'), CLAUDE_CONFIG_DIR=str(home / '.claude'))
    result = subprocess.run([executable, *arguments[1:]], stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=180, env=environment)
    if result.returncode:
        raise ValueError(f'Extension command failed: {arguments[0]} {" ".join(arguments[1:])}\n{result.stdout}{result.stderr}')
    if result.stderr:
        print(result.stderr.rstrip(), file=sys.stderr)
    if not summary and result.stdout:
        print(result.stdout.rstrip())
    elif summary:
        for line in result.stdout.splitlines():
            if re.search(r'warn|error|fail|deprecat', line, re.I):
                print(line)
    return result.stdout


def installed_plugins(client, home=None):
    result = json.loads(run_command([client, 'plugin', 'list', '--json'], True, home))
    if client == 'codex':
        if not isinstance(result, dict) or not isinstance(result.get('installed'), list):
            raise ValueError('Invalid Codex installed plugin response.')
        result = result['installed']
    if not isinstance(result, list):
        raise ValueError('Invalid installed plugin response.')
    key = 'id' if client == 'claude' else 'pluginId'
    if any(not isinstance(item, dict) or not isinstance(item.get(key), str) for item in result):
        raise ValueError('Invalid installed plugin record.')
    return {item[key]: item for item in result}


def fetch_skill(entry):
    source = entry['codex_source']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', source):
        raise ValueError('Skill source must be a GitHub owner/repository.')
    skill = entry['codex_skill']
    if not re.fullmatch(r'[A-Za-z0-9_-]+', skill):
        raise ValueError('Skill name is invalid.')
    revision = resolve_revision(source)
    if revision is None:
        raise ValueError('Cannot resolve an immutable skill revision.')
    request = urllib.request.Request(f'https://codeload.github.com/{source}/zip/{revision}', headers={'User-Agent': 'MyAiConfiguration'})
    with urllib.request.urlopen(request, timeout=60) as response:
        if not response.url.startswith('https://codeload.github.com/'):
            raise ValueError('Unexpected skill download redirect.')
        payload = response.read(32 * 1024 * 1024 + 1)
    if len(payload) > 32 * 1024 * 1024:
        raise ValueError('Skill archive exceeds the download limit.')
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        members = archive.infolist()
        roots = {item.filename.split('/')[0] for item in members}
        if len(roots) != 1:
            raise ValueError('Skill archive has an invalid root.')
        root = next(iter(roots)) + '/'
        prefixes = [root + '.agents/skills/' + skill + '/', root + 'skills/' + skill + '/', root]
        prefix = next((p for p in prefixes if p + 'SKILL.md' in archive.namelist()), None)
        if prefix is None:
            raise ValueError(f'Skill payload is missing: {skill}')
        files = {}
        total = 0
        for item in members:
            if not item.filename.startswith(prefix) or item.is_dir():
                continue
            relative = item.filename[len(prefix):]
            if prefix == root and relative != 'SKILL.md' and not relative.startswith(('references/', 'scripts/', 'assets/', 'agents/')):
                continue
            if stat.S_ISLNK(item.external_attr >> 16):
                raise ValueError('Skill archive contains a symbolic link.')
            parts = PurePosixPath(relative).parts
            if not parts or any(p in ('.', '..') or ':' in p or '\\' in p for p in parts) or relative.startswith('/'):
                raise ValueError('Skill archive contains an unsafe path.')
            total += item.file_size
            if total > 64 * 1024 * 1024 or len(files) >= 10000:
                raise ValueError('Skill payload exceeds extraction limits.')
            if relative in files:
                raise ValueError('Skill archive contains duplicate paths.')
            files[relative] = (archive.read(item), bool(item.external_attr >> 16 & 0o111))
    return skill, files, revision


def resolve_revision(source):
    try:
        request = urllib.request.Request(f'https://api.github.com/repos/{source}/commits/HEAD', headers={'Accept': 'application/vnd.github+json', 'User-Agent': 'MyAiConfiguration'})
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = json.loads(response.read(1024 * 1024))
        revision = payload.get('sha') if isinstance(payload, dict) else None
        return revision if isinstance(revision, str) and re.fullmatch(r'[0-9a-fA-F]{40}', revision) else None
    except (OSError, ValueError, json.JSONDecodeError):
        return None


class Manager:
    def __init__(self, home, dry_run=False, update=False, summary=False):
        self.home = Path(home).absolute()
        self.path = safe_path(self.home, '.my-ai-configuration/extensions.json')
        self.dry_run = dry_run
        self.update = update
        self.summary = summary
        self.state = {'version': 1, 'resources': []}
        if self.path.exists():
            self.state = json.loads(self.path.read_text(encoding='utf-8'))
        self.validate()
        self.cache = {}
        self.new_packages = set()

    def validate(self):
        if not isinstance(self.state, dict) or self.state.get('version') != 1 or not isinstance(self.state.get('resources'), list):
            raise ValueError('Invalid extension ownership ledger.')
        identities = set()
        for resource in self.state['resources']:
            if not isinstance(resource, dict) or resource.get('client') not in ('codex', 'claude', 'shared') or resource.get('kind') not in ('plugin', 'skill', 'qmd', 'cli', 'mcp'):
                raise ValueError('Invalid extension ownership record.')
            if not isinstance(resource.get('name'), str) or not resource['name']:
                raise ValueError('Invalid extension ownership name.')
            identity = (resource['client'], resource['name'])
            if identity in identities:
                raise ValueError('Duplicate extension ownership record.')
            identities.add(identity)
            if resource['kind'] == 'plugin':
                if not re.fullmatch(r'[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+', resource.get('selector', '')):
                    raise ValueError('Invalid owned plugin selector.')
                if 'source' in resource and not isinstance(resource['source'], str):
                    raise ValueError('Invalid owned plugin source.')
            elif resource['kind'] == 'skill':
                directory = resource.get('directory', '')
                if not re.fullmatch(r'\.agents/skills/[A-Za-z0-9_-]+', directory) or resource['client'] != 'codex':
                    raise ValueError('Invalid owned skill directory.')
                safe_path(self.home, directory)
                if not isinstance(resource.get('files'), dict):
                    raise ValueError('Invalid owned skill file inventory.')
                if 'source' in resource and not isinstance(resource['source'], str):
                    raise ValueError('Invalid owned skill source.')
                for relative, value in resource['files'].items():
                    if not relative.startswith(directory + '/') or not re.fullmatch(r'[a-f0-9]{64}', value):
                        raise ValueError('Invalid owned skill file record.')
                    safe_path(self.home, relative)
            elif resource['kind'] == 'qmd' and (resource.get('package') != '@tobilu/qmd' or resource['client'] != 'codex'):
                raise ValueError('Invalid owned QMD record.')
            elif resource['kind'] == 'cli' and not re.fullmatch(r'[a-z0-9@/_.-]+', resource.get('package', '')):
                raise ValueError('Invalid owned CLI record.')
            elif resource['kind'] == 'mcp' and (resource['client'] != 'shared' or not re.fullmatch(r'[a-z0-9-]+', resource.get('server', '')) or not re.fullmatch(r'https://[^\s]+', resource.get('url', ''))):
                raise ValueError('Invalid owned MCP record.')

    def save(self):
        if not self.dry_run:
            self.validate()
            atomic_write(self.path, (json.dumps(self.state, indent=2) + '\n').encode())

    def installed(self, client):
        if client not in self.cache:
            self.cache[client] = installed_plugins(client, self.home)
        return self.cache[client]

    def global_packages(self):
        if 'global_packages' not in self.cache:
            result = json.loads(run_command(['npm', 'list', '--global', '--depth=0', '--json'], True, self.home))
            if not isinstance(result, dict) or not isinstance(result.get('dependencies'), dict):
                raise ValueError('Invalid global npm package inventory.')
            self.cache['global_packages'] = set(result['dependencies'])
        return self.cache['global_packages']

    def command(self, arguments):
        if self.dry_run:
            if not self.summary:
                print('DRYRUN ' + ' '.join(arguments))
        else:
            run_command(arguments, self.summary, self.home)

    def remove(self, record):
        if self.dry_run:
            if not self.summary:
                print(f'DRYRUN remove managed {record["client"]} {record["name"]}')
            return
        if record['kind'] == 'plugin':
            client, selector = record['client'], record['selector']
            item = self.installed(client).get(selector)
            if item is not None:
                if client == 'claude' and item.get('scope', 'user') != 'user':
                    raise ValueError('Owned plugin now has a different scope; removal stopped.')
                arguments = [client, 'plugin', 'uninstall', selector, '--scope', 'user'] if client == 'claude' else [client, 'plugin', 'remove', selector]
                self.command(arguments)
                self.cache[client].pop(selector, None)
        elif record['kind'] == 'skill':
            empty_candidates = set()
            for relative, expected in list(record['files'].items()):
                path = safe_path(self.home, relative)
                if path.exists():
                    if not path.is_file() or digest(path) != expected:
                        print(f'WARN Preserving modified skill file: {relative}')
                        continue
                    path.unlink()
                parent = path.parent
                directory = safe_path(self.home, record['directory'])
                while parent != directory.parent:
                    empty_candidates.add(parent)
                    parent = parent.parent
                del record['files'][relative]
                self.save()
            directory = safe_path(self.home, record['directory'])
            if directory.exists():
                for path in sorted(empty_candidates, key=lambda p: len(p.parts), reverse=True):
                    if path.is_dir() and not path.is_symlink():
                        try:
                            path.rmdir()
                        except OSError:
                            pass
                try:
                    directory.rmdir()
                except OSError:
                    pass
            if record['files']:
                return
        elif record['kind'] == 'mcp':
            self.command(['mcporter', '--config', str(self.home / '.mcporter/mcporter.json'), 'config', 'remove', record['server']])
        else:
            package = record['package']
            self.command(['npm', 'uninstall', '--global', package])
        self.state['resources'].remove(record)
        self.save()

    def ensure(self, client, entry):
        if entry['codex_method'] == 'cli':
            self.ensure_cli(client, entry)
            return
        if entry['codex_method'] == 'qmd':
            self.ensure_qmd(client, entry)
            return
        skill = client == 'codex' and entry['codex_method'] != 'plugin'
        kind = 'skill' if skill else 'plugin'
        record = next((r for r in self.state['resources'] if r['client'] == client and r['name'] == entry['name']), None)
        selector = entry[client + '_plugin']
        if record and (record['kind'] != kind or (kind == 'plugin' and record['selector'] != selector)):
            self.remove(record)
            if not self.dry_run and record in self.state['resources']:
                raise ValueError('Modified owned files prevent extension replacement.')
            record = None
        if self.dry_run:
            if not self.summary:
                print(f'DRYRUN ensure {client} {kind}: {entry["name"]}')
            return
        if skill:
            self.ensure_skill(entry, record)
            return
        if not re.fullmatch(r'[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+', selector):
            raise ValueError('Invalid plugin selector.')
        item = self.installed(client).get(selector)
        if item is not None and record is None:
            if not self.summary:
                print(f'PASS Preserving pre-existing {client} plugin: {selector}')
            return
        if item is not None and client == 'claude' and item.get('scope', 'user') != 'user':
            raise ValueError('Owned plugin now has a different scope; update stopped.')
        if item is not None and not self.update:
            if client == 'claude' and item.get('enabled') is False:
                self.command([client, 'plugin', 'enable', selector])
            if record is not None and item.get('version') is not None:
                record['version'] = item['version']; self.save()
            return
        if item is not None and client == 'claude':
            self.command([client, 'plugin', 'marketplace', 'update', selector.rsplit('@', 1)[1]])
            self.command([client, 'plugin', 'update', selector])
            if item.get('enabled') is False:
                self.command([client, 'plugin', 'enable', selector])
            if record is not None:
                self.cache.pop(client, None)
                version = self.installed(client).get(selector, {}).get('version')
                if version is not None: record['version'] = version; self.save()
            return
        marketplace = entry[client + '_marketplace']
        if marketplace not in ('', '-', 'openai-curated-remote'):
            if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', marketplace):
                raise ValueError('Invalid plugin marketplace source.')
            if item is not None and self.update and client == 'codex':
                self.command([client, 'plugin', 'marketplace', 'upgrade', selector.rsplit('@', 1)[1]])
            else:
                self.command([client, 'plugin', 'marketplace', 'add', marketplace])
        if client == 'claude':
            self.command([client, 'plugin', 'marketplace', 'update', selector.rsplit('@', 1)[1]])
        arguments = [client, 'plugin', 'install', selector, '--scope', 'user'] if client == 'claude' else [client, 'plugin', 'add', selector]
        self.command(arguments)
        resolved_version = None
        if self.update:
            self.cache.pop(client, None)
            resolved_version = self.installed(client).get(selector, {}).get('version')
        if record is None:
            record = dict(client=client, name=entry['name'], kind='plugin', selector=selector, source=entry.get(client + '_marketplace', '-'))
            if resolved_version is not None: record['version'] = resolved_version
            self.state['resources'].append(record)
            self.save()
        self.cache[client][selector] = {'scope': 'user'}

    def ensure_cli(self, client, entry):
        package = entry['codex_source']
        if not re.fullmatch(r'[a-z0-9@/_.-]+', package):
            raise ValueError('Invalid CLI package.')
        record = next((r for r in self.state['resources'] if r['client'] == client and r['name'] == entry['name']), None)
        installed = package in self.global_packages()
        if record is None and installed:
            if not self.summary:
                print(f'PASS Preserving pre-existing global package: {package}')
            return
        if record is not None and installed and not self.update:
            return
        self.command(['npm', 'update' if record is not None and installed else 'install', '--global', package])
        self.global_packages().add(package)
        self.new_packages.add(package)
        if not self.dry_run and record is None:
            self.state['resources'].append(dict(client=client, name=entry['name'], kind='cli', package=package))
            self.save()

    def repair_caveman_windows_hooks(self):
        if self.dry_run or os.name != 'nt':
            return
        if not any(r['client'] == 'codex' and r['kind'] == 'plugin'
                   and r['selector'] == 'caveman@thinkhome-caveman' for r in self.state['resources']):
            return
        # ponytail: only the known 1.0.0 command; remove when upstream ships a portable launcher.
        path = safe_path(self.home, '.codex/plugins/cache/thinkhome-caveman/caveman/1.0.0/hooks/hooks.json')
        if not path.is_file():
            return
        content = json.loads(path.read_text(encoding='utf-8'))
        changed = False
        for groups in content.get('hooks', {}).values():
            for group in groups:
                for hook in group.get('hooks', []):
                    if hook.get('commandWindows') == 'node "%PLUGIN_ROOT%\\hooks\\caveman-hook.mjs"':
                        hook['commandWindows'] = ('node -e "import(require(\'node:url\').pathToFileURL('
                                                  'require(\'node:path\').join(process.env.PLUGIN_ROOT,'
                                                  '\'hooks\',\'caveman-hook.mjs\')).href)"')
                        changed = True
        if changed:
            atomic_write(path, (json.dumps(content, indent=2) + '\n').encode('utf-8'))
            print('Repaired Caveman Windows hook commands; review the changed hooks in Codex /hooks.')

    def ensure_qmd(self, client, entry):
        package = entry['codex_source']
        if package != '@tobilu/qmd':
            raise ValueError('Invalid QMD package.')
        record = next((r for r in self.state['resources'] if r['client'] == 'codex' and r['name'] == entry['name']), None)
        pre_existing = record is None and package in self.global_packages() and package not in self.new_packages
        if not getattr(self, 'qmd_ready', False) and not pre_existing and package not in self.global_packages():
            self.command(['npm', 'install', '--global', package])
            self.global_packages().add(package)
            self.new_packages.add(package)
        self.qmd_ready = True
        if client == 'claude':
            entry = dict(entry, codex_method='plugin')
            self.ensure(client, entry)
            return
        if record is not None or pre_existing:
            return
        self.state['resources'].append(dict(client='codex', name=entry['name'], kind='qmd', package=package))
        self.save()

    def ensure_mcporter(self, entry):
        server, url = entry['mcporter_name'], entry['mcporter_url']
        if not re.fullmatch(r'[a-z0-9-]+', server) or not re.fullmatch(r'https://[^\s]+', url):
            raise ValueError('Invalid MCPorter server definition.')
        record = next((r for r in self.state['resources'] if r['client'] == 'shared' and r['name'] == entry['name']), None)
        config_path = safe_path(self.home, '.mcporter/mcporter.json')
        existing = None
        if config_path.exists():
            config = json.loads(config_path.read_text(encoding='utf-8'))
            if not isinstance(config, dict) or not isinstance(config.get('mcpServers', {}), dict):
                raise ValueError('Invalid MCPorter server configuration.')
            existing = config.get('mcpServers', {}).get(server)
            if existing is not None and not isinstance(existing, dict):
                raise ValueError('Invalid MCPorter server entry.')
            if existing is not None and record is None:
                if not self.summary:
                    print(f'PASS Preserving pre-existing MCPorter server: {server}')
                return
            if existing is not None and record is not None and existing.get('baseUrl') != record['url']:
                raise ValueError('Owned MCPorter server changed locally; refusing to overwrite it.')
        if record is not None and existing is not None and not self.update:
            return
        self.command(['mcporter', '--config', str(self.home / '.mcporter/mcporter.json'), 'config', 'add', server, url])
        if record is None:
            self.state['resources'].append(dict(client='shared', name=entry['name'], kind='mcp', server=server, url=url))
        else:
            record.update(server=server, url=url)
        self.save()

    def ensure_skill(self, entry, record):
        skill = entry['codex_skill']
        if not re.fullmatch(r'[A-Za-z0-9_-]+', skill):
            raise ValueError('Invalid skill name.')
        directory = '.agents/skills/' + skill
        target = self.home / directory
        alternate = self.home / '.codex' / 'skills' / skill
        if record is None and (target.exists() or target.is_symlink() or alternate.exists() or alternate.is_symlink()):
            if not self.summary:
                print(f'PASS Preserving pre-existing Codex skill: {skill}')
            return
        target = safe_path(self.home, directory)
        if record and record['directory'] != directory:
            self.remove(record)
            if record in self.state['resources']:
                raise ValueError('Modified owned files prevent skill replacement.')
            record = None
        if record and record.get('complete') and not self.update and all(safe_path(self.home, name).is_file() for name in record['files']) and record['files']:
            return
        fetched = fetch_skill(entry)
        _, files = fetched[:2]
        revision = fetched[2] if len(fetched) > 2 else None
        if record is None:
            record = dict(client='codex', name=entry['name'], kind='skill', directory=directory, source=entry['codex_source'], files={}, complete=False)
            self.state['resources'].append(record)
            self.save()
        record['complete'] = False
        if revision:
            record['resolvedRevision'] = revision
        self.save()
        for name, (content, executable) in files.items():
            relative = directory + '/' + name
            path = safe_path(self.home, relative)
            if path.exists() and (relative not in record['files'] or not path.is_file() or digest(path) != record['files'][relative]):
                print(f'WARN Preserving modified or foreign skill file: {relative}')
                continue
            atomic_write(path, content)
            if executable:
                path.chmod(path.stat().st_mode | stat.S_IXUSR)
            record['files'][relative] = hashlib.sha256(content).hexdigest()
            self.save()
        for relative in list(record['files']):
            if relative[len(directory) + 1:] in files:
                continue
            path = safe_path(self.home, relative)
            if path.exists() and (not path.is_file() or digest(path) != record['files'][relative]):
                print(f'WARN Preserving modified stale skill file: {relative}')
                continue
            path.unlink(missing_ok=True)
            del record['files'][relative]
            self.save()
        record['complete'] = True
        self.save()

    def sync(self, entries, clients, selected, action='sync'):
        desired = {entry['name']: entry for entry in entries if entry['name'] in selected}
        use_mcporter = 'MCPorter' in desired
        mcporter_entries = {name: entry for name, entry in desired.items() if use_mcporter and entry.get('mcporter_name') and entry.get('mcporter_url') not in ('', '-')}
        direct_entries = {name: entry for name, entry in desired.items() if name not in mcporter_entries}
        for record in sorted(self.state['resources'], key=lambda record: record['kind'] != 'mcp'):
            if record['client'] != 'shared' and record['client'] not in clients:
                continue
            selected_entries = mcporter_entries if record['client'] == 'shared' else direct_entries
            if (action == 'sync' and record['name'] not in selected_entries) or (action == 'remove' and record['name'] in selected):
                self.remove(record)
        if action != 'remove':
            for client in clients:
                for entry in direct_entries.values():
                    self.ensure(client, entry)
                    if client == 'codex' and entry.get('codex_plugin') == 'caveman@thinkhome-caveman':
                        self.repair_caveman_windows_hooks()
            for entry in mcporter_entries.values():
                self.ensure_mcporter(entry)
        print('EXTENSIONS: reconciliation complete' + (' (dry run)' if self.dry_run else ''))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('sync', 'install', 'remove'))
    parser.add_argument('--home', required=True)
    parser.add_argument('--manifest', required=True)
    parser.add_argument('--client', choices=('codex', 'claude', 'both'), required=True)
    parser.add_argument('--selected', nargs='*')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--update', action='store_true')
    parser.add_argument('--summary', action='store_true')
    args = parser.parse_args()
    with open(args.manifest, encoding='utf-8-sig', newline='') as stream:
        entries = list(csv.DictReader(stream, delimiter='\t'))
    names = {entry['name'] for entry in entries}
    if len(names) != len(entries):
        raise ValueError('Duplicate extension manifest entry.')
    selected = names if args.selected is None else set(args.selected)
    if args.action != 'remove' and selected - names:
        raise ValueError('Unknown selected extension.')
    clients = ('claude', 'codex') if args.client == 'both' else (args.client,)
    manager = Manager(args.home, args.dry_run, args.update, args.summary)
    if args.dry_run:
        manager.sync(entries, clients, selected, args.action)
        return
    lock = safe_path(manager.home, '.my-ai-configuration/extensions.lock')
    lock.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    try:
        os.close(descriptor)
        manager = Manager(args.home, args.dry_run, args.update, args.summary)
        manager.sync(entries, clients, selected, args.action)
    finally:
        lock.unlink()


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print(f'Managed extensions: {error}', file=sys.stderr)
        sys.exit(1)
