import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/shared/format/date_keys.dart';

/// The minimal shape `buildBlockRun` needs from a schedule block. The screen
/// maps a Drift `ScheduleBlock` row into this so the builder stays pure (no
/// Drift import), deterministic, and unit-testable — exactly like the other
/// run builders in day_run.dart.
typedef BlockRunInput = ({
  String title,
  String startAt, // ISO 8601
  String endAt, // ISO 8601
  String kind, // on_site | field_trip | break | closed
  String? notes,
  String? sessionSlug, // curriculum_session_slug, if the block runs a deck
  String? status, // planned | skipped | cancelled (null == planned)
});

/// Build the day's run-of-show from the LIVE schedule — the synthesis in
/// docs/VISION.md ("the whole day is one ordered deck — an arc from open to
/// close"). Each block becomes one [DayBeat] the teacher advances through; a
/// block carrying a curriculum session can drill into its own beat deck (the
/// screen handles the drill; the beat flags it).
///
/// Pure + deterministic so it's unit-testable and can cross the cast wire,
/// just like [buildDayRun]. The schedule's order IS the arc: blocks are sorted
/// by start time, and skipped / cancelled blocks are dropped — you don't run
/// what won't happen.
List<DayBeat> buildBlockRun(List<BlockRunInput> blocks) {
  final live = [
    for (final b in blocks)
      if (b.status != 'skipped' && b.status != 'cancelled') b,
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
  return [for (final b in live) _beatForBlock(b)];
}

DayBeat _beatForBlock(BlockRunInput b) {
  final start = DateTime.tryParse(b.startAt)?.toLocal();
  final end = DateTime.tryParse(b.endAt)?.toLocal();
  final timeLabel = (start != null && end != null)
      ? '${timeOfDay(start)} – ${timeOfDay(end)}'
      : '';
  final rawSeconds = (start != null && end != null)
      ? end.difference(start).inSeconds
      : 0;
  // Cap at 6h so a malformed/overnight range can't seed an absurd timer.
  final seconds = rawSeconds < 0 ? 0 : (rawSeconds > 21600 ? 21600 : rawSeconds);
  final hasSession = (b.sessionSlug ?? '').trim().isNotEmpty;
  // A 'closed' block is the day's handoff beat; everything else is a do-it.
  final kind = b.kind == 'closed' ? DayBeatKind.close : DayBeatKind.activity;
  return DayBeat(
    kind: kind,
    label: timeLabel,
    big: b.title.trim().isEmpty ? 'Untitled block' : b.title.trim(),
    sub: (b.notes ?? '').trim(),
    lines: hasSession
        ? const ['▶ Runnable session — open to play its beats']
        : const [],
    suggestedSeconds: seconds,
  );
}
