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
  return Row(
    children: [
      IconButton.filledTonal(
        onPressed: () => send(GameIntent.reset),
        icon: const Icon(Icons.replay),
        tooltip: 'Start over',
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: () => send(GameIntent.next),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
        ),
        icon: const Icon(Icons.skip_next),
        label: Text(nextLabel),
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
}
