## Destructive Actions

* Clearly label destructive actions.
* Use confirmations for irreversible or high-impact operations.
* Explain the consequence before confirmation.
* Prefer reversible actions when possible.
* Offer undo where practical.
* Do not use generic confirmation text for destructive operations.
* Make the safe action visually distinct.
* Do not preselect destructive choices.

## Error Prevention

* Prevent invalid actions before they occur where practical.
* Use constraints and suitable controls instead of relying only on validation errors.
* Provide sensible defaults.
* Confirm only high-impact decisions.
* Warn users before losing unsaved changes.
* Do not clear entered data unexpectedly.
* Avoid ambiguous state transitions.
* Make dependencies between fields or actions visible.

## Consistency

* Similar problems should have similar UI solutions.
* Similar actions should use the same wording and placement.
* Do not introduce custom patterns when an existing pattern already solves the problem.
* Reuse components and design tokens.
* Keep interaction behavior consistent across the application.
* Preserve platform conventions unless there is a strong reason not to.

## User Control

* Keep users in control of important actions.
* Do not perform surprising destructive actions automatically.
* Do not change user data without a clear action or established behavior.
* Make automatic behavior visible when it materially affects the user.
* Allow users to cancel long-running operations where practical.
* Allow recovery from mistakes where possible.
* Avoid dark patterns.
* Never manipulate users into actions they did not intend.

## Progressive Disclosure

* Show the most important options first.
* Hide advanced complexity until it is needed.
* Do not overwhelm users with every possible setting at once.
* Keep advanced options discoverable.
* Avoid forcing expert workflows on normal users.
* Avoid hiding frequently used functionality behind excessive menus.

## Performance Perception

* Optimize perceived performance as well as actual performance.
* Show useful content as early as possible.
* Avoid blocking initial rendering on non-critical data.
* Use skeletons only when they improve comprehension.
* Avoid fake progress.
* Do not use loading animations to mask avoidable slowness.
* Keep interactions responsive even while background work continues.

## Defaults

* Choose safe and sensible defaults.
* Defaults should match the most common expected user intent.
* Avoid defaults with destructive consequences.
* Preserve user preferences when appropriate.
* Do not force repeated configuration for common workflows.
