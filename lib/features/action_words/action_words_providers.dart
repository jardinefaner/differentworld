import 'dart:convert';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/themed_worlds.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

Map<String, dynamic> _decodeDetails(String? raw) {
  if (raw == null || raw.isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  } on FormatException {
    return <String, dynamic>{};
  }
}

List<String> _stringList(dynamic v) =>
    v is List ? [for (final e in v) e.toString()] : const <String>[];

/// One kid's Action Words for a single day — a typed view over an
/// `entries.kind='action_words'` row (null entry = no picks yet today).
class ActionWordsDay {
  const ActionWordsDay({
    required this.entry,
    required this.verbPicks,
    required this.done,
    required this.note,
    required this.wordOfDay,
    required this.worldName,
  });

  factory ActionWordsDay.fromEntry(Entry? entry) {
    if (entry == null) {
      return const ActionWordsDay(
        entry: null,
        verbPicks: <String>[],
        done: <String>{},
        note: null,
        wordOfDay: null,
        worldName: null,
      );
    }
    final d = _decodeDetails(entry.details);
    final note = (d['note'] as String?)?.trim();
    final word = (d['word_of_day'] as String?)?.trim();
    final worldName = (d['world_name'] as String?)?.trim();
    return ActionWordsDay(
      entry: entry,
      verbPicks: _stringList(d['verb_picks']),
      done: _stringList(d['done']).toSet(),
      note: (note == null || note.isEmpty) ? null : note,
      wordOfDay: (word == null || word.isEmpty) ? null : word,
      worldName: (worldName == null || worldName.isEmpty) ? null : worldName,
    );
  }

  final Entry? entry;
  final List<String> verbPicks;
  final Set<String> done;
  final String? note;
  final String? wordOfDay;

  /// A kid-chosen name for a *fresh* world (when the combo maps to no
  /// named world).
  final String? worldName;

  bool get hasPicks => verbPicks.length == kPicksPerDay;
  int get doneCount => verbPicks.where(done.contains).length;
  bool get isComplete => hasPicks && doneCount == kPicksPerDay;

  /// The world the picks reveal — deterministic lookup, null until 3 are
  /// picked.
  WorldMatch? get world =>
      hasPicks ? matchWorld(verbPicks.toSet()) : null;
}

typedef ActionWordsDayKey = ({String subjectId, String date});

/// Today (or any date)'s Action Words for one child. Reactive over the
/// synced `entries` table.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final actionWordsForDayProvider =
    StreamProvider.autoDispose.family<ActionWordsDay, ActionWordsDayKey>(
  (ref, key) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.entriesDao
        .watchForSubject(subjectId: key.subjectId, kind: EntryKind.actionWords)
        .map((entries) => ActionWordsDay.fromEntry(_entryForDate(entries, key.date)));
  },
);

Entry? _entryForDate(List<Entry> entries, String date) {
  for (final e in entries) {
    final local = DateTime.tryParse(e.recordedAt)?.toLocal();
    if (local != null && dateKey(local) == date) return e;
  }
  return null;
}

/// A child's lifetime Action Words collection — world counts + practiced-
/// verb totals + the emerging title — derived from every day's entry.
class ActionWordsCollection {
  const ActionWordsCollection({
    required this.worldCounts,
    required this.verbTotals,
    required this.dayCount,
  });

  factory ActionWordsCollection.fromEntries(List<Entry> entries) {
    final worldCounts = <String, int>{};
    final verbTotals = <String, int>{};
    var dayCount = 0;
    for (final e in entries) {
      final day = ActionWordsDay.fromEntry(e);
      if (!day.hasPicks) continue;
      dayCount++;
      final match = day.world;
      final w = match?.world;
      if (w != null) worldCounts[w.id] = (worldCounts[w.id] ?? 0) + 1;
      // Practiced = verbs actually checked off. Falls back to picks for a
      // day the teacher never marked, so the title can still form.
      final practiced = day.done.isNotEmpty ? day.done : day.verbPicks.toSet();
      for (final v in practiced) {
        verbTotals[v] = (verbTotals[v] ?? 0) + 1;
      }
    }
    return ActionWordsCollection(
      worldCounts: worldCounts,
      verbTotals: verbTotals,
      dayCount: dayCount,
    );
  }

  final Map<String, int> worldCounts;
  final Map<String, int> verbTotals;
  final int dayCount;

