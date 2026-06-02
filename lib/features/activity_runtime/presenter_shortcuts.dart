import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard controls for a host-run / presenter activity driven from a
/// laptop or projector (docs/PLATFORM_RUBRIC.md, P3 — Pointer/KB).
///
/// A presenter clicking on-screen buttons works, but a keyboard is the
/// natural remote for a slideshow-shaped activity:
///   - **→ / Enter** → next ([onNext])
///   - **←** → back ([onBack])
///   - **Space / R** → reveal / discuss ([onReveal])
///
/// Wraps [child] in a focused `CallbackShortcuts` so the keys fire
/// without a tap-to-focus first. Every callback is optional — bind only
/// what the activity supports (a tally game has no reveal, a one-way
/// reveal game has no back). On touch devices there's no keyboard, so
/// this is a no-op there; the on-screen controls remain the primary
/// affordance everywhere.
class PresenterShortcuts extends StatelessWidget {
  const PresenterShortcuts({
    required this.child,
    this.onNext,
    this.onBack,
    this.onReveal,
    super.key,
  });

  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final next = onNext;
    final back = onBack;
    final reveal = onReveal;
    final bindings = <ShortcutActivator, VoidCallback>{};
    if (next != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.arrowRight)] = next;
      bindings[const SingleActivator(LogicalKeyboardKey.enter)] = next;
    }
    if (back != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.arrowLeft)] = back;
    }
    if (reveal != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.space)] = reveal;
      bindings[const SingleActivator(LogicalKeyboardKey.keyR)] = reveal;
    }
    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(autofocus: true, child: child),
    );
  }
}
