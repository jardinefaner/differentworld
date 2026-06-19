import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

/// Kind discriminators for the unified `entries` table.
class EntryKind {
  static const String observation = 'observation';
  static const String meal = 'meal';
  static const String nap = 'nap';
  static const String diaper = 'diaper';
  static const String incident = 'incident';
  static const String medication = 'medication';

  /// A mission completion — the room/kid did a real job (docs/MISSIONS.md).
  /// `details` carries {missionId, missionName, builds, stepsDone,
  /// stepsTotal}; feeds the track record + the growth book.
  static const String mission = 'mission';

  /// A pickup / dismissal — the child was released to an authorized
  /// person (docs/WORKFLOWS.md gap #2, the Pickup board). `body` holds
  /// who they were released to; `details` may carry {guardian_id}. A
  /// SEPARATE axis from attendance: releasing never mutates the day's
  /// attendance status (attendance = "did they come"; departure =
  /// "have they left").
  static const String departure = 'departure';

  /// A field-trip headcount roll-call for one leg (departure / at destination
  /// / return) — payload {leg, present (kid ids), expected, present_count,
  /// override_reason?, override_holder?}. Append-only: each confirm is a new
  /// entry; the latest per leg is the current count. Rides the existing
  /// `entries` sync — no migration (docs/ROADMAP field-trip headcounts).
  static const String tripHeadcount = 'trip_headcount';

  /// A day's Action Words (docs/ACTION_WORDS.md). One row per (subject,
  /// date). `details` = {verb_picks:[3], done:[…], note, word_of_day,
  /// world_name?}. The revealed world is DERIVED from verb_picks via
  /// `matchWorld`, not stored (except a kid-named fresh world).
  static const String actionWords = 'action_words';

  /// A role on the Do board for the day (docs/ACTION_WORDS.md "doing
  /// clears to zero"). `details` = {role_name, emoji, done}. Created when
  /// a teacher adds a role-card to today's board; flipped done when the
  /// room has been that role.
  static const String role = 'role';

  /// A note on the room's Wall for a world (docs/WORLD.md — every world's
  /// Problems / Dreams "sticky notes on the wall"). Space-level (no
  /// subject), anonymous in display. `body` = the note; `details` =
  /// {world_id, note_type: problem|dream|feeling|free}.
  static const String wallNote = 'wall_note';

  /// A rule the ROOM added to a world's bible (the "add a rule" community
  /// mechanic, docs/VISION.md). Space-level (no subject); `body` = the rule
  /// text; `details` = {world_id}. Shows alongside the authored
  /// `kWorldRules` on This Week — the bible becomes community-extensible.
  static const String worldRule = 'world_rule';

  /// A time capsule (docs/WORLD.md — Week 8 "seal in a box, open Week 10";
  /// Week 6 "message to the future you"). `body` = what's sealed;
  /// `details` = {sealed_until: ISO date, world_id?}. Hidden until the
  /// seal date passes.
  static const String timeCapsule = 'time_capsule';

  /// A Mood Weather check (docs/WORLD.md — "fingers up, 1 is a black hole,
  /// 5 is a supernova"). Per subject, often several a day. `details` =
  /// {value: 1-5, part?: morning|midday|afternoon}. Feeds the character
  /// sheet's WEATHER + WEATHER LOG.
  static const String mood = 'mood';

  /// The teacher's end-of-week LOG for a child (docs/WORLD.md). One row per
  /// (subject, week). `details` = {week: int, milestone?, spell?, ally?}.
  /// The structured history the Book + character sheet read from (verbs /
  /// world / inventory are DERIVED; these three are the human-noticed bits).
  static const String weekLog = 'week_log';

  /// A measured SKILL data point for a child — the RPG "stats that grow"
  /// (stillness seconds, story arm-spans, words, details, answer depth).
  /// One row per measurement; the character sheet shows latest + the delta.
  /// `details` = {skill: id, value: num, week?: int}. The skill isn't taught,
  /// it's NOTICED — the rising number is the proof a brain grew.
  static const String skillMeasure = 'skill_measure';

  /// A kept activity from the forge (verb × noun × constraint × time). Space-
  /// level, no subject. `body` = the instruction; `details` = {verb, noun,
  /// constraint, minutes}. The teacher liked a roll and wants to use it.
  static const String forgedActivity = 'forged_activity';

