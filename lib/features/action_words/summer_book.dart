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

/// Why a week's page looks the way it does. [full] = the child was here and
/// the week has content. [quiet] = the child was present but nothing was
/// formally logged (a calm week — NOT neglect). [away] = the child was absent
/// that week (attendance says so). Distinguishing the last two stops a family
/// reading a staffing gap as their kid doing nothing.
enum SummerBookWeekKind { full, quiet, away }

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
    this.kind = SummerBookWeekKind.full,
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
  final SummerBookWeekKind kind;
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

  /// Worlds the child was actually present for — "away" weeks don't count as
  /// a world visited (they explain a gap; they aren't a participation).
  int get worldsVisited =>
      weeks.where((w) => w.kind != SummerBookWeekKind.away).length;
}

/// Assemble a child's Summer Book from their entries + the program start +
/// the world catalog. Mirrors the Book screen's week grouping.
SummerBook buildSummerBook({
  required String firstName,
  required List<Entry> entries,
  required DateTime? start,
  required List<CurriculumWorld> worlds,
  List<AttendanceRecord> attendance = const [],
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

  // Attendance → which curriculum weeks the child was PRESENT, and whether the
  // program tracks attendance for them at all. A gap with attendance tracked
  // and no present record = absent; a gap with no attendance data = unknown
  // (we render it "quiet", never "away", so we don't imply an absence).
  final attendedWeeks = <int>{};
  final tracksAttendance = attendance.isNotEmpty;
  if (start != null) {
    for (final a in attendance) {
      if (!_attendancePresent(a.status)) continue;
      final local = DateTime.tryParse(a.date)?.toLocal();
      if (local == null) continue;
      final week = curriculumWeekFor(start, local);
      if (week != null) attendedWeeks.add(week);
    }
  }

  CurriculumWorld? worldFor(int week) {
    for (final w in worlds) {
      if (w.week == week) return w;
    }
    return null;
  }

  SummerBookWeek pageFor(int week, SummerBookWeekKind kind) {
    final world = worldFor(week);
    final full = kind == SummerBookWeekKind.full;
    final weekEntries = byWeek[week] ?? const <Entry>[];
    final log = full ? weekLogFor(entries, week) : null;
    return SummerBookWeek(
      week: week,
      worldName: world?.name ?? 'Week $week',
      emoji: world?.emoji ?? '🌍',
      color: world?.color ?? const Color(0xFF6B5B95),
      question: full ? (world?.question ?? '') : '',
      verbs: full ? _practicedVerbs(weekEntries) : const [],
      milestone: log?.milestone ?? '',
      spell: log?.spell ?? '',
      ally: log?.ally ?? '',
      moments: full
          ? [
              for (final m in momentsFrom(
                weekEntries
                    .where((e) => e.kind == EntryKind.observation)
                    .toList(),
              ).reversed)
                if (m.body?.trim().isNotEmpty ?? false)
                  m.body!.trim()
                else
                  m.title,
            ]
          : const [],
      kind: kind,
    );
  }

  final weekPages = <SummerBookWeek>[
    for (final c in classifySummerWeeks(
      entryWeeks: byWeek.keys.toSet(),
      attendedWeeks: attendedWeeks,
      tracksAttendance: tracksAttendance,
    ))
      pageFor(c.week, c.kind),
  ];

  return SummerBook(
    firstName: firstName,
    title: collection.emergingTitle ?? '',
    days: dayKeys.length,
    weeks: weekPages,
  );
}

/// Attendance statuses that mean the child was physically here that day.
bool _attendancePresent(String status) =>
    status == 'present' || status == 'late';

/// Walk a CONTINUOUS range from the child's first signal week to their last so
/// no week is silently skipped — gaps become honest "quiet" / "away" pages
/// instead of a hole that reads as neglect. Pure + testable.
///
/// - a week with entries -> full
/// - no entries but present (attendance) -> quiet (here, nothing logged)
/// - no entries, not present, attendance IS tracked -> away (absent)
/// - no entries, not present, NO attendance data -> quiet (don't imply away)
List<({int week, SummerBookWeekKind kind})> classifySummerWeeks({
  required Set<int> entryWeeks,
  required Set<int> attendedWeeks,
  required bool tracksAttendance,
}) {
  final signalWeeks = <int>{...entryWeeks, ...attendedWeeks};
  if (signalWeeks.isEmpty) return const [];
  final firstW = signalWeeks.reduce((a, b) => a < b ? a : b);
  final lastW = signalWeeks.reduce((a, b) => a > b ? a : b);
  final out = <({int week, SummerBookWeekKind kind})>[];
  for (var week = firstW; week <= lastW; week++) {
    final SummerBookWeekKind kind;
    if (entryWeeks.contains(week)) {
      kind = SummerBookWeekKind.full;
    } else if (attendedWeeks.contains(week)) {
      kind = SummerBookWeekKind.quiet;
    } else if (tracksAttendance) {
      kind = SummerBookWeekKind.away;
    } else {
      kind = SummerBookWeekKind.quiet;
    }
    out.add((week: week, kind: kind));
  }
  return out;
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
          kind: w.kind,
        ),
    ],
  );
}
