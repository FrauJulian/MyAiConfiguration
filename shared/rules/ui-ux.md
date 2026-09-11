# UI & UX Guidelines

* Design for clarity first.
* Prefer simple, modern and predictable interfaces.
* Optimize for fast understanding and low cognitive load.
* Every screen should have a clear primary purpose.
* Every important action should be easy to discover.
* Prefer familiar interaction patterns over novel ones.
* Do not require users to learn unnecessary custom behavior.
* Keep layouts visually calm and structured.
* Use consistent spacing, typography, colors and interaction patterns.
* Avoid visual noise.
* Avoid decorative elements that do not improve usability.
* Avoid unnecessary complexity in navigation and workflows.
* Minimize the number of steps required to complete common tasks.
* Keep related information and actions close together.
* Group content logically.
* Use clear visual hierarchy.
* Make primary actions visually distinct from secondary actions.
* Avoid giving multiple actions equal visual priority when one is clearly more important.
* Use whitespace intentionally.
* Prefer readable line lengths and sufficient spacing.
* Avoid dense walls of content.
* Avoid oversized empty areas that reduce information efficiency.
* Keep important information visible without unnecessary scrolling where practical.

## Navigation

* Navigation must be predictable and consistent.
* Users should always understand where they are.
* Users should always understand how to go back.
* Avoid hidden navigation when visible navigation is practical.
* Keep navigation depth shallow where possible.
* Use clear and descriptive navigation labels.
* Do not use ambiguous icons without labels when meaning is not obvious.
* Preserve navigation state when users return to a previous view where practical.
* Avoid resetting filters, search state or scroll position unnecessarily.
* Avoid unexpected redirects.
* Do not change navigation behavior between similar screens without a clear reason.

## Actions

* Use clear action labels.
* Prefer verbs that describe the actual outcome.
* Avoid vague labels such as `OK`, `Submit`, `Proceed` or `Execute` when a more specific label is possible.
* Make destructive actions clearly distinguishable.
* Keep dangerous actions away from common actions.
* Require confirmation for destructive or difficult-to-reverse actions.
* Do not require unnecessary confirmation for safe, reversible actions.
* Disable unavailable actions when the reason is obvious.
* Explain why an action is unavailable when it is not obvious.
* Avoid actions that appear clickable but are not.
* Provide immediate visual feedback after user actions.
* Prevent accidental duplicate submissions.
* Make loading, success and failure states visible.

## Forms

* Keep forms as short as practical.
* Ask only for information that is actually required.
* Group related fields together.
* Use clear field labels.
* Do not rely on placeholders as the only label.
* Use appropriate input controls for the expected value.
* Provide useful defaults where safe and predictable.
* Preserve user input when validation or network errors occur.
* Validate fields at useful moments without interrupting normal input.
* Show validation errors close to the affected field.
* Explain how to fix invalid input.
* Avoid technical validation messages.
* Clearly mark optional fields where useful.
* Avoid asking the same information multiple times.
* Use autocomplete and autofill where appropriate.
* Make keyboard navigation logical.
* Use sensible tab order.
* Support Enter and Escape behavior where users expect it.

## Content and Language

* Use plain, concise language.
* Prefer user terminology over internal technical terminology.
* Avoid jargon unless the target users are expected to understand it.
* Use consistent naming for the same concepts.
* Do not rename concepts between screens.
* Keep button labels, headings and descriptions concise.
* Put the most important information first.
* Avoid unnecessary explanatory text.
* Add explanation only where users may reasonably be confused.
* Error messages should explain what happened and what the user can do next.
* Avoid blaming the user.
* Avoid exposing stack traces, exception names or internal implementation details.

## Feedback and System State

* Always communicate important system state.
* Show loading states for operations that are not immediate.
* Avoid indefinite loading indicators without context.
* Use progress indicators for longer operations where progress can be measured.
* Clearly distinguish loading, empty, error and success states.
* Do not leave blank screens where an empty state is expected.
* Empty states should explain what the user can do next.
* Show success feedback when the result is not otherwise obvious.
* Keep transient notifications concise.
* Do not hide important errors in temporary notifications.
* Preserve actionable errors until the user has had a chance to understand them.
* Do not silently fail.
* Do not silently discard user input.

## Responsiveness

