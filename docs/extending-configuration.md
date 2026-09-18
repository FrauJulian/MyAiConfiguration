# Extending the configuration

Shared definitions are the source of truth. Rebuild after every semantic change.

## Add a rule

Create a focused Markdown file in `shared/rules/`. For a rule that applies only to a language, framework, tool, or change area, add one row to `adapters/rule-skills.tsv`. The build uses that manifest to generate both Claude's rule skill and Codex's rule-loading condition. Put always-applicable guidance in `general.md`, which the build embeds for both clients; a new rule file is not automatically embedded.

## Add a skill

Create `shared/skills/<category>/<skill>/SKILL.md` with valid YAML frontmatter and a concise workflow. Reference shared rules instead of repeating persistent standards.

## Add an agent

Create `shared/agents/<agent>/agent.yml` and `instructions.md`. Keep semantic behavior in these shared files; the build renders the Codex and Claude Code formats.
