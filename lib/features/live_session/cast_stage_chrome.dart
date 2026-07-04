import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// Chrome that floats over the dark cast / live-game STAGE — shared by the
/// cast cockpit, the live controller, the cast receiver, and the fullscreen
/// game presentation. These sit on the raw canvas (docs/THEME_ADHERENCE.md:
/// projection stages), so the hardcoded white-on-dark colors are correct;
/// this file is on the theme-guard allowlist.

/// The translucent strip at the stage's foot that hosts a game's controls.
class CastBar extends StatelessWidget {
  const CastBar({required this.child, this.withSafeArea = false, super.key});

  final Widget child;

  /// True when the bar sits at the physical screen bottom (live controller)
  /// rather than inside an already-inset cockpit column.
  final bool withSafeArea;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: child,
    );
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      child: withSafeArea ? SafeArea(top: false, child: padded) : padded,
    );
  }
}

/// The standard control bar, built from the game's *active* intents — the
/// same vocabulary every game speaks (Back · Reveal · +1 · Next · Again),
/// so it fits any game shape. Progress ("3 / 10") leads when the wire
/// carries a total.
class GameIntentBar extends StatelessWidget {
  const GameIntentBar({
    required this.def,
    required this.wire,
    required this.onIntent,
    this.withSafeArea = false,
    super.key,
  });

  final GameDefinition<dynamic> def;
  final Map<String, dynamic> wire;
  final ValueChanged<GameIntent> onIntent;
  final bool withSafeArea;

  @override
  Widget build(BuildContext context) {
    final active = def.activeIntents(def.decode(wire));
    final index = (wire['i'] as num?)?.toInt() ?? 0;
    final total = (wire['n'] as num?)?.toInt() ?? 0;
    final done = wire['d'] == true;
    final revealed = wire['r'] == true;

    final buttons = <Widget>[
      if (active.contains(GameIntent.back))
        IconButton.filledTonal(
          onPressed: () => onIntent(GameIntent.back),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
      if (active.contains(GameIntent.reveal))
        FilledButton.tonalIcon(
          onPressed: () => onIntent(GameIntent.reveal),
          icon: Icon(revealed ? Icons.visibility_off : Icons.lightbulb_outline),
          label: Text(def.revealLabel(revealed: revealed)),
        ),
      if (active.contains(GameIntent.tally))
        FilledButton.tonalIcon(
          onPressed: () => onIntent(GameIntent.tally),
          icon: const Icon(Icons.add),
          label: const Text('+1'),
        ),
      if (active.contains(GameIntent.next))
        FilledButton.icon(
          onPressed: () => onIntent(GameIntent.next),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next'),
        ),
      if (active.contains(GameIntent.reset))
        FilledButton.icon(
          onPressed: () => onIntent(GameIntent.reset),
          icon: const Icon(Icons.replay),
          label: const Text('Again'),
        ),
    ];

    return CastBar(
      withSafeArea: withSafeArea,
      child: Row(
        children: [
          if (wire['n'] != null)
            Text(
              done ? 'Done' : '${index + 1} / $total',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          const Spacer(),
          for (final b in buttons) ...[b, const SizedBox(width: 8)],
        ],
      ),
    );
  }
}

/// The join code ("CODE  ABCD12"), shown on the stage so a late phone can
/// still join while something's already cast.
class CastCodeChip extends StatelessWidget {
  const CastCodeChip({required this.code, this.margin, super.key});

  final String code;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CODE  ',
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}
