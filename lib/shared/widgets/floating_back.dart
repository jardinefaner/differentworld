import 'package:differentworld/shared/widgets/glass_pill.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tiny glass-pill back button. Drops itself into the top-left of a
/// screen via a `Positioned` parent. Auto-hides when there's nothing
/// to pop to. Pair with a fallback route via [fallbackRoute] for
/// deep-link entries that have no stack.
class FloatingBack extends StatelessWidget {
  const FloatingBack({
    this.fallbackRoute = '/',
    this.semanticsLabel = 'Back',
    super.key,
  });

  /// Where to `go` if `context.canPop()` is false. Defaults to the
  /// home page.
  final String fallbackRoute;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    final scheme = Theme.of(context).colorScheme;
    return GlassPill(
      padding: EdgeInsets.zero,
      child: IconButton(
        tooltip: semanticsLabel,
        icon: Icon(Icons.arrow_back, color: scheme.onSurface),
        onPressed: () {
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
