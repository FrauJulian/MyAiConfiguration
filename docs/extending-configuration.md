# Extending the configuration

Shared definitions are the source of truth. Rebuild after every semantic change.

## Add a rule

Create cross-cutting rules such as Git or Microsoft guidance as focused Markdown files directly in `shared/rules/`. Put each language, framework, or library in its own directory with an `index.md` and focused files under `references/`; put security rules in `shared/rules/security/`. Add the matching loading condition and generated Claude skill name to `shared/global-instructions.md` and the directory index. The build copies rule trees to Codex and generates Claude skills from each rule file. Put always-applicable guidance in `general.md`, which the build embeds for both clients; a new rule file is not automatically embedded.

## Add a skill

Create `shared/skills/<category>/<skill>/SKILL.md` with valid YAML frontmatter and a concise workflow. Reference shared rules instead of repeating persistent standards.

## Add an agent

Create `shared/agents/<agent>/agent.yml` and `instructions.md`. Keep semantic behavior in these shared files; the build renders the Codex and Claude Code formats.
