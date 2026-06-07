import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/story/moment.dart';

/// A rolled-up highlight of a Story over a period (today / this week) — the
/// "wrap" that turns the timeline into something you can read at a glance
/// or send home. Pure + testable.
class StoryWrap {
  const StoryWrap({
    required this.periodLabel,
    required this.worlds,
    required this.topVerbs,
    required this.missions,
    required this.highlights,
    required this.momentCount,
    required this.text,
  });

  final String periodLabel;

  /// "🐬 Dolphin" entries, most-recent first, deduped.
  final List<String> worlds;
  final List<String> topVerbs;
  final List<String> missions;

  /// Observation notes — the actual captured stories.
  final List<String> highlights;
  final int momentCount;

  /// The assembled, copy-pasteable summary.
  final String text;

  bool get isEmpty => momentCount == 0;
}

Map<String, dynamic> _details(String raw) {
  try {
    final d = jsonDecode(raw);
    return d is Map<String, dynamic> ? d : const {};
  } on FormatException {
    return const {};
  }
}

String _joinAnd(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  if (items.length == 2) return '${items[0]} and ${items[1]}';
  return '${items.sublist(0, items.length - 1).join(', ')}, and ${items.last}';
}

/// Roll [entries] (any kind, newest-first) recorded on/after [cutoff] into
/// a wrap. [subjectName] personalizes the prose ("Maya was…"); pass "The
/// room" for a room wrap.
StoryWrap buildWrap({
  required String subjectName,
  required String periodLabel,
  required List<Entry> entries,
  required DateTime cutoff,
}) {
  final inWindow = <Entry>[];
  for (final e in entries) {
    final local = DateTime.tryParse(e.recordedAt)?.toLocal();
    if (local == null || local.isBefore(cutoff)) continue;
    inWindow.add(e);
  }

  final worlds = <String>[];
  final seenWorld = <String>{};
  final verbCounts = <String, int>{};
  final missions = <String>[];
  final seenMission = <String>{};
  final highlights = <String>[];

  for (final e in inWindow) {
    switch (e.kind) {
      case EntryKind.actionWords:
        final day = ActionWordsDay.fromEntry(e);
        if (!day.hasPicks) break;
        final w = day.world?.world;
        final label = w == null
            ? '🌟 ${day.worldName ?? 'a new world'}'
            : '${w.emoji} ${w.name}';
        if (seenWorld.add(label)) worlds.add(label);
        final practiced =
            day.done.isNotEmpty ? day.done : day.verbPicks.toSet();
        for (final v in practiced) {
          verbCounts[v] = (verbCounts[v] ?? 0) + 1;
        }
      case EntryKind.mission:
        final name = (_details(e.details)['missionName'] as String?)?.trim();
        if (name != null && name.isNotEmpty && seenMission.add(name)) {
          missions.add(name);
        }
      case EntryKind.observation:
        final note = (e.body ?? '').trim();
        if (note.isNotEmpty && highlights.length < 3) highlights.add(note);
    }
  }

  final topVerbs = (verbCounts.keys.toList()
        ..sort((a, b) {
          final byCount = verbCounts[b]!.compareTo(verbCounts[a]!);
          return byCount != 0 ? byCount : a.compareTo(b);
        }))
      .take(3)
      .map((id) => verbById(id)?.label.toLowerCase())
      .whereType<String>()
      .toList();

  final momentCount = momentsFrom(inWindow).length;

  // Assemble the prose.
  final lines = <String>[];
  if (worlds.isNotEmpty) {
    lines.add('$subjectName was ${_joinAnd(worlds)}.');
  }
  if (topVerbs.isNotEmpty) {
    lines.add('Practiced ${_joinAnd(topVerbs)}.');
  }
  if (missions.isNotEmpty) {
    lines.add('Did ${_joinAnd(missions)}.');
  }
  if (momentCount > 0) {
    lines.add(momentCount == 1
        ? '1 moment captured.'
        : '$momentCount moments captured.');
  }
  if (highlights.isNotEmpty) {
    lines.add('Highlights: ${highlights.map((h) => '“$h”').join(' · ')}');
  }

  return StoryWrap(
    periodLabel: periodLabel,
    worlds: worlds,
    topVerbs: topVerbs,
    missions: missions,
    highlights: highlights,
    momentCount: momentCount,
    text: lines.isEmpty
        ? '$periodLabel: a quiet one — nothing captured yet.'
        : '$periodLabel\n${lines.join('\n')}',
  );
}
