# Definition of Done

A task is only considered done when all applicable requirements below are fulfilled.

## Coding

* The implementation fully satisfies the requested behavior.
* All relevant acceptance criteria are implemented.
* The work item description is fully addressed.
* The code builds successfully.
* Relevant tests pass.
* New or changed behavior is covered by tests where appropriate.
* No known errors, warnings, regressions, or broken behavior remain.
* The implementation follows the project's coding, architecture, security, and performance guidelines.
* No unrelated changes are included.
* No temporary code, debug output, commented-out code, placeholders, or TODOs remain unless explicitly intended.
* Error handling and edge cases are handled appropriately.
* The implementation is readable, maintainable, and production-ready.
* Existing documentation was not changed automatically. If the code makes it inaccurate, the user was asked before proceeding.
* No new documentation, repository comments, pull request text, or work-item text was created without explicit user instruction.
* Any delegated research, review, or verification is complete and its relevant findings are resolved or reported.

## Work Items

A work item is only considered complete when:

* Every acceptance criterion is fulfilled.
* Every requirement in the description is implemented or otherwise resolved.
* Acceptance criteria and description are checked against the actual implementation, not assumed to be complete.
* No known requirement is left partially implemented.
* No unresolved blocker or relevant defect remains.
* Required tests or validations have been completed successfully.
* Any deviation from the description or acceptance criteria has been explicitly approved by the user.

## Completion Check

Before declaring a task complete:

* Re-read the work item description.
* Re-read all acceptance criteria.
* Compare each requirement against the implemented result.
* Verify the relevant code paths.
* Run applicable builds and tests.
* Check for incomplete or unrelated changes.
* Confirm that the final state matches the requested outcome.

## Important Rule

* Do not mark, close, resolve, or otherwise change the state of a work item automatically.
* A task may be technically complete without changing its remote work item state.
* Any Azure DevOps WRITE operation still requires explicit user approval.
* If completion is unclear, requirements conflict, or something is missing, ask the user instead of deciding autonomously.
