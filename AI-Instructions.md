# AI instructions

This file contains maintenance instructions for this repository only. It is not
part of the generated Codex or Claude Code configuration and must not be read
or processed by build output.

## Architecture

Keep the architecture as:

`shared definitions -> client adapters -> generated output -> optional installation`

- Modify shared definitions first.
- Keep adapters limited to client-specific formats and metadata.
- Do not duplicate shared behavior in adapters.
- Treat `generated/` as reproducible build output.
- Maintain equivalent support for both Codex and Claude Code.
- Keep technology-specific rules in separate files under `shared/rules/`.
- Generate those rule files beside `AGENTS.md` and `CLAUDE.md`; load them only when their subject applies.

## Portability

- Design scripts, hooks, generated configuration, and installation behavior for both Windows and Linux.
- Use cross-platform tools and paths where practical.
- When platform-specific behavior is necessary, provide an equivalent implementation or a safe no-op for the other supported platform.
- Provide equivalent native Bash (`.sh`) and PowerShell (`.ps1`) entry points for every script and hook.
- Support Windows PowerShell 5.1 and newer on Windows, and PowerShell 7 (`pwsh`) on Linux. Keep shared PowerShell syntax compatible with 5.1; Windows must not require PowerShell 7.
- Validate relevant changes on both supported platforms when practical.

## Language

Write all repository content, generated instructions, scripts, prompts, documentation, and user-facing script output in English.

## Workflow

- Run `scripts/build.ps1` to validate every project change before completion.
- Rebuild generated output after semantic changes.
- Run `scripts/doctor.ps1` when changes affect generated output, installation, client configuration, hooks, or environment validation.
- Preserve backward compatibility where practical.
- Keep changes focused on the requested configuration behavior.

## Instruction sources

- Define repository-maintenance rules only in `AI-Instructions.md`.
- Keep the repository-root AGENTS.md and CLAUDE.md as pointer-only files.
- Keep generated global instructions in shared/global-instructions.md; the build copies that file into each generated client package.
- Do not include `AI-Instructions.md` in generated output.

## Installation and security

- Do not install global configuration automatically.
- Perform global installation only after explicit user instruction, using `scripts/install.ps1` so replaced managed files are backed up.
- Do not add project-specific rules, secrets, credentials, authentication state, or generated runtime state.

## Version control

- Never commit changes unless explicitly instructed.
- Preserve unrelated user changes.


