import 'package:differentworld/features/class_memory/class_memory.dart';
import 'package:differentworld/features/facilitation/keep_this.dart';
import 'package:differentworld/features/game_content/ours_strip.dart';
import 'package:differentworld/shared/widgets/app_gap.dart';
import 'package:flutter/material.dart';

/// **The end of a round, on screen** — for the games that own their whole
/// stage (`GameDefinition.buildLiveStage`).
///
/// Those games had an ending in the reducer and none on the screen: the board
/// stamped `done`, froze, and the only way to a second round was leaving the
/// route. Nineteen classics shipped that way, and a substitute who reached
/// the end of a Connect Four had no idea what to press next.
///
/// This is the beat the standard control panel already gives the reveal games,
/// lifted out so the board games get it too: the closing line the room reads,
/// then exactly the verbs a person needs — again, done, the rules — and the
/// two act-one doors (add ours / keep this) that only make sense between
/// rounds.
///
/// A THEMED surface, deliberately: it is a control region sitting on a raw
/// stage (docs/THEME_ADHERENCE.md — the boundary trap), so it reads from the
/// theme like the control panel under a riddle does. One accent edge on the
/// left is the whole decoration (BRAND.md law 1).
class RoundWrap extends StatelessWidget {
  const RoundWrap({
    required this.line,
    required this.accent,
    required this.onAgain,
    this.onDone,
    this.onRules,
    this.gameId,
    this.keepsake,
    super.key,
  });

  /// What the round said as it ended — "Bingo! Top row". Null when the game
  /// ends without announcing anything, in which case the beat is just verbs.
  final String? line;

  /// The game's accent, for the one edge.
  final Color accent;

  /// Play again — a fresh deal, no re-briefing.
  final VoidCallback onAgain;

  /// Leave the game. Null where a surface has nowhere to send you — a live
  /// session ends from its own header — and the button is simply absent.
  final VoidCallback? onDone;

  /// Read the rules again. Null for a game with no run-script.
  final VoidCallback? onRules;

  /// The game id the "add ours" door looks up. Null hides the door.
  final String? gameId;

  /// What this round leaves behind, when the game says it left something —
  /// see `GameDefinition.keepsake`. Null for most games, on purpose.
  final String? keepsake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // At the Extra-large text floor and above, five wrapped controls stack
    // three rows deep and squeeze the board they sit under to a sliver. The
    // add-ours door is an act-one surface reachable from the library too, so
    // it is the one that yields; the keepsake stays — it exists only here.
    final roomy = MediaQuery.textScalerOf(context).scale(10) < 16;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (line case final l?)
                Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: accent, width: 3)),
                  ),
                  child: Text(
                    l,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              if (line != null) const AppGap.lg(),
              // A Wrap, not a Row: at the 200% text floor three buttons are
              // wider than a phone, and a Row has nowhere to put the excess
              // (the same overflow the standard bar hit on "Round complete!").
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('round-wrap-again'),
                    onPressed: onAgain,
                    icon: const Icon(Icons.replay),
                    label: const Text('Play again'),
                  ),
                  if (onDone case final done?)
                    OutlinedButton.icon(
                      key: const ValueKey('round-wrap-done'),
                      onPressed: done,
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                  if (onRules case final rules?)
                    IconButton.outlined(
                      key: const ValueKey('round-wrap-rules'),
                      onPressed: rules,
                      tooltip: 'How to play',
                      icon: const Icon(Icons.help_outline),
                    ),
                  if (gameId case final id?)
                    if (roomy)
                      OursStrip(
                        key: const ValueKey('ours-strip-wrap'),
                        route: id,
                        compact: true,
                      ),
                  if (keepsake case final text?)
                    if (text.trim().isNotEmpty)
                      KeepThisButton(
                        text: text,
                        sort: ClassMemorySort.discovery,
                        label: 'Keep what we made',
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
