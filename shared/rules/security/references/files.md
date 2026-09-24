# File and process security

* Validate filenames, content, sizes, and paths; prevent traversal, zip-slip, and unsafe symbolic-link use.
* Restrict access to intended directories and do not execute uploaded or untrusted files.
* Do not concatenate untrusted input into shell commands; prefer direct APIs and validate process arguments when execution is required.
* Treat local files, IPC, and deserialized input as untrusted at relevant boundaries.
