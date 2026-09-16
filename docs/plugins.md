# Plugins

The user-level plugin manifest is `adapters/plugins.tsv`. It maps each logical plugin to the marketplace selector understood by Claude Code and Codex.

The current baseline includes Ponytail, i-have-adhd, Superpowers, Context7, Caveman, Humanizer, Impeccable, and Anthropic Frontend Design. Both the install and update scripts operate at user scope and show an interactive list to toggle each configured plugin on or off before applying anything (skipped for a dry run).

`install.ps1`/`install.sh` starts every plugin checked by default; unchecking one skips it. It refuses to run against an already-installed destination (`Already installed, use the update script.`).

`update.ps1`/`update.sh` starts each plugin checked to match what is already installed (a disabled but installed Claude plugin still counts as installed and is re-enabled), so a plain confirm re-syncs and updates the existing set without silently touching anything else. Checking a plugin that is not installed installs it; unchecking an installed plugin uninstalls it (`claude plugin uninstall`/`codex plugin remove`). It refuses to run against a destination that is not installed yet (`Not installed, use the install script.`).

Codex receives Caveman through its native plugin adapter. Humanizer and Anthropic Frontend Design are installed through the cross-agent Skills CLI; Impeccable uses its provider-aware Codex installer. All four are therefore available to both clients, although Codex does not expose all four as marketplace plugins. Because those three have no install/uninstall state on Codex, they are always ensured on every Codex run and are left out of the toggle list when only Codex is selected (they still appear, toggleable, for Claude or Both).

Plugin installation requires the corresponding client CLI, network access, and any authentication required by the plugin. Context7 may open an OAuth flow. Codex or plugin hooks may require a trust review in `/hooks`. The scripts never install plugins during a build or doctor run and never install them when `--dry-run` or `-DryRun` is used.

If Codex reports that a marketplace is already registered from another source, the scripts remove only the conflicting marketplace name from the configured user-level Codex sources, add the repository source from the manifest, and continue with the Codex plugin command. Other marketplace errors remain fatal.

Only trusted upstream marketplace sources should be added. Plugins are executable extensions and may access the permissions granted to their client.