  /// A WORK SAMPLE — a photo of what a child made on paper (docs/VISION.md
  /// "the class is a routine … writing their answers on paper, cumulative").
  /// One row per snapped sheet, per subject. `body` = an optional caption;
  /// `details` = {world_id?, day?, in_book?}. The photo rides as an
  /// `attachment` on the entry; the per-child pile + the Summer Book read
  /// these. Distinct from `observation` (staff narrative) — this is the
  /// kid's OWN output, the cumulative proof that goes home.
  static const String workSample = 'work_sample';

  /// A REFLECTION — the stopwatch-then-reflect ritual (docs/VISION.md,
  /// 2026-06-14: "stopwatch, not pomodoro … this is growth and accountability
  /// visible"). The honest time spent on a thing PLUS a required
  /// how-did-it-go, kept as an entry so it flows into the Book / character
  /// sheet / runbook — the accumulating record IS the "visible growth".
  /// `details` = {seconds:int, face:1-4}; `body` = the optional note.
  /// subjectId set → a child's reflection (→ their Book); subjectId null →
  /// a staffer's own practice (scheduleBlockId tags the block it followed).
  static const String reflection = 'reflection';

  /// A **"Do It"** completion (docs/VISION.md 2026-06-18) — the room or a kid
  /// actually PERFORMED a real-world action from the `ContentKind.doIt` bank,
  /// and it left proof. `details` = {instruction, verb, count?}; `body` = an
  /// optional note; the photo evidence rides as an `attachment` on the entry
  /// (the same contract as observations / work samples). This is the
  /// ACCUMULATIVE counterpart to the ephemeral games — *doing IS the data
  /// entry*, and it stacks into the child's Book + the room's track record.
  /// subjectId set → a kid's doing (→ their Book); null → the room did it
  /// together.
  static const String didIt = 'did_it';
}

typedef GroupEntriesKey = ({String groupId, String kind});

/// Stream of entries for a classroom, filtered by kind. Used by the
/// per-classroom observations / meals / naps screens.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final entriesForGroupProvider = StreamProvider.autoDispose
    .family<List<Entry>, GroupEntriesKey>(
      (ref, key) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.entriesDao.watchForGroup(
          groupId: key.groupId,
          kind: key.kind,
        );
      },
    );

/// Moments (entries of any kind) tied to one schedule block, newest first.
/// Drives the live strip's ⊕ N counter and the block's moment sheet
/// (live-block Slice 2). See docs/LIVE_BLOCK_CONTEXT.md.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final momentsForBlockProvider = StreamProvider.autoDispose
    .family<List<Entry>, String>(
      (ref, blockId) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.entriesDao.watchForBlock(scheduleBlockId: blockId);
      },
    );

/// Every observation in the signed-in user's program, scoped to what
/// the viewer can see (director: all; teacher: only entries in
/// classrooms they're assigned to). Newest first.
///
/// The non-director path joins two Drift streams (entries + my
/// assignments) directly via `Rx.combineLatest2` rather than going
/// through `groupsProvider` — Riverpod 3 removed `.stream` so
/// composing provider streams is no longer the easy path. Raw Drift
/// streams stay reactive the same way.
final observationsInSpaceProvider = StreamProvider<List<Entry>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final memberId = viewer.memberId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  final entries = db.entriesDao.watchInSpace(
    spaceId: spaceId,
    kind: EntryKind.observation,
  );
  if (viewer.seesAllClassrooms || memberId == null) {
    yield* entries;
    return;
  }
  final assignments = db.groupMembersDao.watchForMember(memberId);
  yield* Rx.combineLatest2<List<Entry>, List<GroupMember>, List<Entry>>(
    entries,
    assignments,
    (entryList, assigns) {
      final ids = assigns.map((a) => a.groupId).toSet();
      return entryList
          .where((e) => e.groupId == null || ids.contains(e.groupId))
          .toList(growable: false);
    },
  );
});

typedef SubjectEntriesKey = ({String subjectId, String? kind});

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final entriesForSubjectProvider = StreamProvider.autoDispose
    .family<List<Entry>, SubjectEntriesKey>(
      (ref, key) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.entriesDao.watchForSubject(
          subjectId: key.subjectId,
          kind: key.kind,
        );
      },
    );

