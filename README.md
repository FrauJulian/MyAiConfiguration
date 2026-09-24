# My AI Configuration

![OpenAI Codex](https://img.shields.io/badge/OpenAI-Codex-000000)
![Claude Code](https://img.shields.io/badge/Anthropic-Claude_Code-D97757)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-0078D4)
![Bash](https://img.shields.io/badge/Bash-4.3%2B-FCC624)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`MyAiConfiguration` is a version-controlled global user configuration for OpenAI Codex and Claude Code.

It keeps rules, skills, agents, hooks, and orchestration guidance in shared source files. Client adapters turn those files
into shell-specific packages that can be inspected before they are installed.

## Capability check

Check the selected shell's minimum version and required Python tools before setup. Missing `jq` produces a warning because only Claude's Bash status line needs it. The command exits with an error when a requirement is missing.

PowerShell:

```powershell
.\scripts\commands\check-capabilities.ps1
```

Bash:

```bash
./scripts/commands/check-capabilities.sh
```

## Quickstart

With the [requirements](#requirements) installed, clone the repository, build it, then install it.
Stop if any command fails. Installation asks for the shell, client, CLI update, Flashbang, Qwen retrieval, and extension choices.

PowerShell:

```powershell
git clone https://git.lechner-systems.at/fraujulian/MyAiConfiguration.git
cd MyAiConfiguration
.\scripts\commands\build.ps1 -Summary
.\scripts\commands\install.ps1 -Summary
```

Bash:

```bash
git clone https://git.lechner-systems.at/fraujulian/MyAiConfiguration.git
cd MyAiConfiguration
./scripts/commands/build.sh --summary
./scripts/commands/install.sh --summary
```

For an already-installed configuration, use Quickupdate instead.

## Quickupdate

Run these commands from the repository root. Quick reuses the shell, client, CLI update, Flashbang, retrieval, and extension choices from the last
successful installation or update without opening selection menus. Stop if any command fails.

PowerShell:

```powershell
git pull --ff-only
.\scripts\commands\build.ps1 -Summary
.\scripts\commands\update.ps1 -Quick -Summary
```

Bash:

```bash
git pull --ff-only
./scripts/commands/build.sh --summary
./scripts/commands/update.sh --quick --summary
```

If no selection has been saved yet, or it predates a required option, Quick stops with a hint. Run `scripts/commands/update.ps1` or `./scripts/commands/update.sh` once
without Quick to save your choices. They are stored in `~/.my-ai-configuration/selection.json`; dry runs and failed
runs do not overwrite them. To change the selection later, run a normal update again. Quick does not automatically
select newly added plugins.

Install and update also rebuild internally; the explicit build above lets you check the packages before installation.

## Features

- One shared source of truth for Codex and Claude Code.
- Separate generated packages for PowerShell and Bash.
- Native PowerShell 5.1 and Bash scripts.
- Installation for Codex, Claude Code, or both, with explicit target parameters and an interactive plugin selection.
- Claude Code loads technology- and situation-specific rules as skills, so only their name and description sit
  permanently in context; the full rule text loads only when the skill is invoked. Codex keeps loading rules as plain
  files, unchanged.
- A managed-file manifest tracks unchanged and stale files. Replaced files are backed up; locally modified stale
  files are retained with a warning.
- Dry-run support (no destination writes, backups, or plugin changes) and timestamped backup directories.
- Finish notifications, Claude session-state hooks, optional safety utilities, and compact status displays.
- Separate install, update, and uninstall scripts: install refuses to run against an already-installed destination,
  update refuses to run against one that is not installed yet, and uninstall refuses to run against one that was
  never installed.
- User-level plugin installation for Ponytail, i-have-adhd, Superpowers, Context7, Caveman, QMD, Humanizer, Impeccable, and
  Anthropic Frontend Design, with an interactive extension toggle during both install and update. Only extensions
  installed and recorded by this setup can be removed through deselection.
- Optional local semantic retrieval for both clients using Qwen3-Embedding-0.6B embeddings and Qwen3-Reranker-0.6B
  reranking, disabled by default and removable through the install/update choice.

## Requirements

- PowerShell 5.1 or newer; PowerShell 7 is supported as well.
- Bash 4.3 or newer, with standard utilities such as `awk`, `sed`, and `sha256sum`.
- Python 3.11 or newer for configuration validation and task-state hooks/helpers (`python` for PowerShell scripts, `python3` for Bash scripts).
- `jq` for Claude's Bash status line; without it, that status line produces no output.
- Python `venv` and `pip` when the optional semantic retrieval layer is enabled.
- Node.js 22 or newer and `npm` when QMD or MCPorter is selected.

The Bash scripts do not require PowerShell. The PowerShell scripts remain compatible with PowerShell 5.1;
PowerShell 7 can also run them.

## Architecture

```text
shared definitions -> client adapters -> generated packages -> user installation
```

| Directory | Purpose |
| --- | --- |
| `shared/` | Client-independent rules, agents, skills, hooks, status lines, and global instructions. |
| `adapters/` | Codex and Claude Code formats, settings, templates, and the plugin manifest. |
| `generated/` | Reproducible PowerShell and Bash packages. This directory is ignored by Git. |
| [`scripts/`](docs/scripts.md) | Build, installation, update, diagnosis, and validation scripts. |
| `docs/` | Focused documentation about the configuration design. |

The build creates:

```text
generated/
|-- codex-powershell/
|-- claude-powershell/
|-- codex-bash/
`-- claude-bash/
```

## Documentation

| Document | Contents |
| --- | --- |
| [Architecture](docs/architecture.md) | Shared sources, adapters, generated packages, and installation. |
| [Scripts](docs/scripts.md) | Commands, checks, tests, and internal script layout. |
| [Configuration](docs/configuration.md) | Client settings, permission defaults, status displays, and verification. |
| [Extending the configuration](docs/extending-configuration.md) | Add shared rules, skills, and agents. |
| [Plugins](docs/plugins.md) | Plugin sources, selection, installation, updates, and removal. |
| [Hooks](docs/hooks.md) | Registered events, session-state helpers, notifications, and optional utilities. |
| [Agents](docs/agents.md) | Agent roles and when delegation is useful. |
| [Skills](docs/skills.md) | Skill categories and conditional rule loading. |
| [Codex adapter](adapters/codex/README.md) | Codex-specific configuration files. |
| [Claude Code adapter](adapters/claude/README.md) | Claude-specific configuration files. |
| [Hook package](shared/hooks/README.md) | Overview shipped with the hook scripts. |
| [Repository instructions](AI-Instructions.md) | Rules for maintaining this repository. |

## Build Script

Run the matching command from the repository root:

PowerShell:
```powershell
.\scripts\commands\build.ps1
```

Bash:
```bash
./scripts/commands/build.sh
```

Rebuild when shared definitions, adapters, or generation logic change. Choose other verification according to the
change's risk; documentation-only edits do not require a build. Building writes reproducible packages below
`generated/` and may use temporary validation files; it does not install global user configuration.

## Installation Script

The installer asks for the target shell and client, unless they are passed as parameters, then refuses to continue
if any selected destination is already installed (`Already installed, use the update script.`). Selecting PowerShell or
Bash chooses the generated package format; installation always targets the current user's home directory. This
check is skipped for a dry run, so previewing always works regardless of prior install state.

Preview an installation without changing user files, backups, or plugins:

PowerShell:
```powershell
.\scripts\commands\install.ps1 -DryRun
```

Bash:
```bash
./scripts/commands/install.sh --dry-run
```

Install the selected configuration interactively:

PowerShell:
```powershell
.\scripts\commands\install.ps1
```

Bash:
```bash
./scripts/commands/install.sh
```

Omitting either target parameter opens its selection prompt. There is no automatic shell default.
For a noninteractive preview, supply both target parameters together with `-DryRun` or `--dry-run`.

Every installed file is tracked in a per-destination manifest (`.ai-config-manifest.tsv`). On update, unchanged files
are not written or backed up. Files still shipped by the package are replaced when their content differs, including
local edits; the previous content is backed up first. An untracked file at a package target path is also backed up
and replaced, with a warning. Untracked files outside package target paths are left alone.

Previously managed files no longer shipped are backed up and removed if unchanged. If locally modified, they are
backed up and retained with a warning. Backups are stored under `backups/<timestamp>/` in each destination.
Local Codex `model`, `model_reasoning_effort`, `plugins`, and `marketplaces` settings are preserved when syncing `config.toml`;
other local settings are not generally merged. Dry runs still rebuild `generated/`, but do not modify installation destinations.

Selecting Codex also installs shared skills to `.agents/skills`. An interactive extension list includes plugins and
Codex skills; unchecked extensions are skipped on installation. Normal runs also ask whether to update
the selected client CLIs, enable Flashbang, and enable Qwen3 semantic retrieval. These choices are saved for Quickupdate.
Disabling retrieval on a later update removes its setup-owned runtime and index. Dry runs preview
changes without updating CLIs, extensions, or retrieval. See [Plugins](docs/plugins.md) for client-specific behavior.

Install also always asks `Uninstall Codex/Claude/Both and reinstall via npm?` (default no), scoped to whatever client
was selected. This choice is independent of the "update selected agent CLIs" choice above, is never saved, and is not
asked again by Quickupdate or by the update script. Answering yes uninstalls and reinstalls, per selected client, the
matching CLI (`@openai/codex` for Codex, `@anthropic-ai/claude-code` for Claude) through `npm uninstall -g`
followed by `npm install -g <package>@latest`, when that CLI is currently found as a global npm package. When it is
not (for example, installed through a native installer or another package manager), that prior installation is left
in place with a warning, and only a fresh `npm install -g` is run alongside it. Codex is skipped with a warning while
`codex.exe` is running. A dry run never asks this question and never previews it, since the choice is not persisted.

## Update Script

Once a destination is installed, use the update script (not the installer) to refresh its files and plugins. It refuses
to continue if any selected destination is not installed yet (`Not installed, use the install script.`), also skipped
for a dry run.

PowerShell:
```powershell
.\scripts\commands\update.ps1
```

Bash:
```bash
./scripts/commands/update.sh
```

It accepts the same `-DryRun`/`--dry-run`, `-Client`/`--client`, and `-Shell`/`--shell` parameters as the
installer, re-syncs every managed file, and lets you revise the CLI update, Flashbang, retrieval, and extension choices.
Selected extensions are installed or updated. Deselection removes only extensions recorded as installed by this
setup; pre-existing or manually installed extensions are retained. Quickupdate reuses the saved choices.

## Uninstall Script

Remove everything this setup previously installed for the selected client(s): managed files tracked in each
destination's manifest, extensions and skills recorded in the extension ledger, an enabled semantic retrieval setup,
and the saved Quickupdate selection (once no destination remains installed for any client).

PowerShell:
```powershell
.\scripts\commands\uninstall.ps1
```

Bash:
```bash
./scripts/commands/uninstall.sh
```

Omitting `-Client`/`--client` opens the same selection prompt as install and update. Uninstall refuses to continue
if none of the selected destinations are installed (`Not installed, nothing to uninstall.`), unless previewing with
`-DryRun`/`--dry-run`, which always works and never changes anything.

Because this removes configuration rather than adding it, a real run asks for confirmation (`Continue? [y/N]`) before
touching anything, unless `-Force`/`--force` is passed; running without a terminal attached and without `-Force`/`--force`
fails instead of hanging. Removal reuses the same manifest-sync logic as install and update: every managed file is
backed up under `backups/<timestamp>/` before removal, and a file changed locally since the last install/update is
backed up but left in place with a warning instead of being deleted. Files this setup never installed are never
touched. A destination directory is only deleted once it is fully empty; backups already on disk are always kept.
Extensions and skills recorded in the ledger are removed the same way `update` removes a deselected extension:
pre-existing or manually installed ones outside the ledger are left alone, and a skill file modified since it was
installed is kept with a warning. An enabled semantic retrieval setup is disabled and its setup-owned runtime and
index removed for the selected client(s). The saved Quickupdate selection (`~/.my-ai-configuration/selection.json`)
is only removed once uninstalling leaves no client installed at all, so uninstalling just one client out of a
`Both` installation keeps the saved choices for the client that remains.

Uninstall does not remove the CLI tools themselves (`codex`, `claude`), any plugin marketplace registrations they
keep outside this setup's ledger, or files this setup never installed.

## Configuration overview

Codex and Claude Code receive the same shared rules, skills, agents, hooks, and status data. Codex loads applicable rules from generated files, while Claude Code exposes technology- and situation-specific rules as generated skills.

The default configuration keeps writes workspace-scoped and enables automatic review for eligible escalation requests. Both clients include the same logical agent roles and compact status displays. See [Configuration](docs/configuration.md) for settings, permissions, and limitations.

## Support

Create an [issue](https://git.lechner-systems.at/fraujulian/MyAiConfiguration/issues) for problems or proposed changes.

## Contributors

~ [**FrauJulian - Julian Lechner**](https://fraujulian.xyz/)

## License

Licensed under the [MIT License](LICENSE).
