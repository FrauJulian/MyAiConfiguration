# Plugins

The user-level plugin manifest is `adapters/plugins.tsv`. It maps each logical extension to the client-specific plugin, skill, or MCP installation method.

The current baseline includes Ponytail, i-have-adhd, Superpowers, Context7, Caveman, MCPorter, Humanizer, Impeccable, and Anthropic Frontend Design. Install and update operate at user scope and show an extension selector unless running a dry run or Quickupdate. Selections are collected before configuration changes. Both rebuild generated packages before synchronizing client files and extensions. Choosing Auto for local search can prepare and benchmark QMD earlier, during option selection.

### Automatic workflow integration

The always-loaded general rules route both clients to the shared `plugin-workflow` skill at session start/resume and task or phase changes. The policy requires Superpowers at development phase boundaries, Ponytail for implementation and review, Impeccable for UI planning through verification, and i-have-adhd response structure with Caveman's concise style when available. Superpowers owns process; Ponytail constrains implementation to the smallest complete, verified change; Impeccable owns UI decisions; Frontend Design supplements uncovered needs without starting another workflow. User authorization, research gates, and proportionate checks retain precedence.

The installed i-have-adhd 0.4.1 skill declares `disable-model-invocation: true`. The shared policy therefore supplies automatic response guidance without forcing a manual-only skill invocation or relying on its optional hook. It does not diagnose the user. Style stop commands persist through task changes and resume; `normal mode` disables i-have-adhd, Caveman, and Ponytail for the session. Explicit mode levels override defaults. Missing plugins are reported once and do not trigger installation. These are instruction-level requirements, not runtime interception or a guarantee of model compliance. Existing installations receive them through the normal configuration update; builds do not modify local plugin caches or hook trust.

### Context7 routing

Selecting Context7 with MCPorter registers the server in MCPorter. Selecting Context7 without MCPorter installs its native client plugin; that explicit selection permits the native MCP route under the global instructions.

Both clients receive a mandatory Context7-first research gate through the shared general rules and `technical-research` skill. It triggers whenever answers, planning, coding, reviews, debugging, tests, configuration, or upgrades rely on external technology behavior, without requiring the user to mention Context7. The agent checks project versions, resolves the library, queries the relevant behavior, and verifies the original source. Matching evidence from the same task can be reused across phases and handoffs; repository-only facts need no external call. Missing coverage, version mismatches, and service failures require an explicit fallback to authoritative sources. [Phase checkpoints](skills.md) apply inside plugin workflows as well as the focused shared skills. These are agent instructions, not a runtime enforcement hook.

### Optional Context7 health check

For a configured MCPorter route, run these commands in PowerShell or Bash. They make live requests using a public Angular question; they do not install or change configuration. Routine builds and doctor runs do not run this check.

```text
mcporter list context7 --schema
mcporter call context7.resolve-library-id 'libraryName=Angular' 'query=How do Angular computed signals track dependencies?' --timeout 30000
```

Check that discovery lists `resolve-library-id` and `query-docs` and resolution returns the official Angular documentation. Then query the returned ID (the example assumes `/websites/angular_dev` was returned):

```text
mcporter call context7.query-docs 'libraryId=/websites/angular_dev' 'query=How do Angular computed signals track dependencies?' --timeout 30000
```

The check passes only if documentation retrieval returns relevant content with an original Angular source link. Empty results, error text, or merely a zero process exit code are insufficient. This checks connectivity and one library, not general coverage or agent compliance. For a native plugin installation, run the equivalent discovery and tool calls inside that client; do not add an MCPorter registration just for this check.

### Installation and updates

`install.ps1`/`install.sh` starts every plugin checked by default; unchecking one skips it. It refuses to run against an already-installed destination (`Already installed, use the update script.`).

`update.ps1`/`update.sh` lets you revise the saved extension selection. Checking an extension installs it if missing or updates it if owned; existing foreign installations are preserved. Deselection removes only extensions that this setup installed and recorded as owned. Pre-existing or manually installed plugins and skills are retained. Extensions removed from the manifest are also removed when recorded as owned; unrelated installations are retained. Update refuses to run if any selected destination lacks an installation manifest (`Not installed, use the install script.`).

Codex's local `plugins` and `marketplaces` tables survive configuration synchronization, along with other root keys, extra fields in managed tables, other unmanaged tables, and unowned array tables; changed files are backed up. Cached plugin files alone are not treated as proof of installation: selection uses the client CLI's installed list. If an older update removed the registrations, inspect the backed-up `config.toml` under `~/.codex/backups/` and reselect the affected plugins on the next update.

Codex receives Caveman through its native plugin adapter. Humanizer, Impeccable, and Anthropic Frontend Design are downloaded as skill payloads from the GitHub sources in the manifest, without running upstream installers. All three appear in the extension selector for Codex. Ownership is recorded in `~/.my-ai-configuration/extensions.json`. Skill files are tracked by hash; modified or foreign files are retained with a warning. Existing installations from before ownership tracking are not automatically adopted.

On Windows, installation and update repair the known Caveman 1.0.0 hook launcher in setup-owned Codex installations so it resolves the plugin path under PowerShell as well as Command Prompt. Custom commands and foreign installations are preserved. Review the changed hook definitions in Codex `/hooks`; setup does not grant hook trust automatically.


### Setup options outside the extension selector

Flashbang, the custom status line, and local QMD search have separate prompts during install and update.
Quickupdate reuses their saved choices together with the shell, client, and extension selection. Only successful
runs save selections; dry runs do not update extensions or local search. Disabling the status line removes its
custom setting and setup-owned Claude script.

QMD is managed by the local-search option, not as a plugin. See [Local QMD search](configuration.md#local-qmd-search)
for models, Auto thresholds, runtime behavior, sandbox paths, and ownership-aware removal.
Install and update do not modify the Codex or Claude CLI installations.

Plugin installation requires the corresponding client CLI, network access, and any authentication required by the plugin. Context7 may open an OAuth flow. Codex or plugin hooks may require a trust review in `/hooks`. The scripts never install plugins during a build or doctor run and never install them when `--dry-run` or `-DryRun` is used.

Marketplace source conflicts stop installation; the setup does not replace a foreign marketplace registration. Failed extension operations retain the ownership records of earlier successful operations so the next run can reconcile them.

Only trusted upstream marketplace sources should be added. Plugins are executable extensions and may access the permissions granted to their client.