class EntryActions {
  EntryActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// Create an observation. Returns the new entry's id. If [id] is
  /// supplied the caller controls it (so pre-uploaded photo paths
  /// already point at the right entry); otherwise a new uuid is
  /// generated inside.
  ///
  /// Photos are persisted as separate `attachments` rows (entity_kind:
  /// 'entry'), in the order they appear in [photoUrls]. Per
  /// UX_DECISIONS §8 the entry row no longer carries photo URLs
  /// directly; attachments are first-class.
  ///
  /// [photoIds] (aligned by index with [photoUrls]) lets the caller pin each
  /// attachment's id. REQUIRED for offline correctness when a url is a
  /// `pending:` token: the bytes were uploaded via
  /// `uploadOnly(entityKind:'attachment', entityId:<this id>)`, and the queue
  /// patches the deferred upload via `updateUrl(<this id>)` — so the
  /// attachment row MUST carry that same id or the photo is silently lost.
  /// When empty (text-only callers / no offline photos) ids are random.
  Future<String> createObservation({
    required String subjectId,
    required String groupId,
    required String text,
    List<String> photoUrls = const [],
    List<String> photoIds = const [],
    String? scheduleBlockId,
    String? id,
  }) async {
    final entryId = await _create(
      kind: EntryKind.observation,
      subjectId: subjectId,
      groupId: groupId,
      body: text,
      scheduleBlockId: scheduleBlockId,
      id: id,
    );
    if (photoUrls.isNotEmpty) {
      final attachments = _ref.read(attachmentActionsProvider);
      for (var i = 0; i < photoUrls.length; i++) {
        await attachments.add(
          id: i < photoIds.length ? photoIds[i] : null,
          entityKind: 'entry',
          entityId: entryId,
          url: photoUrls[i],
          sortOrder: i,
        );
      }
    }
    return entryId;
  }

  /// Create a WORK SAMPLE (docs/VISION.md "writing their answers on paper,
  /// cumulative") — a photo of a child's paper, kept per subject and fed to
  /// the per-child pile + the Summer Book. Same offline-safe photo contract
  /// as [createObservation]: [photoIds] must be the SAME ids the caller
  /// uploaded under via `uploadOnly(entityKind:'attachment', entityId:)`, or a
  /// deferred offline upload patches a non-existent row and the photo is
  /// silently lost. [worldId]/[day] tag the sample to the routine moment.
  Future<String> createWorkSample({
    required String subjectId,
    required String groupId,
    String caption = '',
    List<String> photoUrls = const [],
    List<String> photoIds = const [],
    String? worldId,
    int? day,
    String? id,
  }) async {
    final details = <String, dynamic>{
      'world_id': ?worldId,
      'day': ?day,
    };
    final entryId = await _create(
      kind: EntryKind.workSample,
      subjectId: subjectId,
      groupId: groupId,
      body: caption,
      detailsJson: jsonEncode(details),
      id: id,
    );
    if (photoUrls.isNotEmpty) {
      final attachments = _ref.read(attachmentActionsProvider);
      for (var i = 0; i < photoUrls.length; i++) {
        await attachments.add(
          id: i < photoIds.length ? photoIds[i] : null,
          entityKind: 'entry',
          entityId: entryId,
          url: photoUrls[i],
          sortOrder: i,
        );
      }
    }
    return entryId;
  }