  int get collectedWorlds => worldCounts.length;

  String? get topWorldId => _topKey(worldCounts);
  String? get topVerbId => _topKey(verbTotals);

  /// "The Owl Who Listens" — top collected world + top practiced verb.
  /// Null until there's at least one of each.
  String? get emergingTitle {
    final wid = topWorldId;
    final vid = topVerbId;
    if (wid == null || vid == null) return null;
    World? world;
    for (final w in kNamedWorlds) {
      if (w.id == wid) {
        world = w;
        break;
      }
    }
    final verb = verbById(vid);
    if (world == null || verb == null) return null;
    return 'The ${world.name} Who ${verb.label}s';
  }

  static String? _topKey(Map<String, int> m) {
    String? best;
    var bestN = 0;
    // Sort keys for deterministic tie-breaking.
    final keys = m.keys.toList()..sort();
    for (final k in keys) {
      if (m[k]! > bestN) {
        bestN = m[k]!;
        best = k;
      }
    }
    return best;
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final actionWordsCollectionProvider =
    StreamProvider.autoDispose.family<ActionWordsCollection, String>(
  (ref, subjectId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.entriesDao
        .watchForSubject(subjectId: subjectId, kind: EntryKind.actionWords)
        .map(ActionWordsCollection.fromEntries);
  },
);

/// All Action Words entries across the program — the substrate for the
/// class-wide world book.
final _spaceActionWordsProvider = StreamProvider<List<Entry>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.entriesDao
      .watchInSpace(spaceId: spaceId, kind: EntryKind.actionWords);
});

/// A world the class INVENTED — a fresh combo (no named world) that a kid
/// named. The growth that stays unhidden (docs/ACTION_WORDS.md).
class InventedWorld {
  const InventedWorld({
    required this.name,
    required this.verbs,
    required this.count,
  });

  final String name;
  final Set<String> verbs;

  /// How many days this invented world has shown up — the class's own
  /// continuity.
  final int count;
}

