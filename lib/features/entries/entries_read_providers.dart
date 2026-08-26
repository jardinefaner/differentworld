import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

/// The READ side of the `entries` feature — the kind discriminators plus every
/// query provider over the unified `entries` table. Split out of
/// `entries_providers.dart` (which kept the `EntryActions` write class) so each
/// half stays a readable size; `entries_providers.dart` re-exports this file,
/// so every existing `import '…/entries_providers.dart'` still sees these
/// symbols unchanged.

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

  /// Something the ROOM remembers, not a child (docs/VISION.md — Keep).
  /// `groupId` set, `subjectId` NULL, `details` = {sort, context?} where
  /// sort is one of question / discovery / word. No migration was needed:
  /// entries.group_id has always been nullable alongside subject_id.
  static const String classMemory = 'class_memory';

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

  /// A child's make-believe **Hero** (docs/VISION.md 2026-06-19) — an
  /// alter-ego card (animal · skin · powers · `[Name] of [From]` · a named
  /// drawing). One evolving row per child (upserted by `recordHero`); the
  /// creative twin of `didIt` (imaginative act → a keepsake artifact).
  static const String hero = 'hero';

  /// A **daily response** (docs/VISION.md 2026-06-19) — a child's answer to a
  /// Question / Quote / Mission of the Day, captured as a drawing or a
  /// sentence. `details` = `{prompt_kind, prompt_text}`; `body` = the written
  /// response; an optional drawing rides as an attachment. subjectId set → it
  /// flows into that child's Book ("their learning with intentionality"); null
  /// → the room answered together. ACCUMULATIVE — one row per answer, the
  /// transcript that becomes the record ("document the now").
  static const String dailyResponse = 'daily_response';

  /// The **daily parent recap** — the room's shared day + this child's own
  /// moments, sent home to their family. One row PER CHILD (subject_id set), so
  /// it rides the existing per-subject family path; each copy is scrubbed of
  /// other children's names before it's stored. See lib/features/recap/.
  static const String recap = 'recap';

  /// A child's own **weekly intention** (docs/VISION.md 2026-06-19 — the
  /// dailies/weeklies/projects arc, made personal). One row per (subject, week);
  /// `details` = {week: int, text}. The "I want to be brave" the child sets at
  /// week start — theirs alone, the spine of the per-child weekly hub.
  static const String weeklyIntention = 'weekly_intention';

  /// A child's own **project** for the week (docs/VISION.md 2026-06-19). One
  /// row per (subject, week); `details` = {week: int, title, steps: [..],
  /// done: int}. Each child's is THEIRS — distinct title + steps, their own
  /// progress — even when the room shares a theme. See lib/features/child_world/.
  static const String project = 'project';
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
/// classrooms they're assigned to — see [entriesScopedToViewer]).
/// Newest first.
final observationsInSpaceProvider = StreamProvider<List<Entry>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* entriesScopedToViewer(
    db: db,
    viewer: viewer,
    entries: db.entriesDao.watchInSpace(
      spaceId: spaceId,
      kind: EntryKind.observation,
    ),
  );
});

/// Scope an [entries] stream to what [viewer] can see: a viewer who sees all
/// classrooms (director) — or one with no member row — gets the stream as-is;
/// a teacher gets only entries in cohorts they're assigned to (space-level
/// rows with no group always pass). The shared visibility tail of
/// [observationsInSpaceProvider] and story's `spaceMomentsProvider`.
///
/// Joins two raw Drift streams via `Rx.combineLatest2` rather than going
/// through `groupsProvider` — Riverpod 3 removed `.stream` so composing
/// provider streams is no longer the easy path. Raw Drift streams stay
/// reactive the same way.
Stream<List<Entry>> entriesScopedToViewer({
  required AppDatabase db,
  required Viewer viewer,
  required Stream<List<Entry>> entries,
}) {
  final memberId = viewer.memberId;
  if (viewer.seesAllClassrooms || memberId == null) return entries;
  final assignments = db.groupMembersDao.watchForMember(memberId);
  return Rx.combineLatest2<List<Entry>, List<GroupMember>, List<Entry>>(
    entries,
    assignments,
    (entryList, assigns) {
      final ids = assigns.map((a) => a.groupId).toSet();
      return entryList
          .where((e) => e.groupId == null || ids.contains(e.groupId))
          .toList(growable: false);
    },
  );
}

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
