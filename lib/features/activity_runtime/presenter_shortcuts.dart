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
///   - **Space / +** → tally a contribution ([onTally], for counting games
///     like Rhyme Time / Beat the Letter — it owns Space when set)
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
    this.onTally,
    super.key,
  });

  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onReveal;

  /// Counting games (Rhyme Time, Beat the Letter): the frequent "+1" beat.
  /// When set it owns the Space key (and + / =); a game is either a reveal
  /// game or a tally game, so the two never collide on Space.
  final VoidCallback? onTally;

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
    final tally = onTally;
    // Space is the game's primary beat: tally a contribution in a counting
    // game, else reveal in a reveal game (a game is one or the other).
    final space = tally ?? reveal;
    if (space != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.space)] = space;
    }
    if (tally != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.equal)] = tally;
      bindings[const SingleActivator(LogicalKeyboardKey.numpadAdd)] = tally;
    } else if (reveal != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyR)] = reveal;
    }
    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(autofocus: true, child: child),
    );
  }
}
