# TypeScript Modules and Dependencies

Apply these rules when changing package dependencies, module structure, imports, or public exports.

* Follow the project's existing module system consistently; avoid mixing ESM and CommonJS without a compatibility need.
* Keep modules focused and boundaries intentional. Avoid circular dependencies and unnecessary public exports.
* Separate transport models from domain logic where that boundary exists. Do not leak implementation details through public APIs.
* Prefer built-in platform APIs or installed packages before adding a dependency. Keep dependencies minimal, supported, and compatible with the lockfile.
* Review package identity, maintenance, transitive dependencies, permissions, lifecycle scripts, and update behavior before adopting a package. Pin or constrain versions according to project policy and commit the package manager's lockfile.
* Avoid broad dependency upgrades unrelated to the task. Do not hand-edit generated lockfile content; regenerate it with the intended package manager and verify the resulting diff.
* Do not treat bundled frontend configuration as secret storage. Anything shipped to a browser is observable by users.
* Remove unused imports and exports, and keep path and export conventions consistent with the surrounding code.
