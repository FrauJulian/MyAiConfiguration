# Skills

Skills are reusable workflows. Rules are persistent constraints and agents are specialized roles. Each skill has a readable `SKILL.md` with YAML frontmatter; detailed guidance may live in that file or its `references/` directory.

The current structure is organized by purpose:

- `planning/`: impact analysis and work-item definition
- `research/`: mandatory `research` gate for every search, with technical and repository specialists, plus `semantic-search`, which is installed only while local QMD search is enabled
- `reviews/`: security, performance, WPF, UI/UX, business, API, and EF Core reviews
- `implementation/`: SQL, unit-test, and integration-test writing
- `verification/`: facts and work-item verification
- `git/`: pull request reviews
- `content-strategy/`, `copy-editing/`, `copywriting/`: planning, editing, and writing text
- `image/`, `site-architecture/`: visuals and website structure
- `marketing-psychology/`, `offers/`, `product-marketing/`, `cro/`: audience understanding, value framing, and conversion

General planning, debugging, code review, and completion verification workflows come from Superpowers, so the catalog does not duplicate their triggers. The remaining skills cover focused domains Superpowers does not.

Each skill defines a focused workflow with the investigation, decision points, and output expected for that task. Keep guidance specific to the skill; shared repository constraints belong in the rules.

The single catalog in `shared/skills/` includes development skills and focused skills for writing, images, content and site structure, positioning, psychology, and conversion. Builds include every retained skill for both clients. Updating a managed installation backs up and removes unchanged setup-owned skills deleted from the catalog; local changes are backed up and retained.

Claude discovers only `skills/<name>/SKILL.md`, so its generated package flattens the categorized catalog to one directory per skill name, together with the skill's `references/`; the build fails on duplicate names or a `name` that differs from its directory. Claude's package additionally has a `rules-*` skill for each focused rule file or directory in
`shared/rules/`. The rule-to-skill loading conditions live in `shared/global-instructions.md`, so full rule text loads
only when Claude invokes a matching skill instead of sitting permanently in context. Codex reads the matching rule
files directly. Both clients embed the general rules in their global instructions.
Language, framework, library, and security rules use directory indexes plus focused topic files. Their generated Claude skills expose each focused rule separately; the index skills also include the references for contextual lookup. See [Configuration](configuration.md).

Every search or lookup must use `research` and the applicable specialist, including direct reads, exact matches, familiar areas, and follow-up queries during implementation or verification. Loaded instructions can be reused; their checks apply to each search. Semantic retrieval runs first for unknown repository identifiers; known identifiers still use direct reads or `rg` within the research workflow. Disabling QMD does not disable the research requirement. These are agent instructions, not a runtime tool interceptor.

Context7 phase checkpoints are defined once in `research/technical-research/SKILL.md`. Focused planning, SQL and test-writing, and verification skills call them explicitly, as do the architect, implementer, and verifier roles. The global rule applies the same checkpoints inside Superpowers and other plugin workflows without modifying upstream plugin caches or duplicating general workflow skills. Planning verifies external assumptions before accepting a design; implementation checks them against actual versions before coding; verification requires both applicable source evidence and proportionate execution results. Evidence travels in the existing plan or handoff and is reused across phases when the behavior, version, and environment match. Queries contain only public, sanitized concepts, use bounded timeouts and refinement, and report source fallback or unresolved gaps explicitly. This enforces an instruction contract; it does not guarantee model compliance or add network calls to builds and tests.

Other skills guide a task when needed; their availability does not require a full review, build, or test suite after every
change. The shared Verification rules govern proportional checking, including when generic skill workflows call
for more work than the change needs.
