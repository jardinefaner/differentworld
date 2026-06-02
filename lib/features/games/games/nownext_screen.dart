import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/nownext_game.dart';
import 'package:differentworld/features/live_session/live_game_screen.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

String _kindLabel(String kind) => switch (kind) {
  'field_trip' => 'Field trip',
  'break' => 'Break',
  'closed' => 'Closed',
  _ => 'Activity',
};

String _fmtTime(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  return dt == null ? '' : DateFormat.jm().format(dt);
}

String _title(String? title, String kind) {
  final t = (title ?? '').trim();
  return t.isEmpty ? _kindLabel(kind) : t;
}

/// Seeds Now & Next from today's schedule (Drift, not the content bank), then
/// hands off to the runner / live screen (docs/VISION.md #18). Starts on the
/// block that's happening now (or the next upcoming). The resolved blocks
/// ride in the wire-state, so a joined controller shows the same board.
class NowNextScreen extends ConsumerWidget {
  const NowNextScreen({required this.live, super.key});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(scheduleDayProvider(todayKey()));
    return day.when(
      data: (blocks) {
        final sorted = [...blocks]
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final now = DateTime.now();
        var current = 0;
        for (var i = 0; i < sorted.length; i++) {
          current = i;
          final end = DateTime.tryParse(sorted[i].endAt)?.toLocal();
          // First block that hasn't ended = now-or-next; else fall to the last.
          if (end != null && now.isBefore(end)) break;
        }
        final seed = <String, dynamic>{
          'blocks': [
            for (final b in sorted)
              [_title(b.title, b.kind), _fmtTime(b.startAt), b.kind],
          ],
          'i': current,
        };
        return live
            ? LiveGameScreen(def: const NowNextGame(), seed: seed)
            : GameRunner(def: const NowNextGame(), seed: seed);
      },
      loading: () => const EdgeScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => live
          ? const LiveGameScreen(def: NowNextGame())
          : const GameRunner(def: NowNextGame()),
    );
  }
}
