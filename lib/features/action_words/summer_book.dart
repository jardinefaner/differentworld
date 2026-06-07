import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/week_log.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color;

/// One week's page in the Summer Book — the world the room was in, the verbs
/// the child practiced, the teacher's noticed bits, and the moments captured.
@immutable
class SummerBookWeek {
  const SummerBookWeek({
    required this.week,
    required this.worldName,
    required this.emoji,
    required this.color,
    required this.question,
    required this.verbs,
    required this.milestone,
    required this.spell,
    required this.ally,
    required this.moments,
  });

  final int week;
  final String worldName;
  final String emoji;
  final Color color;
  final String question;
  final List<String> verbs; // labels
  final String milestone;
  final String spell;
  final String ally;
  final List<String> moments; // observation notes, oldest-first
}

/// A child's whole summer, assembled — the capstone the app lays out and
/// sends home (docs/VISION.md: "the app lays out the summer book for each
/// child, each history, each different world"). Pure + testable.
@immutable
class SummerBook {
  const SummerBook({
    required this.firstName,
    required this.title,
    required this.days,
    required this.weeks,
  });

  final String firstName;

  /// The emerging title ("The Owl Who Listens"), or '' if none yet.
  final String title;

  /// Days of participation.
  final int days;
  final List<SummerBookWeek> weeks;

  bool get isEmpty => weeks.isEmpty;
}

/// Assemble a child's Summer Book from their entries + the program start +
/// the world catalog. Mirrors the Book screen's week grouping.
SummerBook buildSummerBook({
  required String firstName,
  required List<Entry> entries,
  required DateTime? start,
  required List<CurriculumWorld> worlds,
}) {
  final collection = ActionWordsCollection.fromEntries(entries);

  // Days of participation = distinct days the child appears in a moment.
  final dayKeys = <String>{};
  final byWeek = <int, List<Entry>>{};
  for (final e in entries) {
    final local = DateTime.tryParse(e.recordedAt)?.toLocal();
    if (local == null) continue;
    dayKeys.add(dateKey(local));
    if (start == null) continue;
    final week = curriculumWeekFor(start, local);
    if (week != null) byWeek.putIfAbsent(week, () => []).add(e);
  }

  CurriculumWorld? worldFor(int week) {
    for (final w in worlds) {
      if (w.week == week) return w;
    }
    return null;
  }

  final weekPages = <SummerBookWeek>[];
  for (final week in byWeek.keys.toList()..sort()) {
    final weekEntries = byWeek[week]!;
    final world = worldFor(week);
    final log = weekLogFor(entries, week);
    weekPages.add(
      SummerBookWeek(
        week: week,
        worldName: world?.name ?? 'Week $week',
        emoji: world?.emoji ?? '🌍',
        color: world?.color ?? const Color(0xFF6B5B95),
        question: world?.question ?? '',
        verbs: _practicedVerbs(weekEntries),
        milestone: log?.milestone ?? '',
        spell: log?.spell ?? '',
        ally: log?.ally ?? '',
        moments: [
          for (final m in momentsFrom(
            weekEntries.where((e) => e.kind == EntryKind.observation).toList(),
          ).reversed)
            (m.body?.trim().isNotEmpty ?? false) ? m.body!.trim() : m.title,
        ],
      ),
    );
  }

  return SummerBook(
    firstName: firstName,
    title: collection.emergingTitle ?? '',
    days: dayKeys.length,
    weeks: weekPages,
  );
}

List<String> _practicedVerbs(List<Entry> entries) {
  final seen = <String>{};
  final out = <String>[];
  for (final e in entries) {
    if (e.kind != EntryKind.actionWords) continue;
    final day = ActionWordsDay.fromEntry(e);
    for (final v in {...day.done, ...day.verbPicks}) {
      if (seen.add(v) && verbById(v) != null) out.add(verbById(v)!.label);
    }
  }
  return out;
}

/// Replace any occurrence of another child's name in [text] with "a friend"
/// (word-boundary, case-insensitive). The export/family path runs this over
/// every free-text field so a child's keepsake never names another child —
/// the cross-child-name leak the Red Team flagged on the buddy concept (the
/// same class the incident form guards against staff→family).
String scrubOtherNames(String text, Set<String> names) {
  if (text.isEmpty || names.isEmpty) return text;
  var out = text;
  for (final name in names) {
    final n = name.trim();
    if (n.length < 2) continue; // a 1-char "name" would over-match
    final re = RegExp('\\b${RegExp.escape(n)}\\b', caseSensitive: false);
    out = out.replaceAll(re, 'a friend');
  }
  return out;
}

/// Anonymize a Summer Book for the FAMILY / EXPORT path — the child's own
/// name + the curriculum content stay; every free-text field (milestone,
/// ally, moments) is scrubbed of any OTHER child's name. [otherNames] is the
/// roster's names minus this child. Staff-side rendering passes an empty set
/// (no scrubbing). Acceptance: an exported book contains no other child's name.
SummerBook anonymizeSummerBook(SummerBook book, Set<String> otherNames) {
  if (otherNames.isEmpty) return book;
  return SummerBook(
    firstName: book.firstName, // their OWN name stays
    title: book.title,
    days: book.days,
    weeks: [
      for (final w in book.weeks)
        SummerBookWeek(
          week: w.week,
          worldName: w.worldName,
          emoji: w.emoji,
          color: w.color,
          question: w.question,
          verbs: w.verbs,
          milestone: scrubOtherNames(w.milestone, otherNames),
          spell: w.spell, // a vocab word — never a name
          ally: scrubOtherNames(w.ally, otherNames),
          moments: [
            for (final m in w.moments) scrubOtherNames(m, otherNames),
          ],
        ),
    ],
  );
}
