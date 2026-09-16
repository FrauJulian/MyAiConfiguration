## Templates

* Keep expressions short and readable.
* Do not execute expensive methods from templates.
* Avoid function calls in templates when their result can be derived or cached.
* Avoid complex conditions directly in markup.
* Prefer derived state in TypeScript over repeated template expressions.
* Use Angular control flow syntax such as `@if`, `@for` and `@switch` for new code.
* Always provide stable tracking for repeated collections.
* Avoid deeply nested template structures.
* Split large templates into focused components when it improves maintainability.
* Avoid unnecessary DOM elements.
* Use semantic HTML.
* Prefer native HTML behavior before custom implementations.
* Keep accessibility in mind when choosing elements and interactions.

## Styling

* Keep styles scoped and predictable.
* Avoid unnecessary global CSS.
* Follow the project's styling strategy consistently.
* Avoid excessive specificity.
* Avoid `!important` unless there is a concrete reason.
* Prefer reusable design tokens and shared styles over duplicated magic values.
* Keep component styles focused on component concerns.
* Avoid styling based on fragile DOM structure.
* Do not mix multiple styling approaches without need.
