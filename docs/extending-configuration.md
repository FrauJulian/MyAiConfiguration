# Extending the configuration

Shared definitions are the source of truth. Rebuild after every semantic change.

## Add a rule

Create a focused Markdown file in `shared/rules/` and add its loading condition to `shared/global-instructions.md`. Claude rule skills are generated from the rule filenames; Codex loads the referenced rule files directly. Put always-applicable guidance in `general.md`, which the build embeds for both clients; a new rule file is not automatically embedded.

## Add a skill

Create `shared/skills/<category>/<skill>/SKILL.md` with valid YAML frontmatter and a concise workflow. Reference shared rules instead of repeating persistent standards.

## Add an agent

Create `shared/agents/<agent>/agent.yml` and `instructions.md`. Keep semantic behavior in these shared files; the build renders the Codex and Claude Code formats.
