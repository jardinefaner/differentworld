import 'package:differentworld/features/games/game_motion.dart';
import 'package:flutter/material.dart';

/// **How a new thing arrives on screen** — one decision, for every surface
/// that replaces its content in place.
///
/// The boards have had this since `ShapeStageView` shipped, because one
/// renderer draws every board. The prompt STAGES got it when `GameStage.frame`
/// took the decision. The seven bespoke activity screens — Do It, Group Talk,
/// Role Cards, Many Paths, Fill in the Blank, Photo Studio, Make a Pattern —
/// share no stage and no layout, so there was nowhere for the decision to
/// live and all seven cut: tap Next and the new thing is simply THERE, which
/// leaves the room unable to answer the only question a change raises —
/// *what moved?*
///
/// They share a decision, not a shape, so this is the decision and nothing
/// else. Wrap the part that CHANGES, never the whole screen: a page that
/// re-animates when a counter ticks is worse than one that never moves.
class Arrives extends StatelessWidget {
  const Arrives({required this.turn, required this.child, super.key});

  /// What makes this content *this* content — the prompt, the index, the word.
  /// When it changes the new child arrives; when it does not, the child
  /// updates in place. Null means there is no identity to compare, so nothing
  /// animates (a screen that cannot say which thing it is showing should not
  /// pretend a change happened).
  final Object? turn;

  final Widget child;

  /// Long enough to read as a movement, short enough that a teacher tapping
  /// Next four times in a row is never waiting on it.
  static const Duration duration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    // Deliberately NOT a ConsumerWidget. This is a presentation atom and it is
    // drawn by `GameStage`, which is used from golden harnesses and plain
    // widget tests — making it need a ProviderScope would make a pure stage
    // crash outside the app. It reads the scope instead, which also carries
    // the OS reduce-animations flag; `GameView` publishes one from the
    // setting, and `ActivityBrief` publishes one for the activity screens.
    if (turn == null || !GameMotion.of(context)) return child;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      // **The prompt on its way out is never tappable.** `AnimatedSwitcher`
      // keeps it in the tree for the whole transition and hit-tests it by
      // default, so for 260ms a room tapping twice — which rooms do — could
      // land its second tap on the thing that is leaving: Next fired against
      // the OLD prompt, skipping one nobody saw. Visible, not live.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (final leaving in previousChildren) IgnorePointer(child: leaving),
          ?currentChild,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<Object>(turn!), child: child),
    );
  }
}
