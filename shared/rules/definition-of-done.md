# Definition of Done

A task is only considered done when all applicable requirements below are fulfilled.

## Requirements

* Every requirement in the work item description and every acceptance criterion is implemented or otherwise resolved; none is left partially implemented.
* Requirements are checked against the actual implementation and the relevant code paths, not assumed to be complete.
* Any deviation from the description or acceptance criteria has been explicitly approved by the user.
* No known unresolved blocker, defect, or regression introduced by the change remains.

## Verification

* Verification is sufficient for the change's risk and scope, following `general.md`'s Verification rules. A build, test run, new test, or independent review is not required for every change.
* Checks selected on that basis, and checks explicitly required by the user or project, have passed. Material gaps and pre-existing failures are reported without claiming unverified success.
* Any delegated research, review, or verification is complete and its relevant findings are resolved or reported.

## Code

* The implementation follows the project's coding, architecture, security, and performance guidelines and handles errors and edge cases appropriately.
* No unrelated changes are included.
* No temporary code, debug output, commented-out code, placeholders, or TODOs remain unless explicitly intended.
* Directly affected documentation and comments are updated; other documentation or comments are added only for a concrete need.

## Work item state

* Do not mark, close, resolve, or otherwise change the state of a work item automatically. A task may be technically complete without changing its remote work item state.
* Perform an Azure DevOps write only when the user explicitly requests or approves that specific action. A direct request in the current task is sufficient; do not ask for the same approval again.
* If completion is unclear, requirements conflict, or something is missing, ask the user instead of deciding autonomously.
