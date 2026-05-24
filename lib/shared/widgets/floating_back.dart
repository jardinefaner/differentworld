import 'package:differentworld/shared/widgets/glass_pill.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tiny glass-pill back button. Drops itself into the top-left of a
/// screen via a `Positioned` parent. Auto-hides when there's nothing
/// to pop to. Pair with a fallback route via [fallbackRoute] for
/// deep-link entries that have no stack.
///
/// Pass [onPressed] for non-route back semantics (e.g. closing an
/// in-app overlay like the omnibox suggestion panel). When provided,
/// it overrides the default pop/go behavior.
class FloatingBack extends StatelessWidget {
  const FloatingBack({
    this.fallbackRoute = '/',
    this.semanticsLabel = 'Back',
    this.onPressed,
    super.key,
  });

  /// Where to `go` if `context.canPop()` is false. Defaults to the
  /// home page.
  final String fallbackRoute;
  final String semanticsLabel;

  /// Custom back handler. When non-null, replaces the route-pop /
  /// go-fallback logic — used by the AppShell's overlay-mode chrome
  /// to close the suggestion panel without touching the navigator.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    final scheme = Theme.of(context).colorScheme;
    return GlassPill(
      padding: EdgeInsets.zero,
      child: IconButton(
        tooltip: semanticsLabel,
        icon: Icon(Icons.arrow_back, color: scheme.onSurface),
        onPressed: onPressed ??
            () {
              if (canPop) {
                context.pop();
              } else {
                context.go(fallbackRoute);
              }
            },
      ),
    );
  }
}
