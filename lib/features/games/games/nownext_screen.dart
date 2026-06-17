import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/games/data_seeded_game.dart';
import 'package:differentworld/features/games/games/nownext_game.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
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

/// Map today's schedule [blocks] to the Now & Next wire-state — sorted by
/// start, positioned on the block happening NOW (or the next upcoming). Shared
/// by the single-device present screen ([NowNextScreen]) and the cockpit's cast
/// tile, so both surfaces produce the identical board.
Map<String, dynamic> nowNextSeed(List<ScheduleBlock> blocks) {
  final sorted = [...blocks]..sort((a, b) => a.startAt.compareTo(b.startAt));
  final now = DateTime.now();
  var current = 0;
  for (var i = 0; i < sorted.length; i++) {
    current = i;
    final end = DateTime.tryParse(sorted[i].endAt)?.toLocal();
    // First block that hasn't ended = now-or-next; else fall to the last.
    if (end != null && now.isBefore(end)) break;
  }
  return {
    'blocks': [
      for (final b in sorted)
        [_title(b.title, b.kind), _fmtTime(b.startAt), b.kind],
    ],
    'i': current,
  };
}

/// Seeds Now & Next from today's schedule (Drift, not the content bank), then
/// hands off via [DataSeededGame] (docs/VISION.md #18). Starts on the block
/// happening now (or the next upcoming). The resolved blocks ride in the
/// wire-state, so a joined controller shows the same board.
class NowNextScreen extends ConsumerWidget {
  const NowNextScreen({required this.live, super.key});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DataSeededGame(
      def: const NowNextGame(),
      live: live,
      data: ref.watch(scheduleDayProvider(todayKey())),
      seed: nowNextSeed,
    );
  }
}
