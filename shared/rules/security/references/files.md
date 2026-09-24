# File and process security

* Validate filenames, content, sizes, and paths; prevent traversal, zip-slip, and unsafe symbolic-link use.
* Resolve paths against a trusted root and verify the canonical result remains inside it. Account for symlink or reparse-point changes where an attacker can modify directories.
* Restrict filesystem permissions to the intended identity and directory. Use safe temporary-file creation and avoid predictable names or permissive shared locations.
* Validate upload content using limits and format-aware parsing; do not trust names or client-supplied MIME types. Store untrusted uploads outside executable or public paths.
* Limit archive entry count, nesting, total expanded size, and path destinations to prevent traversal and resource exhaustion.
* Do not execute uploaded or untrusted files. Avoid shell execution; when a process is required, fix the executable and pass validated arguments through structured process APIs.
* Treat local files, IPC, and deserialized input as untrusted at relevant boundaries. Use explicit deserialization types and bound depth, size, and processing time.
* Avoid insecure temporary-file handoff and check permissions and ownership before consuming files from shared or attacker-writable locations.
