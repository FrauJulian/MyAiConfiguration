# Global Instructions

Read `~/.my-ai-configuration/instructions/__CLIENT__.md` first when present; it is the user's direct instruction. System and developer requirements still apply.

For credentials, run the child command through `~/.my-ai-configuration/bin/with-credential.__SHELL__` with the client and credential key. Never expose credentials in commands, output, logs, or files.

## Loading rules

Detect affected technologies and concerns. Load every applicable rule: Codex reads its path; Claude invokes its `rules-*` skill. For directory indexes, load only matching topic rules listed there.

Every code, configuration, infrastructure, review, test, script, hook, or integration task: `rules/security/index.md` / `rules-security`.

Focused security: authentication, authorization, sessions, tokens, permissions, tenants => `rules/security/references/auth.md` / `rules-security-auth`; HTTP, requests, serialization, endpoints => `api.md` / `rules-security-api`; browser, cookies, redirects, XSS, CSRF => `web.md` / `rules-security-web`; databases, queries, persistence, sensitive data => `data.md` / `rules-security-data`; files, uploads, archives, paths, processes, IPC, deserialization => `files.md` / `rules-security-files`; network, URLs, proxies, TLS, SSRF => `network.md` / `rules-security-network`; cryptography, secrets, keys, credentials => `crypto.md` / `rules-security-crypto`; dependencies, packages, plugins, builds, deployment, CI => `supply-chain.md` / `rules-security-supply-chain` (remaining paths under `rules/security/references/`).

Technology indexes: Angular => `rules/angular/index.md` / `rules-angular`; C#/.NET => `rules/csharp/index.md` / `rules-csharp`; Java/JVM => `rules/java/index.md` / `rules-java`; TypeScript/ECMAScript => `rules/typescript/index.md` / `rules-typescript`; UI/UX => `rules/ui-ux/index.md` / `rules-ui-ux`; WPF/XAML/MVVM => `rules/wpf/index.md` / `rules-wpf`.

Cross-cutting: unclear requirements or significant choices => `rules/decision-rule.md` / `rules-decision-rule`; completion or review readiness => `rules/definition-of-done.md` / `rules-definition-of-done`; Git operations => `rules/git.md` / `rules-git`; Microsoft 365, Azure DevOps, Teams => `rules/microsoft.md` / `rules-microsoft`; delegation or long-running work => `rules/orchestration.md` / `rules-orchestration`; behavior-preserving refactors => `rules/refactoring.md` / `rules-refactoring`.

## Tools and delegation

Use the `mcporter` CLI for MCP services by default. Use a native MCP connection when MCPorter is not active, or when the user explicitly requests it or selects a native MCP plugin in this configuration. If the requested route is unavailable, report the limitation instead of silently switching routes.

The main agent owns state and decisions. Delegate only independent work when it saves effort; use one implementer for contained work. Subagents do not spawn agents; pass minimal context and verify handoffs.
