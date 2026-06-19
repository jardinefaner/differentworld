import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's three prompts (docs/VISION.md 2026-06-19). Any may be null if the
/// bank has none of that kind.
typedef DailyTrio = ({
  ContentItem? question,
  ContentItem? quote,
  ContentItem? mission,
});

/// Deterministic "of the day" index from a `YYYY-MM-DD` date — the same item
/// for everyone on the same calendar day, rotating across days, with NO
/// randomness (so the room shares one question, like the live activities share
/// a deterministic order). Exposed for tests.
int dailyIndexFor(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return 0;
  return d.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

ContentItem? _pickForDay(List<ContentItem> items, int dayIndex) {
  if (items.isEmpty) return null;
  return items[dayIndex % items.length];
}

/// Today's Question + Quote + Mission, picked deterministically from the
/// content bank. The Mission reuses the **Do It** bank — a real action is the
/// day's mission ("find 3 round things"), so doing it writes a `did_it` record.
final todaysDailyProvider = Provider<DailyTrio>((ref) {
  final items = ref.watch(bankedContentProvider).value ?? curatedSeeds;
  final idx = dailyIndexFor(todayKey());
  final questions = items.where((i) => i.kind == ContentKind.question).toList();
  final quotes = items.where((i) => i.kind == ContentKind.quote).toList();
  final missions = items.where((i) => i.kind == ContentKind.doIt).toList();
  return (
    question: _pickForDay(questions, idx),
    quote: _pickForDay(quotes, idx),
    mission: _pickForDay(missions, idx),
  );
});
