# Plugins

The user-level plugin manifest is `adapters/plugins.tsv`. It maps each logical plugin to the marketplace selector understood by Claude Code and Codex.

The current baseline includes Ponytail, i-have-adhd, Superpowers, Context7, Caveman, Humanizer, Impeccable, and Anthropic Frontend Design. Both scripts operate at user scope and show a plugin selector unless running a dry run. Selections are collected before configuration changes. Both rebuild generated packages first.

`install.ps1`/`install.sh` starts every plugin checked by default; unchecking one skips it. It refuses to run against an already-installed destination (`Already installed, use the update script.`).

`update.ps1`/`update.sh` lets you revise the saved extension selection. Checking an extension installs it if missing or updates it if owned; existing foreign installations are preserved. Deselection removes only extensions that this setup installed and recorded as owned. Pre-existing or manually installed plugins and skills are retained. Extensions removed from the manifest are also removed when recorded as owned; unrelated installations are retained. Update refuses to run if any selected destination lacks an installation manifest (`Not installed, use the install script.`).

Codex's local `plugins` and `marketplaces` tables survive configuration synchronization. Cached plugin files alone are not treated as proof of installation: selection uses the client CLI's installed list. If an older update removed the registrations, inspect the backed-up `config.toml` under `~/.codex/backups/` and reselect the affected plugins on the next update.

Codex receives Caveman through its native plugin adapter. Humanizer, Impeccable, and Anthropic Frontend Design are downloaded as skill payloads from the GitHub sources in the manifest, without running upstream installers. All three appear in the extension selector for Codex. Ownership is recorded in `~/.my-ai-configuration/extensions.json`. Skill files are tracked by hash; modified or foreign files are retained with a warning. Existing installations from before ownership tracking are not automatically adopted.

Normal installation and update also ask whether to update the selected client CLIs, enable Flashbang, and enable the optional Qwen3-Embedding-0.6B semantic retrieval layer. Retrieval is shared by Codex and Claude through a local MCP server, uses a per-user virtual environment and index, and is disabled by default. Quickupdate reuses the saved shell, client, CLI update, Flashbang, retrieval, and extension choices without opening menus. Disabling retrieval removes its setup-owned runtime, index, and MCP registrations. Only successful runs save selections; dry runs do not update CLIs, extensions, or retrieval.

Plugin installation requires the corresponding client CLI, network access, and any authentication required by the plugin. Context7 may open an OAuth flow. Codex or plugin hooks may require a trust review in `/hooks`. The scripts never install plugins during a build or doctor run and never install them when `--dry-run` or `-DryRun` is used.

Marketplace source conflicts stop installation; the setup does not replace a foreign marketplace registration. Failed extension operations retain the ownership records of earlier successful operations so the next run can reconcile them.

Only trusted upstream marketplace sources should be added. Plugins are executable extensions and may access the permissions granted to their client.
