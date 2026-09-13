# Plugins

The user-level plugin manifest is `adapters/plugins.tsv`. It maps each logical plugin to the marketplace selector understood by Claude Code and Codex.

The current baseline includes Ponytail, i-have-adhd, Superpowers, Context7, Caveman, Humanizer, Impeccable, and Anthropic Frontend Design. The install script operates at user scope and is idempotent: a normal run only installs missing plugins (a disabled but already-installed Claude plugin is re-enabled). Pass `-UpdatePlugins`/`--update-plugins` to also update plugins that are already installed, so a configuration update never silently updates third-party plugin code.

Codex receives Caveman through its native plugin adapter. Humanizer and Anthropic Frontend Design are installed through the cross-agent Skills CLI; Impeccable uses its provider-aware Codex installer. All four are therefore available to both clients, although Codex does not expose all four as marketplace plugins.

Plugin installation requires the corresponding client CLI, network access, and any authentication required by the plugin. Context7 may open an OAuth flow. Codex or plugin hooks may require a trust review in `/hooks`. The scripts never install plugins during a build or doctor run and never install them when `--dry-run` or `-DryRun` is used.

If Codex reports that a marketplace is already registered from another source, the scripts remove only the conflicting marketplace name from the configured user-level Codex sources, add the repository source from the manifest, and continue with the Codex plugin command. Other marketplace errors remain fatal.

Only trusted upstream marketplace sources should be added. Plugins are executable extensions and may access the permissions granted to their client.
