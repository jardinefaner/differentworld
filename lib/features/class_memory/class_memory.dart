import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';

/// What a ROOM remembers (docs/VISION.md 2026-08-26 — the Keep function).
///
/// Not everything worth keeping belongs to a child. A question nobody could
/// answer, a word the room started using, the moment everyone realised they
/// had each solved it differently — those belong to the class, and until now
/// the app had nowhere to put them. Every artifact was subject-tagged, so a
/// room accumulated nothing of its own and each activity ended at dismissal.
///
/// **No migration.** `entries.group_id` is nullable and sits alongside
/// `subject_id`, so an entry attached to a room rather than a child was
/// always representable — the schema was ready and the surface was missing.
/// A class memory is exactly: `kind == 'class_memory'`, `groupId` set,
/// `subjectId` null.
///
/// The three sorts are stored in `details` rather than as three separate
/// entry kinds, because they are one thing viewed three ways: the room's
/// memory. Splitting them at the kind level would mean three queries, three
/// providers, and a fourth sort becoming a schema decision instead of a
/// one-line addition.
enum ClassMemorySort {
  /// Asked, and still open. The most valuable of the three precisely
  /// because it is unfinished — it is the one that can come BACK.
  question('question', 'Questions we haven’t answered'),

  /// Something the room worked out together.
  discovery('discovery', 'Things we discovered'),

  /// A word the room started using and kept.
  word('word', 'Words we learned')
  ;

  const ClassMemorySort(this.id, this.heading);

  /// Stored in `details.sort`. Stable — changing one orphans existing rows.
  final String id;

  /// The room-facing heading. Deliberately first-person plural: this is the
  /// class's own memory, not a staff record about them.
  final String heading;

  static ClassMemorySort? byId(String? id) {
    for (final s in ClassMemorySort.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// One remembered thing, read back off an [Entry].
class ClassMemory {
  const ClassMemory({
    required this.id,
    required this.sort,
    required this.text,
    required this.recordedAt,
    this.context,
  });

  final String id;
  final ClassMemorySort sort;
  final String text;
  final DateTime? recordedAt;

  /// What was happening — a block title, usually. Optional because a memory
  /// caught in a corridor is still a memory, and demanding context is how a
  /// capture surface becomes paperwork.
  final String? context;

  /// Null when the row is not a class memory, or carries an unknown sort —
  /// a row written by a newer build than this one is skipped rather than
  /// guessed at.
  static ClassMemory? fromEntry(Entry e) {
    if ((e.body ?? '').trim().isEmpty) return null;
    Map<String, dynamic> details;
    try {
      final decoded = jsonDecode(e.details) as Object?;
      details = decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return null;
    }
    final sort = ClassMemorySort.byId(details['sort'] as String?);
    if (sort == null) return null;
    final ctx = (details['context'] as String?)?.trim();
    return ClassMemory(
      id: e.id,
      sort: sort,
      text: e.body!.trim(),
      recordedAt: DateTime.tryParse(e.recordedAt)?.toLocal(),
      context: ctx == null || ctx.isEmpty ? null : ctx,
    );
  }
}

/// Group the room's memories by sort, newest first within each.
///
/// Returns every sort in enum order, including empty ones — the headings are
/// a prompt as much as a label, and a room that has never recorded a
/// question benefits more from seeing the heading than from its absence.
Map<ClassMemorySort, List<ClassMemory>> groupBySort(
  Iterable<ClassMemory> memories,
) {
  final out = <ClassMemorySort, List<ClassMemory>>{
    for (final s in ClassMemorySort.values) s: <ClassMemory>[],
  };
  for (final m in memories) {
    out[m.sort]!.add(m);
  }
  return out;
}

/// The oldest still-open question — what Return reaches for first.
///
/// Oldest, not newest, and that is the whole design: a question from three
/// weeks ago has had time to become surprising again, while one from this
/// morning is still in the room's head and returning it would be noise.
ClassMemory? oldestOpenQuestion(Iterable<ClassMemory> memories) {
  ClassMemory? best;
  for (final m in memories) {
    if (m.sort != ClassMemorySort.question) continue;
    final at = m.recordedAt;
    if (at == null) continue;
    final bestAt = best?.recordedAt;
    if (bestAt == null || at.isBefore(bestAt)) best = m;
  }
  return best;
}
