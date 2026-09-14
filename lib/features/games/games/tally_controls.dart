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
      // Width in TEXT units, not pixels: a 440dp bar at 200% text has the
      // room of a 220dp bar at 100%, and the labelled skip button overflowed
      // it by exactly the amount the pixel check could not see.
      final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
      final tight = constraints.maxWidth / scale < 360;
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
              // No Flexible here: FilledButton.icon already wraps its label
              // in one, and a second competes for the same parent data.
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
