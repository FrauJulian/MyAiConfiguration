# WPF Code Guidelines

* Use modern C# and current .NET/WPF conventions.
* Keep UI, application logic and domain logic clearly separated.
* Prefer MVVM for non-trivial views.
* Keep code-behind minimal.
* Use code-behind only for view-specific behavior that does not belong in the ViewModel.
* Avoid business logic in views.
* Avoid direct service access from controls.
* Keep dependencies explicit and testable.
* Prefer composition over inheritance.
* Avoid unnecessary abstractions and framework wrappers.
* Follow the existing project architecture unless there is a strong reason to change it.

## Safety Rule

* The UI must remain responsive.
* Do not block the UI thread with I/O or expensive CPU work.
* Do not bypass validation or security controls for convenience.
* Do not introduce hidden cross-thread access.
* Prefer predictable, explicit and testable UI behavior.

## Detailed guidance

Read the matching reference file before working in that area:

| Read this reference for... | ...this kind of work |
| --- | --- |
| `references/mvvm-and-binding.md` | MVVM, data binding, property change notifications, dependency/attached properties |
| `references/commands-and-async.md` | Commands, async/threading, UI-thread work, events |
| `references/collections-and-xaml.md` | Collections, virtualization, layout, XAML |
| `references/resources-and-lifecycle.md` | Resources/styles, windows/dialogs, navigation, memory, images/media |
| `references/security-and-errors.md` | Security, file/process access, error handling, logging, validation |
| `references/architecture-and-quality.md` | Architecture, DI, testing, code quality, performance |
