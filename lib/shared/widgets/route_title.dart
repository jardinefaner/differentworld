import 'package:flutter/material.dart';

/// Wraps a route body in a `Title` so the browser tab updates per
/// page. Wave 108.
///
/// Without this, every Different World tab shows "Different World"
/// forever — a director with three tabs open (Today / Schedule /
/// a kid's profile) can't tell which is which. With it, the tab
/// title becomes a real navigation breadcrumb:
///
///   `/`                                  Today · Different World
///   `/groups/:id`                        4-6 Cohort · Different World
///   `/groups/:id/students/:sid`          Emma Smith · Different World
///   `/schedule`                          Schedule · Different World
///
/// Flutter's `Title` widget writes to `document.title` on web and is
/// a no-op everywhere else. The `color` is required by the framework
/// (controls the OS task-switcher chip on Android) — we pass the
/// theme's primary so it tracks dark/light mode.
///
/// Pattern: wrap the body of each screen at the EdgeScaffold level.
/// Don't wrap the AppShell — that'd set a single title for the entire
/// app and defeat the purpose.
///
/// ```dart
/// return RouteTitle(
///   title: 'Today',
///   child: EdgeScaffold(...),
/// );
/// ```
///
/// The widget appends " · Different World" automatically so callers
/// only spell the page-specific part. Pass `appendApp: false` for
/// surfaces that already include the brand (the login screen).
class RouteTitle extends StatelessWidget {
  const RouteTitle({
    required this.title,
    required this.child,
    this.appendApp = true,
    super.key,
  });

  /// The page-specific title fragment. Examples: "Today", "Schedule",
  /// "Emma Smith", "Settings". Don't include the brand here unless
  /// you also pass `appendApp: false`.
  final String title;

  /// When true (default), the resolved document title is
  /// "`<title>` · Different World". When false, the title is rendered
  /// as-is — useful for screens that already incorporate the brand
  /// (e.g. the login screen renders the wordmark; the tab shows
  /// just "Different World").
  final bool appendApp;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Title(
      title: appendApp ? '$title · Different World' : title,
      color: theme.colorScheme.primary,
      child: child,
    );
  }
}
