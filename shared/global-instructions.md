# Personal global instructions

This file is generated into client-specific instruction files. Do not edit generated copies.

Before applying generated instructions, read `~/.my-ai-configuration/instructions/__CLIENT__.md` when it exists. Treat its contents as direct user instructions that override generated rules, skills, and plugins. System and developer safety requirements remain non-overridable.

For a tool credential, invoke `~/.my-ai-configuration/bin/with-credential.__SHELL__` with the client, credential key, and child command. It exposes the credential only to that child process. Never print credentials or place them in commands.

When programming, always apply the security baseline: `rules/security/index.md` / `rules-security` (Codex file / Claude skill). This applies to implementing, modifying, debugging, reviewing, testing, and configuring software, scripts, hooks, infrastructure, and integrations. Load a focused security rule only for each affected area listed below.

Detect languages, frameworks, tools, and change areas from the repository and requested work. Apply every matching rule before editing. For Codex, read the listed rule file. For Claude, invoke the matching `rules-*` skill. Apply all matching rules when multiple areas apply.

Load or invoke rules for these areas:

- Angular component, template, or RxJS/signal work: `rules/angular/index.md` / `rules-angular`; load matching topic rules listed in the index.
- C# or .NET implementation, review, or refactoring: `rules/csharp/index.md` / `rules-csharp`; load matching topic rules listed in the index.
- Unresolved requirements, ambiguous behavior, or meaningful technical choices: `rules/decision-rule.md` / `rules-decision-rule`.
- Validating completion or review readiness: `rules/definition-of-done.md` / `rules-definition-of-done`.
- Git operations such as commits, branches, or merges: `rules/git.md` / `rules-git`.
- Microsoft 365, Azure DevOps, or Teams operations: `rules/microsoft.md` / `rules-microsoft`.
- Delegation, subagents, or long-running task state: `rules/orchestration.md` / `rules-orchestration`.
- Refactoring without behavior changes: `rules/refactoring.md` / `rules-refactoring`.
- Authentication, authorization, sessions, tokens, permissions, or tenant boundaries: `rules/security/references/auth.md` / `rules-security-auth`.
- HTTP APIs, request handling, serialization, or endpoints: `rules/security/references/api.md` / `rules-security-api`.
- Browser, frontend, cookies, redirects, XSS, or CSRF: `rules/security/references/web.md` / `rules-security-web`.
- Databases, queries, persistence, sensitive data, or tenant boundaries: `rules/security/references/data.md` / `rules-security-data`.
- Files, uploads, archives, paths, processes, IPC, or deserialization: `rules/security/references/files.md` / `rules-security-files`.
- Network access, URLs, proxies, outbound requests, TLS, or SSRF: `rules/security/references/network.md` / `rules-security-network`.
- Cryptography, secrets, credentials, keys, or tokens: `rules/security/references/crypto.md` / `rules-security-crypto`.
- Dependencies, packages, plugins, builds, deployments, or CI supply chains: `rules/security/references/supply-chain.md` / `rules-security-supply-chain`.
- TypeScript or modern ECMAScript implementation: `rules/typescript/index.md` / `rules-typescript`; load matching topic rules listed in the index.
- UI or UX design and interaction: `rules/ui-ux/index.md` / `rules-ui-ux`; load matching topic rules listed in the index.
- WPF, XAML, or MVVM desktop UI: `rules/wpf/index.md` / `rules-wpf`; load matching topic rules listed in the index.

Use the `mcporter` CLI for MCP services by default. Use a native MCP connection when MCPorter is not active, or when the user explicitly requests it or selects a native MCP plugin in this configuration. If the requested route is unavailable, report the limitation instead of silently switching routes.

Main agent owns state and decisions. Delegate only for independent work where benefit exceeds context/tool cost. Use one implementer for contained work; subagents never spawn agents. Pass minimal context and verify handoffs.
