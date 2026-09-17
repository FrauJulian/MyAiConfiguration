# Skills

Skills are reusable workflows. Rules are persistent constraints and agents are specialized roles. Each skill is a minimal `SKILL.md` with YAML frontmatter and a small initial workflow so both clients can consume it.

The current structure is organized by purpose:

- `debugging/`
- `planning/`: implementation planning, impact analysis, and work-item definition
- `research/`: technical and repository research
- `reviews/`: code, security, performance, WPF, UI/UX, business, API, and EF Core reviews
- `implementation/`: SQL, unit-test, and integration-test writing
- `verification/`: facts, work-item, and regression verification
- `git/`: pull request responses and reviews

The files intentionally define only a small baseline. Detailed personal workflows and standards can be added later without changing the structure.

Claude's generated package additionally has `skills/rules/`: one skill per technology- or situation-specific rule in
`shared/rules/` (driven by the shared `adapters/rule-skills.tsv` manifest), so the full rule text loads only when Claude invokes the
matching skill instead of sitting permanently in context. This category does not exist for Codex, which keeps loading
applicable focused rules as plain files instead. Both clients embed the general rules in their global instructions.
Split Angular, WPF, and UI/UX rules load supporting references only for the topic being worked on. See [Configuration](configuration.md).

Skills guide a task when needed; their availability does not require a full review, build, or test suite after every
change. The shared Verification rules govern proportional checking, including when generic skill workflows call
for more work than the change needs.
