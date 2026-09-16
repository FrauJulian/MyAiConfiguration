# Plugins

The user-level plugin manifest is `adapters/plugins.tsv`. It maps each logical plugin to the marketplace selector understood by Claude Code and Codex.

The current baseline includes Ponytail, i-have-adhd, Superpowers, Context7, Caveman, Humanizer, Impeccable, and Anthropic Frontend Design. Both scripts operate at user scope and show a plugin selector unless running a dry run. Installation copies configuration before selection; update selects plugins before copying configuration. Both rebuild generated packages first.

`install.ps1`/`install.sh` starts every plugin checked by default; unchecking one skips it. It refuses to run against an already-installed destination (`Already installed, use the update script.`).

`update.ps1`/`update.sh` pre-checks plugins installed in the selected client. For `Both`, Claude is the reference client; the selection is then applied to both clients. A disabled but installed Claude plugin is checked and re-enabled when updated. Checking a missing plugin installs it; unchecking an installed plugin uninstalls it (`claude plugin uninstall --scope user`/`codex plugin remove`). Unlisted plugins are not explicitly installed or removed. Update refuses to run if any selected destination lacks an installation manifest (`Not installed, use the install script.`).

Codex's local `plugins` and `marketplaces` tables survive configuration synchronization. Cached plugin files alone are not treated as proof of installation: selection uses the client CLI's installed list. If an older update removed the registrations, inspect the backed-up `config.toml` under `~/.codex/backups/` and reselect the affected plugins on the next update.

Codex receives Caveman through its native plugin adapter. Humanizer and Anthropic Frontend Design use the cross-agent Skills CLI; Impeccable uses its provider-aware Codex installer. The scripts do not track or uninstall these three Codex skill installations. They are always ensured and omitted from the selector on Codex-only runs. For Claude or Both they are toggleable; deselection can remove the Claude plugin but does not remove an existing Codex skill installation.

Plugin installation requires the corresponding client CLI, network access, and any authentication required by the plugin. Context7 may open an OAuth flow. Codex or plugin hooks may require a trust review in `/hooks`. The scripts never install plugins during a build or doctor run and never install them when `--dry-run` or `-DryRun` is used.

If Codex reports that a marketplace is already registered from another source, the scripts remove only the conflicting marketplace name from the configured user-level Codex sources, add the repository source from the manifest, and continue with the Codex plugin command. Other marketplace errors remain fatal.

Only trusted upstream marketplace sources should be added. Plugins are executable extensions and may access the permissions granted to their client.