  /// Curate: mark (or unmark) a work sample as a keeper for the Summer Book.
  /// Merges `in_book` into the existing details so the world/day tags survive.
  Future<void> setWorkSampleInBook(Entry entry, {required bool inBook}) async {
    final db = await _ref.read(appDatabaseProvider.future);
    Map<String, dynamic> details;
    try {
      details = entry.details.trim().isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(entry.details) as Map).cast<String, dynamic>();
    } on Object catch (_) {
      details = <String, dynamic>{};
    }
    details['in_book'] = inBook;
    await db.entriesDao.updateDetails(
      id: entry.id,
      detailsJson: jsonEncode(details),
    );
  }

  /// Create a structured incident (docs/WORKFLOWS.md gap #3). The
  /// narrative goes in [text]; the structured fields ride in `details`
  /// JSON ({incident_type, action_taken?, parent_notified}). Reuses the
  /// `entries` table — `kind='incident'` — so there's no new data layer.
  /// A separate first-class kind from observations: incidents are a
  /// compliance record, filtered + exported on their own axis.
  Future<String> createIncident({
    required String subjectId,
    required String text,
    required String incidentType,
    String? groupId,
    String? actionTaken,
    String? familyNote,
    bool parentNotified = false,
    String? id,
  }) async {
    // Shape kept in sync with `incidentDetailsJson` in incidents_providers
    // (a leaf encoder there can't be imported here — that'd cycle).
    final details = <String, dynamic>{
      'incident_type': incidentType,
      if (actionTaken != null && actionTaken.trim().isNotEmpty)
        'action_taken': actionTaken.trim(),
      if (familyNote != null && familyNote.trim().isNotEmpty)
        'family_note': familyNote.trim(),
      'parent_notified': parentNotified,
    };
    return _create(
      kind: EntryKind.incident,
      subjectId: subjectId,
      groupId: groupId,
      body: text,
      detailsJson: jsonEncode(details),
      id: id,
    );
  }

  /// Record a field-trip headcount for one [leg] — append-only (each confirm
  /// is a fresh entry; readers take the latest per leg). [presentIds] are the
  /// kids accounted for; [expected] is the full roster size. An override
  /// (leaving with someone unaccounted) carries a required [overrideReason]
  /// plus who has them ([overrideHolder]) for the safety trail.
  Future<void> recordTripHeadcount({
    required String tripBlockId,
    required String leg,
    required List<String> presentIds,
    required int expected,
    String? groupId,
    String? overrideReason,
    String? overrideHolder,
  }) async {
    await _create(
      kind: EntryKind.tripHeadcount,
      scheduleBlockId: tripBlockId,
      groupId: groupId,
      detailsJson: jsonEncode(<String, dynamic>{
        'leg': leg,
        'present': presentIds,
        'expected': expected,
        'present_count': presentIds.length,
        if (overrideReason != null && overrideReason.isNotEmpty)
          'override_reason': overrideReason,
        if (overrideHolder != null && overrideHolder.isNotEmpty)
          'override_holder': overrideHolder,
      }),
    );
  }

  /// Record a **"Do It"** completion — the accumulative proof that a real-world
  /// action happened (docs/VISION.md 2026-06-18). [instruction] + [verb] come
  /// from the `ContentKind.doIt` bank; [note] is an optional what-happened;
  /// [count] fits the find/help verbs (how many). Photo evidence rides as
  /// attachments — same offline-safe contract as [createObservation]:
  /// [photoIds] must be the SAME ids the caller uploaded under via
  /// `uploadOnly(entityKind:'attachment', entityId:)`, or a deferred offline
  /// upload patches a non-existent row and the photo is silently lost.
  /// subjectId set → a kid's doing (→ their Book); null + groupId → the room's.
  Future<String> recordDidIt({
    required String instruction,
    required String verb,
    String? subjectId,
    String? groupId,
    String? scheduleBlockId,
    String? note,
    int? count,
    List<String> photoUrls = const [],
    List<String> photoIds = const [],
    String? id,
  }) async {
    final entryId = await _create(
      kind: EntryKind.didIt,
      subjectId: subjectId,
      groupId: groupId,
      scheduleBlockId: scheduleBlockId,
      body: note,
      detailsJson: jsonEncode(<String, dynamic>{
        'instruction': instruction,
        'verb': verb,
        'count': ?count,
      }),
      id: id,
    );
    if (photoUrls.isNotEmpty) {
      final attachments = _ref.read(attachmentActionsProvider);
      for (var i = 0; i < photoUrls.length; i++) {
        await attachments.add(
          id: i < photoIds.length ? photoIds[i] : null,
          entityKind: 'entry',
          entityId: entryId,
          url: photoUrls[i],
          sortOrder: i,
        );
      }
    }
    return entryId;
  }

  Future<String> _create({
    required String kind,
    String? subjectId,
    String? groupId,
    String? scheduleBlockId,
    String? body,
    String detailsJson = '{}',
    String? id,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final (:spaceId, :memberId) = _ref
        .read(viewerProvider)
        .requireSpaceAndMember(action: 'create an entry');
    final useId = id ?? _uuid.v4();
    await db.entriesDao.create(
      id: useId,
      spaceId: spaceId,
      kind: kind,
      recordedBy: memberId,
      subjectId: subjectId,
      groupId: groupId,
      scheduleBlockId: scheduleBlockId,
      body: body,
      detailsJson: detailsJson,
    );
    return useId;
  }

  /// Update an existing entry's text. Photo changes go through
  /// [AttachmentActions]; this method does not touch attachments.
  /// The observation form computes a diff against the existing
  /// attachment list and adds / removes rows directly.
  Future<void> updateText({
    required String id,
    required String text,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.updateText(id: id, body: text);
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.deleteById(id);
  }

  /// Post a note to the room's Wall for a world (space-level, anonymous).
  Future<String> createWallNote({
    required String text,
    required String worldId,
    required String noteType,
    String? groupId,
  }) => _create(
    kind: EntryKind.wallNote,
    groupId: groupId,
    body: text.trim(),
    detailsJson: jsonEncode({'world_id': worldId, 'note_type': noteType}),
  );

  /// Add a rule to a world's bible (the "add a rule" community mechanic).
  /// Space-level (no subject); shows alongside the authored `kWorldRules`
  /// on This Week. `body` = the rule; `details` = {world_id}.
  Future<String> addWorldRule({
    required String text,
    required String worldId,
  }) => _create(
    kind: EntryKind.worldRule,
    body: text.trim(),
    detailsJson: jsonEncode({'world_id': worldId}),
  );

  /// Record a Mood Weather check for a child (1–5).
  Future<String> recordMood({
    required String subjectId,
    required int value,
    String? part,
    String? groupId,
  }) => _create(
    kind: EntryKind.mood,
    subjectId: subjectId,
    groupId: groupId,
    detailsJson: jsonEncode({'value': value.clamp(1, 5), 'part': ?part}),
  );

  /// Record a REFLECTION (the stopwatch-then-reflect ritual). Works for a
  /// child (pass [subjectId] → their Book) OR a staffer's own practice (no
  /// subject; [scheduleBlockId] tags the block it followed). [face] is the
  /// 1–4 tap-a-face scale ("how did it go"); [note] is the optional line.
  /// The honest [seconds] is whatever the stopwatch measured — never a
  /// pomodoro box.
  Future<String> recordReflection({
    required int seconds,
    required int face,
    String? note,
    String? subjectId,
    String? groupId,
    String? scheduleBlockId,
  }) => _create(
    kind: EntryKind.reflection,
    subjectId: subjectId,
    groupId: groupId,
    scheduleBlockId: scheduleBlockId,
    body: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
    detailsJson: jsonEncode({'seconds': seconds, 'face': face.clamp(0, 4)}),
  );

  /// Record a measured SKILL data point for a child (the RPG "stats that
  /// grow"). One row per measurement — the character sheet reads the latest
  /// value + the delta from the previous one to show the line going up.
  Future<String> recordSkillMeasure({
    required String subjectId,
    required String skillId,
    required num value,
    int? week,
    String? groupId,
  }) => _create(
    kind: EntryKind.skillMeasure,
    subjectId: subjectId,
    groupId: groupId,
    detailsJson: jsonEncode({
      'skill': skillId,
      'value': value,
      'week': ?week,
    }),
  );

  /// Keep an activity at the space level so the teacher can come back to it.
  /// A forge roll passes the four parts; a free-typed "bring your own"
  /// activity passes just the [instruction] (the parts are optional).
  Future<String> keepForgedActivity({
    required String instruction,
    String? verbId,
    String? noun,
    String? constraint,
    int? minutes,
    String? groupId,
  }) => _create(
    kind: EntryKind.forgedActivity,
    groupId: groupId,
    body: instruction,
    detailsJson: jsonEncode({
      'verb': ?verbId,
      'noun': ?noun,
      'constraint': ?constraint,
      'minutes': ?minutes,
    }),
  );

  /// Forget a kept activity.
  Future<void> removeKeptActivity(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.deleteById(id);
  }

  /// Upsert the end-of-week LOG for (subject, week) — merges the provided
  /// fields onto any existing row, so saving just the milestone keeps the
  /// spell + ally. One row per (subject, week).
  Future<void> setWeekLog({
    required String subjectId,
    required int week,
    String? groupId,
    String? milestone,
    String? spell,
    String? ally,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final rows = await db.entriesDao
        .watchForSubject(subjectId: subjectId, kind: EntryKind.weekLog)
        .first;
    Entry? existing;
    var details = <String, dynamic>{'week': week};
    for (final e in rows) {
      Map<String, dynamic> d;
      try {
        final decoded = jsonDecode(e.details);
        d = decoded is Map<String, dynamic> ? decoded : const {};
      } on FormatException {
        d = const {};
      }
      if ((d['week'] as num?)?.toInt() == week) {
        existing = e;
        details = Map<String, dynamic>.of(d);
        break;
      }
    }
    details['week'] = week;
    if (milestone != null) details['milestone'] = milestone.trim();
    if (spell != null) details['spell'] = spell.trim();
    if (ally != null) details['ally'] = ally.trim();
    if (existing != null) {
      await db.entriesDao.updateDetails(
        id: existing.id,
        detailsJson: jsonEncode(details),
      );
    } else {
      await _create(
        kind: EntryKind.weekLog,
        subjectId: subjectId,
        groupId: groupId,
        detailsJson: jsonEncode(details),
      );
    }
  }

  /// Bury a time capsule — sealed (hidden) until [sealedUntil].
  Future<String> createTimeCapsule({
    required String text,
    required DateTime sealedUntil,
    String? subjectId,
    String? groupId,
    String? worldId,
  }) => _create(
    kind: EntryKind.timeCapsule,
    subjectId: subjectId,
    groupId: groupId,
    body: text.trim(),
    detailsJson: jsonEncode({
      'sealed_until':
          '${sealedUntil.year.toString().padLeft(4, '0')}-'
          '${sealedUntil.month.toString().padLeft(2, '0')}-'
          '${sealedUntil.day.toString().padLeft(2, '0')}',
      'world_id': ?worldId,
    }),
  );
}

final entryActionsProvider = Provider<EntryActions>(EntryActions.new);

/// The room's Wall notes (all worlds; the screen filters by world).
// autoDispose stream providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final wallNotesProvider = StreamProvider.autoDispose<List<Entry>>((ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final spaceId = ref.watch(viewerProvider).spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  yield* db.entriesDao.watchInSpace(spaceId: spaceId, kind: EntryKind.wallNote);
});

