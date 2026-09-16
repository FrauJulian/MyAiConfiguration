## Resources and Styles

* Use shared resources for repeated styles, brushes, templates and dimensions.
* Keep resource dictionaries focused.
* Avoid giant global resource dictionaries.
* Prefer feature-level resources when styles are not truly global.
* Use `StaticResource` by default.
* Use `DynamicResource` only when runtime resource replacement is required.
* Avoid excessive dynamic resource lookups.
* Keep theme resources separated from application logic.
* Avoid hardcoded colors and dimensions when design tokens or resources already exist.

## Windows and Dialogs

* Keep window lifecycle explicit.
* Avoid creating duplicate windows unintentionally.
* Do not keep hidden windows alive without a reason.
* Separate dialog logic from business logic.
* Prefer dialog services when ViewModels need to request user interaction.
* Keep ownership relationships explicit.
* Avoid application shutdown behavior that depends on accidental window lifetime.

## Navigation

* Keep navigation state explicit.
* Avoid coupling ViewModels directly to concrete views.
* Avoid service locator patterns for view resolution.
* Keep navigation history intentional.
* Dispose or release navigation targets when they are no longer required.
* Do not retain entire navigation graphs unnecessarily.

## Memory Management

* Watch for memory leaks caused by:

  * Event subscriptions
  * Timers
  * Static references
  * Long-lived services
  * Cached views
  * Closures
  * Collection views
  * Binding-related references
* Dispose resources correctly.
* Stop timers and background work when no longer needed.
* Avoid retaining closed windows or unloaded views.
* Do not keep unnecessary references to visual elements.
* Profile memory when long-running applications continuously grow.

## Images and Media

* Load images at an appropriate resolution.
* Avoid decoding images significantly larger than their displayed size.
* Release streams and file handles correctly.
* Avoid locking image files unintentionally.
* Cache images only when there is a clear memory strategy.
* Avoid keeping large bitmaps alive unnecessarily.
* Prefer frozen image resources when they are immutable.
