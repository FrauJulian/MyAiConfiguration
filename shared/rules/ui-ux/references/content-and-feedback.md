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
