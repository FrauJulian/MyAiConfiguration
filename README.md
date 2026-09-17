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

Check the selected shell's minimum version and required Python and `jq` tools before setup. The command exits with an error when a requirement is missing.

PowerShell:

```powershell
.\scripts\check-capabilities.ps1
```

Bash:

```bash
./scripts/check-capabilities.sh
```

## Quickstart

With the [requirements](#requirements) installed, clone the repository, build it, then install it.
Stop if any command fails. Installation asks for the shell, client, CLI update, Flashbang, and extension choices.

PowerShell:

```powershell
git clone https://git.lechner-systems.at/fraujulian/MyAiConfiguration.git
cd MyAiConfiguration
.\scripts\build.ps1 -Summary
.\scripts\install.ps1 -Summary
```

Bash:

```bash
git clone https://git.lechner-systems.at/fraujulian/MyAiConfiguration.git
cd MyAiConfiguration
./scripts/build.sh --summary
./scripts/install.sh --summary
```

For an already-installed configuration, use Quickupdate instead.

## Quickupdate

Run these commands from the repository root. Quick reuses the shell, client, CLI update, Flashbang, and extension choices from the last
successful installation or update without opening selection menus. Stop if any command fails.

PowerShell:

```powershell
git pull --ff-only
.\scripts\build.ps1 -Summary
.\scripts\update.ps1 -Quick -Summary
```

Bash:

```bash
git pull --ff-only
./scripts/build.sh --summary
./scripts/update.sh --quick --summary
```

If no selection has been saved yet, or it predates the CLI update and Flashbang options, Quick stops with a hint. Run `scripts/update.ps1` or `./scripts/update.sh` once
without Quick to save your choices. They are stored in `~/.my-ai-configuration/selection.json`; dry runs and failed
runs do not overwrite them. To change the selection later, run a normal update again. Quick does not automatically
select newly added plugins.

Install and update also rebuild internally; the explicit build above lets you check the packages before installation.

## Documentation

| Document | Contents |
| --- | --- |
| [Architecture](docs/architecture.md) | Shared sources, adapters, generated packages, and installation. |
| [Configuration](docs/configuration.md) | Client settings, permission defaults, status displays, and verification. |
| [Plugins](docs/plugins.md) | Plugin sources, selection, installation, updates, and removal. |
| [Hooks](docs/hooks.md) | Registered events, session-state helpers, notifications, and optional utilities. |
| [Agents](docs/agents.md) | Agent roles and when delegation is useful. |
| [Skills](docs/skills.md) | Skill categories and conditional rule loading. |
| [Codex adapter](adapters/codex/README.md) | Codex-specific configuration files. |
| [Claude Code adapter](adapters/claude/README.md) | Claude-specific configuration files. |
| [Hook package](shared/hooks/README.md) | Overview shipped with the hook scripts. |
| [Repository instructions](AI-Instructions.md) | Rules for maintaining this repository. |

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
- Separate install and update scripts: install refuses to run against an already-installed destination, update refuses
  to run against one that is not installed yet.
- User-level plugin installation for Ponytail, i-have-adhd, Superpowers, Context7, Caveman, QMD, Humanizer, Impeccable, and
  Anthropic Frontend Design, with an interactive extension toggle during both install and update. Only extensions
  integrations installed and recorded by this setup can be removed through deselection.
- Optional local semantic retrieval for both clients using Qwen3-Embedding-0.6B, disabled by default and removable
  through the install/update choice.

## Architecture

```text
shared definitions -> client adapters -> generated packages -> user installation
```

| Directory | Purpose |
| --- | --- |
| `shared/` | Client-independent rules, agents, skills, hooks, status lines, and global instructions. |
| `adapters/` | Codex and Claude Code formats, settings, templates, and the plugin manifest. |
| `generated/` | Reproducible PowerShell and Bash packages. This directory is ignored by Git. |
| `scripts/` | Build, installation, update, diagnosis, and shell validation entry points. |
| `docs/` | Focused documentation about the configuration design. |

The build creates:

```text
generated/
|-- codex-powershell/
|-- claude-powershell/
|-- codex-bash/
`-- claude-bash/
```

## Requirements

- PowerShell 5.1 or newer; PowerShell 7 is supported as well.
- Bash 4.3 or newer, with standard utilities such as `awk`, `sed`, and `sha256sum`.
- Python 3.11 or newer for configuration validation and task-state hooks/helpers (`python` for PowerShell scripts, `python3` for Bash scripts).
- `jq` for Claude's Bash status line; without it, that status line produces no output.
- Python `venv` and `pip` when the optional semantic retrieval layer is enabled.
- Node.js 22 or newer and `npm` when QMD is selected.

The Bash scripts do not require PowerShell. The PowerShell scripts remain compatible with PowerShell 5.1;
PowerShell 7 can also run them.

## Build

Run the matching command from the repository root:

PowerShell:
```powershell
.\scripts\build.ps1
```

Bash:
```bash
./scripts/build.sh
```

Rebuild when shared definitions, adapters, or generation logic change. Choose other verification according to the
change's risk; documentation-only edits do not require a build. Building writes reproducible packages below
`generated/` and may use temporary validation files; it does not install global user configuration.

## Installation

The installer asks for the target shell and client, unless they are passed as parameters, then refuses to continue
if any selected destination is already installed (`Already installed, use the update script.`). Selecting PowerShell or
Bash chooses the generated package format; installation always targets the current user's home directory. This
check is skipped for a dry run, so previewing always works regardless of prior install state.

Preview an installation without changing user files, backups, or plugins:

PowerShell:
```powershell
.\scripts\install.ps1 -DryRun 
```

Bash:
```bash
./scripts/install.sh --dry-run 
```

Install the selected configuration interactively:

PowerShell:
```powershell
.\scripts\install.ps1 
```

Bash:
```bash
./scripts/install.sh 
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
Disabling retrieval on a later update removes its setup-owned runtime, index, and MCP registrations. Dry runs preview
changes without updating CLIs, extensions, or retrieval. See [Plugins](docs/plugins.md) for client-specific behavior.

## Update

Once a destination is installed, use the update script (not the installer) to refresh its files and plugins. It refuses
to continue if any selected destination is not installed yet (`Not installed, use the install script.`), also skipped
for a dry run.

PowerShell:
```powershell
.\scripts\update.ps1 
```

Bash:
```bash
./scripts/update.sh 
```

It accepts the same `-DryRun`/`--dry-run`, `-Client`/`--client`, and `-Shell`/`--shell` parameters as the
installer, re-syncs every managed file, and lets you revise the CLI update, Flashbang, and extension choices.
Selected extensions are installed or updated. Deselection removes only extensions recorded as installed by this
setup; pre-existing or manually installed extensions are retained. Quickupdate reuses the saved choices.

## Doctor

Check client availability, generated packages, source directories, hooks, and installed managed files:

PowerShell:
```powershell
.\scripts\doctor.ps1 
```

Bash:
```bash
./scripts/doctor.sh 
```

Use `-Summary` (PowerShell) or `--summary` (Bash) with build, doctor, install, update, and test scripts for compact output.
Omit the flag for detailed output. Summary mode retains warnings and failure status, but can suppress captured
plugin-command output on failure. Set `AI_CONFIG_VERBOSE=1` when full plugin failure output is needed.

## Configuration

Codex receives global instructions, rules, skills, agent TOML files, hooks, and `config.toml`. Its defaults keep writes
workspace-scoped and use automatic review for eligible escalation requests. Every rule ships as a plain file under
`rules/`, and `AGENTS.md` tells Codex to load the matching one by path.

Claude Code receives the equivalent global instructions, agents, hooks, and `settings.json`. General rules are embedded
once in `CLAUDE.md` (and in Codex's `AGENTS.md`); every technology- or
situation-specific rule (`adapters/rule-skills.tsv`) is generated as a skill under `skills/rules/` instead, so
only its name and description are permanently visible and the full rule text loads only when Claude invokes it. Its
generated settings use the supported automatic permission mode where available.

Both clients receive the same logical agent roles:

- Architect
- Implementer
- Researcher
- Reviewer
- Verifier

Agent use is proportional to the task. Small changes can stay with the implementer, while additional roles are available
when research, design, independent review, or focused verification adds value.

Verification is also proportional: the agent selects checks based on changed behavior, affected callers, risk,
and uncertainty. A small change may need only focused inspection; builds, tests, and separate reviews are not
automatic. Explicit user and project requirements still apply.

Both status displays include model, effort, repository, branch, context-window size, context used, and tokens used.
Codex shows its review mode. Claude also shows its review mode in two colored lines, with context usage
turning yellow at 60% and red at 85%. See
[Configuration](docs/configuration.md) for details and limitations.

## Extending the Configuration

### Add a rule

Create a focused Markdown file in `shared/rules/`. For a rule that applies only to a language, framework, tool, or
change area, add one row to `adapters/rule-skills.tsv`. The build uses that manifest to generate both Claude's
rule skill and Codex's rule-loading condition. Put always-applicable guidance in `general.md`, which the build embeds
for both clients; a new rule file is not automatically embedded.

### Add a skill

Create `shared/skills/<category>/<skill>/SKILL.md` with valid YAML frontmatter and a concise workflow. Reference shared
rules instead of repeating persistent standards.

### Add an agent

Create `shared/agents/<agent>/agent.yml` and `instructions.md`. Keep semantic behavior in these shared files; the build
renders the Codex and Claude Code formats.

Rebuild after every semantic change.

## Security

- Never store API keys, OAuth tokens, credentials, authentication state, or sensitive logs in this repository.
- Review generated output and use the installer's dry-run before installation.
- Global installation happens only through an explicit installer invocation.
- Plugins execute with permissions granted by their client; review their upstream sources and trust prompts.
- Codex keeps workspace sandboxing enabled and requires escalation outside expected development boundaries.

## Support

Create an [issue](https://git.lechner-systems.at/fraujulian/MyAiConfiguration/issues) for problems or proposed changes.

## Contributors

~ [**FrauJulian - Julian Lechner**](https://fraujulian.xyz/)

## License

Licensed under the [MIT License](LICENSE).
