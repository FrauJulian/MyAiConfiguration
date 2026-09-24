# Skills

Skills are reusable workflows. Rules are persistent constraints and agents are specialized roles. Each skill is a minimal `SKILL.md` with YAML frontmatter and a small initial workflow so both clients can consume it.

The current structure is organized by purpose:

- `debugging/`
- `planning/`: implementation planning, impact analysis, and work-item definition
- `research/`: technical and repository research
- `reviews/`: code, security, performance, WPF, UI/UX, business, API, and EF Core reviews
- `implementation/`: SQL, unit-test, and integration-test writing
- `verification/`: facts, work-item, and regression verification
- `git/`: pull request reviews

Each skill defines a focused workflow with the investigation, decision points, and output expected for that task. Keep guidance specific to the skill; shared repository constraints belong in the rules.

Claude's generated package additionally has `skills/rules/`: one skill per focused rule file or directory in
`shared/rules/`. The rule-to-skill loading conditions live in `shared/global-instructions.md`, so full rule text loads
only when Claude invokes a matching skill instead of sitting permanently in context. Codex reads the matching rule
files directly. Both clients embed the general rules in their global instructions.
Split Angular, WPF, and UI/UX rules load supporting references only for the topic being worked on. See [Configuration](configuration.md).

Skills guide a task when needed; their availability does not require a full review, build, or test suite after every
change. The shared Verification rules govern proportional checking, including when generic skill workflows call
for more work than the change needs.
