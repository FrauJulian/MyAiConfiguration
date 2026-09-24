---
name: wpf-review
description: Use when reviewing WPF, XAML, or MVVM desktop changes, including bindings, commands, resources, accessibility, lifecycle, and UI-thread behavior.
---

# WPF Review

Use when reviewing WPF, XAML, or MVVM desktop changes.

## Review

- Trace `DataContext`, binding paths, update modes, validation, and `INotifyPropertyChanged` behavior. Check collection updates and selection state.
- Review commands for enablement, asynchronous execution, cancellation, exception handling, and UI-thread affinity.
- Check resource dictionaries, styles, templates, theme behavior, and resource lookup scope.
- Inspect control names, focus and keyboard behavior, automation properties, and error feedback for accessibility.
- Check view and window lifetime, event subscriptions, disposal, timers, and owned resources for leaks or stale references.
- Review XAML parsing, converters, dependency properties, and virtualization for correctness and practical performance.

Report concrete findings with the view, binding, or lifecycle path and user-visible impact. Recommend focused WPF verification; avoid framework-wide advice unrelated to the diff.
