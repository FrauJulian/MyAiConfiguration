# Token-Efficiency Improvements — Design

Historical design approved on 2026-09-16, retained to explain the original decisions. It is not a description of every current behavior. Later changes supersede its blanket validation steps; see [AI-Instructions.md](../../../AI-Instructions.md), [Configuration](../../configuration.md), and the [README](../../../README.md) for current guidance.

## Goal

Reduce unnecessary token consumption in both Claude Code and Codex — script
output copied into agent context, rule/skill content loaded when not needed,
duplicated instructions loaded on every task, and delegation that duplicates
context — without weakening correctness, security, or verification quality.

## 1. Quiet output mode for scripts

Add `-Summary` (PowerShell) / `--summary` (Bash) to `build`, `doctor`,
`install`, `update`, and the `test-*` scripts.

- Purely an output-verbosity switch. Orthogonal to `-Client`/`-Platform`
  (interactivity is unaffected — a quiet run without `-Client`/`-Platform`
  still prompts) and to `-DryRun` (dry-run keeps its existing defaults;
  `-Summary -DryRun` just makes the preview more compact).
- On success: suppress the low-value per-item lines (`SOURCE`, `CREATE`,
  `UPDATE`, `UNCHANGED`, per-plugin `PASS ... ensured/already installed`,
  per-doctor-check `PASS`) and print one summary line instead:
  - `Build: PASS | 4 packages`
  - `Doctor: PASS | <n> checks`
  - `Tests: PASS | <n>/<n>`
  - `Install: PASS | <client>, <platform>` / `Update: PASS | <client>, <platform>`
- Never suppress: `WARN`, `FAIL`, thrown errors, interactive prompts, or the
  plugin toggle list. Warnings/errors always print in full regardless of the
  flag.
- Implementation: each script gains a `$Summary`/`summary` bool threaded into
  the existing `Write-Output`/`printf` call sites in `scripts/lib/manifest.*`
  and `scripts/lib/plugins.*` (guard the per-item lines), plus a tally +
  one-line footer at the end of `build.*`, `doctor.*`, `install.*`,
  `update.*`, and each `test-*.*`.

## 2. Progressive disclosure for large rules

Split only the three rules that are 2-3x larger than the rest and have
clearly separable, independently-invokable subtopics:

- `angular.md` (297 lines) → components, templates, signals, rxjs,
  dependency-injection-and-services, forms-and-routing, testing
- `wpf.md` (375 lines) → mvvm-and-binding, commands-and-async,
  collections-and-virtualization, xaml-and-layout, resources-and-lifecycle,
  testing-and-quality
- `ui-ux.md` (306 lines) → navigation-and-actions, forms, content-and-feedback,
  visual-and-accessibility, tables-search-dialogs, destructive-and-error-prevention

`git.md`, `typescript.md`, `csharp.md`, `refactoring.md`, `microsoft.md`
(116-167 lines) stay single-file — splitting them adds a read hop without
materially cutting tokens.

Structure per split rule: `shared/rules/<name>/index.md` (small: universal/
high-value rules + a short table telling the agent which `references/*.md`
to open for which subtopic) + `shared/rules/<name>/references/*.md`.

- Claude: `skills/rules/<skill_name>/SKILL.md` = generated frontmatter (from
  `rule-skills.tsv`, unchanged mechanism) + `index.md` body; `references/`
  copied alongside into the same skill directory (already documented Anthropic
  pattern; `Copy-Directory` already ships arbitrary sibling files, so no new
  copy mechanism needed — only the generation loop needs to read `index.md`
  instead of a flat file when `rule_file` in the manifest names a directory).
- Codex: `rules/<name>/index.md` + `rules/<name>/references/*.md`; the path
  in `AGENTS.md`'s rule-loading heredoc (`scripts/build.ps1`/`build.sh`)
  changes from `rules/<name>.md` to `rules/<name>/index.md` for these three.
- `adapters/claude/rule-skills.tsv` stays the single source of truth for
  trigger wording — no new duplication.
- Build-script change: detect whether `shared/rules/<rule_file>` resolves to
  a file or a directory; directory ⇒ read `<dir>/index.md` as the body and
  copy the whole `<dir>/` (including `references/`) instead of a single file.