* The interface should feel responsive at all times.
* Provide immediate feedback after interaction.
* Avoid blocking the entire interface when only one section is loading.
* Prefer localized loading states.
* Use optimistic UI only when failures can be handled safely.
* Avoid layout jumps during loading.
* Reserve space for content where practical.
* Keep animations short and functional.
* Do not use animations that delay task completion.
* Respect reduced-motion preferences.
* Avoid unnecessary transitions and visual effects.

## Visual Design

* Prefer modern, clean and restrained visual design.
* Use a consistent design system.
* Keep typography hierarchy clear.
* Maintain sufficient contrast.
* Use color intentionally.
* Do not rely on color alone to communicate state.
* Keep the number of accent colors limited.
* Avoid excessive gradients, shadows and decorative effects.
* Use rounded corners, borders and elevation consistently.
* Keep icons stylistically consistent.
* Use familiar icons for familiar actions.
* Pair unclear icons with text labels.
* Avoid tiny click targets.
* Keep interactive targets large enough for comfortable use.
* Maintain consistent alignment.
* Avoid arbitrary spacing values.
* Prefer reusable spacing and sizing tokens.

## Accessibility

* Accessibility is part of the default design, not an optional enhancement.
* Use semantic controls and elements.
* Ensure full keyboard usability.
* Maintain visible focus indicators.
* Use sufficient color contrast.
* Do not rely solely on hover interactions.
* Do not rely solely on color to indicate status.
* Provide accessible names for controls.
* Keep focus order logical.
* Move focus intentionally after dialogs, navigation or major state changes.
* Support screen readers where applicable.
* Use ARIA only when native semantics are insufficient.
* Respect reduced-motion and system accessibility preferences.
* Avoid flashing or distracting content.

## Responsive Design

* Design for the available viewport instead of fixed screen sizes.
* Prioritize important content on smaller screens.
* Avoid horizontal scrolling unless the content genuinely requires it.
* Keep controls usable on touch devices.
* Do not simply shrink desktop layouts.
* Adapt navigation and layout intentionally for smaller screens.
* Preserve core functionality across supported screen sizes.
* Avoid hiding important actions solely because space is limited.
* Test common breakpoints and extreme content lengths.

## Tables and Data-Dense Views

* Use tables only for genuinely tabular data.
* Keep column names concise.
* Align numeric data consistently.
* Make sorting and filtering discoverable.
* Preserve filter and sort state where useful.
* Do not overload tables with too many actions.
* Prefer a clear primary row action and secondary contextual actions.
* Keep important columns visible.
* Allow horizontal scrolling only when necessary.
* Use pagination, virtualization or incremental loading for large data sets.
* Provide clear empty states.
* Avoid showing unnecessary columns by default.
* Use sensible formatting for dates, numbers and units.

## Search and Filtering

* Search should behave predictably.
* Make active filters visible.
* Make filters easy to remove.
* Provide a clear way to reset filters.
* Preserve search and filter state when navigating back where practical.
* Avoid requiring users to configure many filters before seeing results.
* Use sensible defaults.
* Clearly distinguish no results from loading or errors.
* Suggest recovery options when no results are found.

## Dialogs and Modals

* Use dialogs only when interruption is justified.
* Avoid stacking dialogs.
* Keep dialogs focused on one decision or task.
* Use clear titles.
* Keep primary and secondary actions obvious.
* Make cancellation easy.
* Support Escape where appropriate.
* Do not use dialogs for information that belongs inline.
* Avoid large workflows inside modal dialogs.
* Do not close dialogs unexpectedly while users are entering data.

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

## Design Decision Rule

* Every UI element should have a clear purpose.
* Every additional interaction adds cognitive cost.
* Prefer removing complexity over explaining unnecessary complexity.
* Prefer familiar patterns over clever ones.
* Prefer fewer clear choices over many ambiguous choices.
* Prefer predictable behavior over surprising automation.
* If a design decision introduces ambiguity, unnecessary complexity, or multiple equally valid UX directions, ask the user instead of deciding autonomously.

## Priority Order

Prioritize UI/UX decisions in this order:

* Correctness
* Clarity
* Safety
* Accessibility
* User control
* Task efficiency
* Consistency
* Responsiveness
* Visual polish

Visual polish must never reduce usability.
