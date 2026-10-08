---
name: plugin-workflow
description: MUST use at session start/resume, task changes, and development phase transitions to coordinate installed workflow, UI, and communication plugins.
---

# Plugin Workflow

MUST apply available plugins automatically at these triggers. User instructions, security, project rules, research gates, and proportional checks retain precedence. Check exposed skills/enabled plugins once per session; cache presence is insufficient. Load actual installed instructions before use; reuse them. Report missing plugins once, continue with shared guidance, and never install or grant trust implicitly. Respect manual-only invocation metadata.

## Superpowers: process

MUST load `using-superpowers` for development tasks and the matching skill before each phase:

- Features/behavior changes: `brainstorming`; multi-step plans: `writing-plans`.
- Bugs/failures: `systematic-debugging` before fixing.
- Accepted plans: `executing-plans`; delegate only when authorized and useful.
- Behavior requiring regression coverage: `test-driven-development`.
- Review requests/feedback: `requesting-code-review`/`receiving-code-review`.
- Completion claims: `verification-before-completion`, with matching evidence.

Keep Context7 checkpoints within this workflow. Existing authorization stands; ask only about material unresolved decisions. Plugin defaults do not authorize commits, publishing, or additional approval rounds.

## Ponytail: implementation and review

MUST load `ponytail` in `full` mode before coding, fixing, refactoring, configuring, choosing dependencies, or reviewing. Inspect affected callers and consumers. Prefer existing code, then platform features, then installed dependencies. Implement the smallest complete change; remove speculative abstractions without cutting requested behavior, security, accessibility, or error handling. Verify non-trivial logic proportionally. Apply `ponytail-review` when reviewing changes, inside the existing review phase. Report skipped checks and material risks concisely.

## Impeccable: UI

MUST load `impeccable` before UI planning, edits, debugging, or review, including accessibility, responsive behavior, UI copy, and frontend performance. Follow installed context setup, relevant references, and launcher fallback within permissions. Preserve the brief and existing design system. Verify affected states and layouts; batch findings and bound confirmation passes. Report unavailable previews honestly. Impeccable owns UI decisions; Superpowers owns process; Frontend Design supplements gaps without starting a competing workflow. Backend-only tasks skip this layer.

## i-have-adhd and Caveman: responses

MUST apply i-have-adhd structure and Caveman `full` style every response when available. i-have-adhd can be manual-only: use these shared response rules automatically without claiming plugin invocation. This is a communication preference, not a diagnosis.

Lead with the answer/result or required user action. Number user steps; state progress briefly. Complete authorized work yourself. Give one next user action only when needed; estimates only when supported. Preserve complete requested lists, evidence, uncertainty, and risks. Caveman removes filler while retaining i-have-adhd structure; clarity and requested detail override compression.

User-selected levels override defaults. `stop adhd mode`, `stop caveman`, and `stop ponytail` disable their respective layers; `normal mode` disables all three for the session. Preserve opt-outs across tasks, compaction, and resume until explicit reactivation.

Before sending, check applicable phase/UI/Ponytail triggers, style opt-outs, and evidence. Keep this check internal; report material gaps.