/// The `world_id` an entry is tagged to (from its details JSON), or null.
String? entryWorldId(Entry e) {
  try {
    final d = jsonDecode(e.details) as Map<String, dynamic>;
    return d['world_id'] as String?;
  } on Object {
    return null;
  }
}

/// Maps raw [entries] to the room-added rules for [worldId] — each carrying
/// its entry **id** (so the room can delete a rule it added) plus the trimmed
/// text. Pure, so the id-carrying contract is unit-testable without a DB.
List<({String id, String text})> addedWorldRulesFrom(
  List<Entry> entries,
  String worldId,
) => [
  for (final e in entries)
    if (entryWorldId(e) == worldId && (e.body ?? '').trim().isNotEmpty)
      (id: e.id, text: e.body!.trim()),
];

/// Rules the ROOM added to a world's bible (the "add a rule" mechanic),
/// newest-first — they layer on top of the authored `kWorldRules`. Keyed by
/// world id; each value carries the rule's entry id (for delete) + its text.
// autoDispose family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final addedWorldRulesProvider = StreamProvider.autoDispose
    .family<List<({String id, String text})>, String>((ref, worldId) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      final spaceId = ref.watch(viewerProvider).spaceId;
      if (spaceId == null) {
        yield const <({String id, String text})>[];
        return;
      }
      yield* db.entriesDao
          .watchInSpace(spaceId: spaceId, kind: EntryKind.worldRule)
          .map((entries) => addedWorldRulesFrom(entries, worldId));
    });

/// The activities the teacher kept from the forge (space-level), newest first.
// autoDispose stream providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final keptActivitiesProvider = StreamProvider.autoDispose<List<Entry>>((
  ref,
) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final spaceId = ref.watch(viewerProvider).spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  yield* db.entriesDao.watchInSpace(
    spaceId: spaceId,
    kind: EntryKind.forgedActivity,
  );
});

/// The program's time capsules (sealed + opened).
// autoDispose stream providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final timeCapsulesProvider = StreamProvider.autoDispose<List<Entry>>((
  ref,
) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final spaceId = ref.watch(viewerProvider).spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  yield* db.entriesDao.watchInSpace(
    spaceId: spaceId,
    kind: EntryKind.timeCapsule,
  );
});
