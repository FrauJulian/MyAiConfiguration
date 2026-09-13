# My AI Configuration

![OpenAI Codex](https://img.shields.io/badge/OpenAI-Codex-000000)
![Claude Code](https://img.shields.io/badge/Anthropic-Claude_Code-D97757)
![Windows](https://img.shields.io/badge/Windows-PowerShell_5.1%2B-0078D4)
![Linux](https://img.shields.io/badge/Linux-Bash-FCC624)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`MyAiConfiguration` is a version-controlled global user configuration for OpenAI Codex and Claude Code.

It keeps rules, skills, agents, hooks, and orchestration guidance in shared source files. Client adapters turn those files
into platform-specific packages that can be inspected before they are installed.

## Features

- One shared source of truth for Codex and Claude Code.
- Separate generated packages for Windows and Linux.
- Native PowerShell 5.1 and Bash scripts.
- Interactive or non-interactive (`-Client`/`-Platform`) installation for Codex, Claude Code, or both.
- Claude Code loads technology- and situation-specific rules as skills, so only their name and description sit
  permanently in context; the full rule text loads only when the skill is invoked. Codex keeps loading rules as plain
  files, unchanged.
- A managed-file manifest (path and SHA-256 per destination) makes installation idempotent, detects files this setup
  previously installed but no longer ships, and protects files a user changed locally instead of silently overwriting
  or deleting them.
- Dry-run support (no writes, no backups, no plugin changes) and timestamped, per-run backup directories.
- Shared safety, notification, validation, and status-line hooks.
- User-level plugin installation for Ponytail, i-have-adhd, Superpowers, Context7, Caveman, Humanizer, Impeccable,
  and Anthropic Frontend Design; updates only with
  `-UpdatePlugins`/`--update-plugins`.

## Architecture

```text
shared definitions -> client adapters -> generated packages -> user installation
```

| Directory | Purpose |
| --- | --- |
| `shared/` | Client-independent rules, agents, skills, hooks, status lines, and global instructions. |
| `adapters/` | Codex and Claude Code formats, settings, templates, and the plugin manifest. |
| `generated/` | Reproducible Windows and Linux packages. This directory is ignored by Git. |
| `scripts/` | Build, installation, diagnosis, and platform validation entry points. |
| `docs/` | Focused documentation about the configuration design. |

The build creates:

```text
generated/
├── codex-windows/
├── claude-windows/
├── codex-linux/
└── claude-linux/
```

## Requirements

- Windows PowerShell 5.1 or newer on Windows.
- Bash on Linux.
- The Codex and Claude Code CLIs for the clients that should be installed or diagnosed.
- Network access for plugin installation and updates.

The Bash scripts do not require PowerShell. The PowerShell scripts remain compatible with Windows PowerShell 5.1;
PowerShell 7 can also run them.

## Build

Run the matching command from the repository root:

Powershell: (Windows)
```powershell
.\scripts\build.ps1
```

Bash: (Linux)
```bash
./scripts/build.sh
```

Every repository change must pass the build before completion. Building only writes reproducible files below
`generated/`; it does not modify global user configuration.

## Installation

The installer runs a fresh build and then asks for the target platform and client, unless they are passed as
parameters. Selecting Linux or Windows chooses the generated package format; installation always targets the current
user's home directory.

Preview an installation without changing user files, backups, or plugins:

Powershell: (Windows)
```powershell
.\scripts\install.ps1 -DryRun
```

Bash: (Linux)
```bash
./scripts/install.sh --dry-run
```

Install the selected configuration interactively:

Powershell: (Windows)
```powershell
.\scripts\install.ps1
```

Bash: (Linux)
```bash
./scripts/install.sh
```

Install non-interactively, for scripting or CI:

Powershell: (Windows)
```powershell
.\scripts\install.ps1 -Client Both -Platform Windows
```

Bash: (Linux)
```bash
./scripts/install.sh --client both --platform linux
```

`-Platform`/`--platform` defaults to the current platform when omitted together with `-Client`/`--client`.

Every installed file is tracked in a per-destination manifest (`.ai-config-manifest.tsv`). A second run of the same
installation is a no-op for unchanged files (no write, no backup). A file this setup installed before but no longer
ships is backed up and removed, unless it was changed locally since the last install, in which case it is backed up
and left in place with a warning instead. A file the installer never tracked is never touched, even if a file of the
same name is now part of the package. Backups land in a single timestamped directory per run under
`backups/<timestamp>/` inside each destination.

Selecting Codex also installs shared skills to `.agents/skills`. A normal installation only installs plugins that are
missing; add `-UpdatePlugins`/`--update-plugins` to also update and enable plugins that are already installed.

Run the same installation command whenever the repository configuration should be updated. There is no separate update
script.

## Doctor

Check client availability, generated packages, source directories, hooks, and installed managed files:

Powershell: (Windows)
```powershell
.\scripts\doctor.ps1
```

Bash: (Linux)
```bash
./scripts/doctor.sh
```

The doctor reports concise `PASS`, `WARN`, and `FAIL` results without reading or printing credentials.

## Configuration

Codex receives global instructions, rules, skills, agent TOML files, hooks, and `config.toml`. Its defaults keep writes
workspace-scoped and use automatic review for eligible escalation requests. Every rule ships as a plain file under
`rules/`, and `AGENTS.md` tells Codex to load the matching one by path.

Claude Code receives the equivalent global instructions, agents, hooks, and `settings.json`. Only `general.md` ships as
an always-applied rule file (its content is also embedded directly in `CLAUDE.md`); every technology- or
situation-specific rule (`adapters/claude/rule-skills.tsv`) is generated as a skill under `skills/rules/` instead, so
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

## Extending the Configuration

### Add a rule

Create a focused Markdown file in `shared/rules/`. For a rule that applies only to a language, framework, tool, or
change area, add a row to `adapters/claude/rule-skills.tsv` (Claude generates it as a skill) and add its loading
condition to the Codex rule-loading text in `scripts/build.ps1`/`scripts/build.sh` (Codex loads it as a plain file, by
path — unchanged from before). A rule that should always apply, like `general.md`, needs neither.

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
