import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';

/// One beat in a child's Story — a typed, human view over an `entries`
/// row of any kind. The Story timeline weaves these into the memory: every
/// tool the room uses drops a moment, and the moments become the story
/// (docs/ACTION_WORDS.md "growth unhidden").
class Moment {
  const Moment({
    required this.entry,
    required this.emoji,
    required this.title,
    this.body,
    this.showsPhotos = false,
  });

  final Entry entry;
  final String emoji;

  /// A one-line headline for the beat.
  final String title;

  /// Optional longer text (an observation note, an incident narrative).
  final String? body;

  /// Whether to look up + show attached photos for this entry.
  final bool showsPhotos;

  String get id => entry.id;
  DateTime? get when => DateTime.tryParse(entry.recordedAt)?.toLocal();
}

Map<String, dynamic> _details(String raw) {
  try {
    final d = jsonDecode(raw);
    return d is Map<String, dynamic> ? d : const {};
  } on FormatException {
    return const {};
  }
}

/// Map any entry to a story beat. Returns null for kinds that aren't part
/// of the narrative (a departure is logistics, not a memory).
Moment? momentFor(Entry e) {
  switch (e.kind) {
    case EntryKind.observation:
      final note = (e.body ?? '').trim();
      return Moment(
        entry: e,
        emoji: '📝',
        title: 'A moment',
        body: note.isEmpty ? null : note,
        showsPhotos: true,
      );

    case EntryKind.actionWords:
      final day = ActionWordsDay.fromEntry(e);
      if (!day.hasPicks) return null;
      final world = day.world?.world;
      final verbs = verbsByIds(
        day.verbPicks,
      ).map((v) => v.label.toLowerCase()).join(', ');
      final name = world?.name ?? day.worldName ?? 'a new world';
      final emoji = world?.emoji ?? '🌟';
      return Moment(
        entry: e,
        emoji: emoji,
        title: 'Was $name',
        body: verbs.isEmpty ? null : 'Practiced $verbs',
      );

    case EntryKind.mission:
      final d = _details(e.details);
      final name = (d['missionName'] as String?)?.trim();
      return Moment(
        entry: e,
        emoji: '🎯',
        title: (name == null || name.isEmpty) ? 'Did a mission' : 'Did: $name',
      );

    case EntryKind.role:
      final d = _details(e.details);
      final name = (d['role_name'] as String?)?.trim();
      return Moment(
        entry: e,
        emoji: (d['emoji'] as String?) ?? '🎭',
        title: (name == null || name.isEmpty) ? 'Took a role' : 'Was a $name',
      );

    case EntryKind.incident:
      final inc = Incident.fromEntry(e);
      return Moment(
        entry: e,
        emoji: '⚠️',
        title: '${inc.type.label} logged',
        body: inc.narrative.isEmpty ? null : inc.narrative,
        showsPhotos: true,
      );

    case EntryKind.meal:
      return Moment(entry: e, emoji: '🍎', title: 'Snack / meal');
    case EntryKind.nap:
      return Moment(entry: e, emoji: '😴', title: 'Rested');
    case EntryKind.diaper:
      return Moment(entry: e, emoji: '🧷', title: 'Diaper change');
    case EntryKind.medication:
      return Moment(entry: e, emoji: '💊', title: 'Medication given');

    // Logistics, not memory.
    case EntryKind.departure:
      return null;
    default:
      final note = (e.body ?? '').trim();
      return Moment(
        entry: e,
        emoji: '•',
        title: 'A moment',
        body: note.isEmpty ? null : note,
      );
  }
}

/// Map a child's entries (any kind, newest-first) to story beats, dropping
/// the kinds that aren't part of the narrative.
List<Moment> momentsFrom(List<Entry> entries) =>
    [for (final e in entries) momentFor(e)].whereType<Moment>().toList();
