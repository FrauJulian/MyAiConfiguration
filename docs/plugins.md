# Plugins

The user-level plugin manifest is `adapters/plugins.tsv`. It maps each logical plugin to the marketplace selector understood by Claude Code and Codex.

The current baseline includes Ponytail, i-have-adhd, Superpowers, and Context7. The install script operates at user scope and is idempotent: existing Claude plugins are enabled and updated, and Codex plugins are updated or ensured through the Codex plugin command.

Plugin installation requires the corresponding client CLI, network access, and any authentication required by the plugin. Context7 may open an OAuth flow. Codex or plugin hooks may require a trust review in `/hooks`. The scripts never install plugins during a build or doctor run and never install them when `--dry-run` or `-DryRun` is used.

If Codex reports that a marketplace is already registered from another source, the scripts remove only the conflicting marketplace name from the configured user-level Codex sources, add the repository source from the manifest, and continue with the Codex plugin command. Other marketplace errors remain fatal.

Only trusted upstream marketplace sources should be added. Plugins are executable extensions and may access the permissions granted to their client.
