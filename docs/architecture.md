# Architecture

Shared Markdown and metadata define meaning once. Codex and Claude adapters contain only client-specific paths, filenames, and serialization details. The build script renders those inputs into `generated/`. Installation is a separate, explicit step that copies generated files into global user-level locations with backups.

Generated output is ignored because it is reproducible build output. The source files are the reviewable record.
