import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// Shared control bar for the host-paced "shout it out, teacher tallies" games
/// (Rhyme Time, Letter Words) — a prominent tally button + New + Again, laid
/// out to fit both the local scaffold and the live bar.
Widget tallyControls({
  required void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  required String tallyLabel,
  required String nextLabel,
}) {
  // The tally button is the one pressed over and over, so it keeps the room
  // it has at every width — what gives way on a narrow phone is the LABEL of
  // the skip button beside it, which is read once and then never again.
  //
  // Measured rather than guessed: at 320dp the reset button and a labelled
  // skip button already exceed the row on their own, so the Expanded tally
  // button had nothing left to shrink into and overflowed by 16px. A minimum
  // width is not the fix — dropping a word is.
  return LayoutBuilder(
    builder: (context, constraints) {
      final tight = constraints.maxWidth < 360;
      return Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => send(GameIntent.reset),
            icon: const Icon(Icons.replay),
            tooltip: 'Start over',
          ),
          const SizedBox(width: 8),
          if (tight)
            IconButton.outlined(
              onPressed: () => send(GameIntent.next),
              icon: const Icon(Icons.skip_next),
              tooltip: nextLabel,
            )
          else
            OutlinedButton.icon(
              onPressed: () => send(GameIntent.next),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
              icon: const Icon(Icons.skip_next),
              label: Text(nextLabel, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => send(GameIntent.tally),
              icon: const Icon(Icons.add),
              label: Text(
                tallyLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      );
    },
  );
}