/// The class's **world book** — every world the program has invented,
/// derived from `world_name` on fresh-combo days. Most-named first.
final inventedWorldsProvider = Provider<AsyncValue<List<InventedWorld>>>((ref) {
  return ref.watch(_spaceActionWordsProvider).whenData((entries) {
    // key = lower(name); value = (display name, the combo, count)
    final byName = <String, (String, Set<String>, int)>{};
    for (final e in entries) {
      final day = ActionWordsDay.fromEntry(e);
      final name = day.worldName;
      if (name == null || name.isEmpty || !day.hasPicks) continue;
      // Only genuinely invented worlds (the combo maps to no named world).
      if (day.world?.kind != WorldMatchKind.fresh) continue;
      final key = name.toLowerCase();
      final prev = byName[key];
      byName[key] = (
        prev?.$1 ?? name,
        day.verbPicks.toSet(),
        (prev?.$3 ?? 0) + 1,
      );
    }
    final list = [
      for (final v in byName.values)
        InventedWorld(name: v.$1, verbs: v.$2, count: v.$3),
    ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0
            ? byCount
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  });
});

/// How many children have picked their words today — drives the optional
/// "Today's words" card on the main Today (renders nothing at 0, so it's
/// invisible for programs that don't use Action Words).
final actionWordsPickedTodayProvider = Provider<int>((ref) {
  final entries = ref.watch(_spaceActionWordsProvider).value ?? const <Entry>[];
  final today = todayKey();
  final picked = <String>{};
  for (final e in entries) {
    final sid = e.subjectId;
    if (sid == null) continue;
    final local = DateTime.tryParse(e.recordedAt)?.toLocal();
    if (local == null || dateKey(local) != today) continue;
    if (ActionWordsDay.fromEntry(e).hasPicks) picked.add(sid);
  }
  return picked.length;
});

/// The sorted-verb key for a combo — the lookup key for class worlds.
String worldComboKey(Set<String> verbs) => (verbs.toList()..sort()).join('+');

/// THIS class's invented worlds keyed by their verb combo, so a combo
/// resolves to the world the program already named for it (continuity).
final classWorldBookProvider = Provider<Map<String, InventedWorld>>((ref) {
  final invented =
      ref.watch(inventedWorldsProvider).value ?? const <InventedWorld>[];
  return {for (final w in invented) worldComboKey(w.verbs): w};
});

/// Resolve a combo to a world, consulting THIS class's invented worlds
/// first (continuity), then the fixed catalog. A combo the class already
/// named comes back [WorldMatchKind.claimed] (shown by name, not re-
/// named); an unknown fresh combo still comes back [WorldMatchKind.fresh].
WorldMatch resolveWorld(Set<String> picks, Map<String, InventedWorld> book) {
  final claimed = book[worldComboKey(picks)];
  if (claimed != null) {
    return WorldMatch(
      kind: WorldMatchKind.claimed,
      picks: picks,
      world: World(
        id: 'class-${claimed.name.toLowerCase()}',
        emoji: '🌟',
        name: claimed.name,
        title: 'a world your class made',
        verbs: picks,
        dinnerQuestion: 'What was it like being ${claimed.name} today?',
      ),
    );
  }
  return matchWorld(picks);
}

/// Mutations for a child's Action Words day. Every write is optimistic
/// (local Drift → PowerSync). One `action_words` entry per (subject,
/// date); find-or-create runs in a transaction so a double-tap can't
/// fork two rows for the same day.
class ActionWordsActions {
  ActionWordsActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> _mutate(
    String subjectId,
    String? groupId,
    String date,
    Map<String, dynamic> Function(Map<String, dynamic> details) update,
  ) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    final memberId = viewer.memberId;
    if (spaceId == null || memberId == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.transaction(() async {
      final existing = _entryForDate(
        await db.entriesDao
            .watchForSubject(subjectId: subjectId, kind: EntryKind.actionWords)
            .first,
        date,
      );
      if (existing != null) {
        final next = update(_decodeDetails(existing.details));
        await db.entriesDao
            .updateDetails(id: existing.id, detailsJson: jsonEncode(next));
      } else {
        final next = update(<String, dynamic>{'verb_picks': <String>[], 'done': <String>[]});
        await db.entriesDao.create(
          id: _uuid.v4(),
          spaceId: spaceId,
          kind: EntryKind.actionWords,
          recordedBy: memberId,
          subjectId: subjectId,
          groupId: groupId,
          detailsJson: jsonEncode(next),
        );
      }
    });
  }

  /// Set the day's 3 verb picks (replaces any prior pick).
  Future<void> setPicks({
    required String subjectId,
    required String date,
    required List<String> verbIds,
    String? groupId,
  }) =>
      _mutate(subjectId, groupId, date, (d) {
        d['verb_picks'] = verbIds;
        // Drop any done verbs no longer picked.
        final picks = verbIds.toSet();
        d['done'] = _stringList(d['done']).where(picks.contains).toList();
        return d;
      });

  /// Toggle a picked verb's done state.
  Future<void> toggleDone({
    required String subjectId,
    required String date,
    required String verbId,
    String? groupId,
  }) =>
      _mutate(subjectId, groupId, date, (d) {
        final done = _stringList(d['done']).toSet();
        if (!done.remove(verbId)) done.add(verbId);
        d['done'] = done.toList();
        return d;
      });

  Future<void> setNote({
    required String subjectId,
    required String date,
    required String note,
    String? groupId,
  }) =>
      _mutate(subjectId, groupId, date, (d) {
        d['note'] = note.trim();
        return d;
      });

  Future<void> setWordOfDay({
    required String subjectId,
    required String date,
    required String word,
    String? groupId,
  }) =>
      _mutate(subjectId, groupId, date, (d) {
        d['word_of_day'] = word.trim();
        return d;
      });

  /// Name a *fresh* world (a combo that maps to no named world).
  Future<void> setWorldName({
    required String subjectId,
    required String date,
    required String name,
    String? groupId,
  }) =>
      _mutate(subjectId, groupId, date, (d) {
        d['world_name'] = name.trim();
        return d;
      });
}

final actionWordsActionsProvider =
    Provider<ActionWordsActions>(ActionWordsActions.new);

/// The themed "world of the week" the room is currently in — resolved from
/// the Space's `current_world` string cap. Null until a teacher picks one.
/// The daily 3-verb world nests inside this bigger weekly world
/// (docs/ACTION_WORDS.md).
final currentThemedWorldProvider = Provider<ThemedWorld?>((ref) {
  final space = ref.watch(currentSpaceProvider).value;
  return themedWorldById(space?.caps.getString(SpaceCaps.currentWorld));
});