## 3+4. Narrower triggers and canonical rule locations (same fix)

Root cause found in the current build: `general.md` is embedded in full into
`CLAUDE.md` (`build.ps1`/`build.sh`, unconditional, every task) but for Codex
is only *referenced by path* ("Always load `rules/general.md`"—Codex must
actively read it). `shared/global-instructions.md` separately re-paraphrases
Priority, Documentation/Comments, and decision-making content inline — so
`decision-rule.md`'s substance is already permanently loaded for both
clients today, never actually lazy, defeating its own skill/file-based
lazy-loading.

Changes:

- Embed `general.md` in full into `AGENTS.md` too (mirror what `CLAUDE.md`
  already does). Remove the "Always load `rules/general.md`" instruction —
  no longer needed. This is strictly safer, not riskier, for Codex even
  though subagent AGENTS.md inheritance is undocumented/unconfirmed
  (researched): today, if a Codex subagent doesn't inherit AGENTS.md, it
  already can't see the *instruction* to go read `general.md` either, so
  embedding changes nothing for that case, and strictly helps the case where
  it does inherit (guaranteed-present vs. requires-a-read-action).
- Trim `shared/global-instructions.md` to just the rule-loading block and the
  (rewritten, see §5) orchestration paragraph. Delete the restated
  Priority/Documentation/Comments/decision-making prose — `general.md` (now
  embedded for both clients, always) is the single canonical source.
- `general.md` gains one short pointer line to the decision-rule skill/file
  for actual ambiguity, replacing the removed inline paragraph — keeps
  decision-making guidance genuinely lazy (loads only when ambiguity is
  actually present), which is exactly the item-3 goal for `decision-rule.md`.
- `definition-of-done.md`'s two bullets that restate the documentation rule
  (lines 19-20) collapse to one line referencing `general.md`'s Documentation
  section instead of repeating it.
- `shared/agents/*/instructions.md` (the 3-line per-role files) stay
  unchanged. Researched: Claude subagents fully inherit CLAUDE.md (redundant
  there), but Codex subagent AGENTS.md inheritance is unconfirmed/
  undocumented — these files feed both clients' agent definitions from one
  shared source, and for Codex the one-line "no comments" reminder inside
  `developer_instructions` is the only guaranteed-present copy if inheritance
  turns out not to hold. Cost is 3 lines; not worth the risk to trim.
- `security.md`'s broad trigger ("any software development task") is left
  as-is — it's already the documented "short universal baseline" design
  (`docs/configuration.md`), 11 lines, and narrowing it would just relocate
  the same content behind a less reliable trigger. The actual "effectively
  always loaded" problem was the *duplicated* Priority/decision content in
  `global-instructions.md`, fixed above.

## 5. Token-aware subagent orchestration guidance

Replace the "Use one implementer for small, contained tasks. Add researcher
only for material uncertainty..." paragraph in `global-instructions.md` with:

> Delegate only when the expected improvement in correctness, independence,
> specialization, or parallelism outweighs the duplicated context and tool
> cost. Do not delegate simple repository exploration the main agent can do
> directly. Do not create a researcher for information the main agent can
> obtain cheaply itself. Use one implementer for small and medium contained
> tasks. Run reviewer and verifier together only when their responsibilities
> are materially different for the current task. Avoid multiple agents
> independently reading the same large set of files. Use parallel agents
> only for genuinely independent work. Do not let subagents create further
> subagents.

`config.toml`'s `max_concurrent_threads_per_session = 5` / Claude's five-
operation concurrency stay untouched — only the decision guidance changes,
not the ceiling.

## Validation

- `scripts/build.ps1`/`.sh`, `scripts/doctor.ps1`/`.sh` pass.
- `scripts/test-platform-packages.*` (agent/skill/AGENTS.md/CLAUDE.md content
  assertions) updated for: embedded `general.md` in `AGENTS.md`, the split
  rule skill/reference structure, trimmed `global-instructions.md`.
- New/updated assertions for `-Summary`/`--summary` output shape on at least
  one script per language (build + doctor), covering both the summary line
  and that `WARN`/`FAIL` still surface unsummarized.
- Manual read-through of the three split rules to confirm no content was
  dropped, only relocated.
