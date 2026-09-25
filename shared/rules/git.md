# Git Guidelines

## General Rules

* Never commit changes unless explicitly instructed to do so.
* Never push changes unless explicitly instructed to do so.
* Never create a pull request unless explicitly instructed to do so.
* Never merge branches unless explicitly instructed to do so.
* Never rebase branches unless explicitly instructed to do so.
* Never amend an existing commit unless explicitly instructed to do so.
* Never create or delete Git tags unless explicitly instructed to do so.
* Never modify remote branches unless explicitly instructed to do so.
* Do not interpret general requests such as "finish this", "implement this", or "fix this" as permission to commit or push.
* Permission to commit does not imply permission to push.
* Permission to push does not imply permission to create or merge a pull request.
* Only perform Git write operations that the user explicitly requested.
* Read-only Git commands may be used when needed to inspect repository state.
* Create commits only with `git commit` and push commits only with `git push`. Never create commits or publish repository code through REST APIs, hosting-provider APIs, or other non-Git interfaces.

## Repository Safety

* Always inspect the current Git status before performing Git write operations.
* Never discard uncommitted user changes.
* Never overwrite unrelated changes.
* Never reset, clean, checkout, restore, or revert user changes unless explicitly requested.
* Never use destructive Git operations without explicit instruction.
* Never use `git reset --hard` unless explicitly requested.
* Never use `git clean` unless explicitly requested.
* Never force-push unless explicitly requested.
* Never use `--force` or `--force-with-lease` unless explicitly requested.
* Never rewrite shared history without explicit instruction.
* Never modify `.gitignore` unless required by the task.
* Never commit secrets, credentials, tokens, API keys, private keys, environment files, or other sensitive data.
* Never bypass Git hooks unless explicitly requested.
* Never use `--no-verify` unless explicitly requested.

## Scope

* Only stage files related to the requested task.
* Never stage unrelated modified files.
* Prefer staging specific files instead of using broad commands such as `git add .`.
* Do not include generated files unless they are intentionally tracked by the repository.
* Do not include formatting-only changes unrelated to the task.
* Do not modify unrelated files merely to create a cleaner commit.
* Keep commits focused on one logical change.
* Split unrelated changes into separate commits when multiple commits were explicitly requested.

## Commit Messages

Use Conventional Commits.

Format:

`<type>(<optional-scope>): <description>`

Allowed common types:

* `feat`: new functionality
* `fix`: bug fix
* `refactor`: code change without changing external behavior
* `perf`: performance improvement
* `test`: test changes
* `docs`: documentation changes
* `style`: formatting or style-only changes
* `build`: build system or dependency changes
* `ci`: CI/CD changes
* `chore`: maintenance work
* `revert`: revert of an earlier change

Commit message rules:

* Use lowercase commit types.
* Keep the subject concise and specific.
* Use imperative wording.
* Do not end the subject with a period.
* Describe what changed, not how hard the work was.
* Avoid vague messages such as `fix stuff`, `update`, `changes`, or `cleanup`.
* Use a scope when it improves clarity.
* Keep each commit limited to one logical purpose.
* Use `!` or a `BREAKING CHANGE:` footer for breaking changes.
* Reference issue or ticket identifiers only when relevant and known.
* Never invent issue numbers, ticket IDs, or references.

Examples of valid commit messages:

* `feat(auth): add refresh token rotation`
* `fix(api): handle missing user id`
* `refactor(storage): simplify cache abstraction`
* `perf(database): reduce duplicate queries`
* `test(users): add validation coverage`
* `docs(readme): document local setup`
* `build: update dotnet dependencies`

## Branches

* Do not create a branch unless explicitly requested.
* Do not switch branches unless necessary for the requested task.
* Never delete branches unless explicitly requested.
* Never rename branches unless explicitly requested.
* Never assume the target branch for a merge, rebase, or push.
* Preserve the repository's existing branch naming convention.
* If no branch naming convention exists and a branch was explicitly requested, prefer concise names such as:

  * `feat/<name>`
  * `fix/<name>`
  * `refactor/<name>`
  * `chore/<name>`

## Pulling and Fetching

* Fetching remote state is allowed when required for inspection.
* Do not pull automatically unless explicitly requested or required for an explicitly requested Git operation.
* Never resolve pull or merge conflicts by discarding user changes.
* Do not automatically rebase after pulling.
* Do not automatically merge remote changes into the current branch.

## Conflicts

* Stop before making destructive conflict-resolution decisions.
* Preserve both user work and repository history whenever possible.
* Resolve conflicts only when the correct resolution is clear from the task and surrounding code.
* Do not silently choose one side of a conflict when intent is ambiguous.
* Never use conflict resolution as an excuse to remove unrelated changes.

## Before an Explicitly Requested Commit

Before creating a commit:

* Inspect `git status`.
* Inspect the staged diff.
* Confirm only task-related files are staged.
* Check for accidental secrets or sensitive files.
* Ensure the changes are consistent with the requested task.
* Run relevant tests, checks, or builds when practical.
* Do not include unrelated modifications.
* Use a Conventional Commit message.

## Before an Explicitly Requested Push

Before pushing:

* Confirm that pushing was explicitly requested.
* Confirm the intended branch.
* Confirm the intended remote when multiple remotes exist.
* Ensure the commits being pushed are expected.
* Do not force-push unless explicitly requested.
* Do not push unrelated local commits unintentionally.

## Autonomous Agent Rule

The agent may edit files and implement requested changes autonomously.

The agent must not autonomously:

* commit
* push
* merge
* rebase
* amend commits
* create pull requests
* create or delete tags
* delete branches
* rewrite Git history
* discard working-tree changes

These actions require explicit user instruction each time.

When in doubt, leave the repository changes uncommitted.
