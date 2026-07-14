import 'dart:convert';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// The seeded sample child — "Sam" — who makes the book payoff visible on
/// day one (docs/VISION.md dream #1: every child becomes their own book).
///
/// Sam ships with six weeks of story: real-shaped observations with a
/// growth arc (arrives quiet → finds the building table → leads a build),
/// plus two completed missions. Everything is fiction; the subject row
/// carries [SubjectCaps.isSample] and the space carries
/// [SpaceCaps.onboardingSampleSubjectId] so the starter spine can badge,
/// link, and remove it wholesale.
///
/// Seeded once, right after space creation (create_space_screen). Removal
/// is [removeSampleChild] — a cascading delete, so it stays behind a
/// confirm (the modals law's cascade exception).

/// One beat of Sam's story: [daysAgo] before seed time, at [hour]:[minute]
/// local, an entry of [kind] with [body] (+ optional [details] JSON map).
class _Beat {
  const _Beat(
    this.daysAgo,
    this.hour,
    this.minute,
    this.kind,
    this.body, [
    this.details,
  ]);

  final int daysAgo;
  final int hour;
  final int minute;
  final String kind;
  final String body;
  final Map<String, Object?>? details;
}

/// Six weeks, newest last. Written in the app's own observation voice —
/// concrete, warm, specific — so the story screen and the book read the
/// way a real child's will.
const List<_Beat> _samStory = [
  _Beat(
    41,
    15,
    40,
    'observation',
    'First day. Sam stayed near the door for the first twenty minutes, '
        'watching the building table. Came over when Ms. R asked for a '
        '"tower inspector" — inspected every tower very seriously.',
  ),
  _Beat(
    39,
    16,
    5,
    'observation',
    'Sam brought a drawing of yesterday\'s tallest tower "so we can '
        'build it again but taller." Taped it above the building table.',
  ),
  _Beat(
    36,
    15,
    55,
    'observation',
    'Chose "explore" as an action word and spent snack asking what\'s '
        'inside a marble. Nobody knew. We wrote it on the wonder wall.',
  ),
  _Beat(
    33,
    16,
    30,
    'observation',
    'Hard goodbye at pickup — wanted to finish the bridge. We took a '
        'photo of the half-bridge and promised it would survive the night.',
  ),
  _Beat(
    29,
    15,
    45,
    'observation',
    'The bridge survived. Sam checked on it before even putting a '
        'backpack down, then recruited two friends to "make it earthquake '
        'proof."',
  ),
  _Beat(
    27,
    16,
    10,
    'mission',
    "Snack helper — counted out cups for the whole room and didn't "
        'lose track once.',
    {
      'missionName': 'Snack helper',
      'builds': 'responsibility',
      'stepsDone': 3,
      'stepsTotal': 3,
    },
  ),
  _Beat(
    22,
    15,
    35,
    'observation',
    'Quiet afternoon. Sam sat with the new kid at the drawing table and '
        'narrated the whole room for him — "that\'s the loud corner, '
        'that\'s the good-marker jar."',
  ),
  _Beat(
    20,
    16,
    20,
    'observation',
    'Asked to run the This-or-That game on the TV and read every card '
        'out loud for the group. Big voice. New thing.',
  ),
  _Beat(
    15,
    15,
    50,
    'observation',
    'Built a marble run with the ramp pieces INSIDE the tower base — '
        'said "the inspector approves." Three kids copied the design.',
  ),
  _Beat(
    13,
    16,
    0,
    'mission',
    'Room librarian for the week — books faced out, "like a store."',
    {
      'missionName': 'Room librarian',
      'builds': 'ownership',
      'stepsDone': 4,
      'stepsTotal': 4,
    },
  ),
  _Beat(
    8,
    15,
    30,
    'observation',
    'Led the building table without being asked — assigned jobs '
        '("you\'re beams, you\'re windows") and thanked everyone at '
        'cleanup. The tower hit the shelf. New record.',
  ),
  _Beat(
    6,
    16,
    15,
    'observation',
    'Wonder wall follow-up: Sam brought the answer about marbles from '
        'the library. Presented it at circle like a press conference.',
  ),
  _Beat(
    1,
    15,
    45,
    'observation',
    'Told the new kid: "you can be inspector today, I\'ll teach you." '
        'Six weeks ago Sam WAS the kid by the door.',
  ),
];

/// Seed Sam into a freshly-created space. Call once, right after
/// `createSpaceForMember` — the caller owns idempotence (it only runs on
/// the create path). Returns the sample subject id.
Future<String> seedSampleChild(
  AppDatabase db, {
  required String spaceId,
  required String memberId,
}) async {
  const uuid = Uuid();
  final subjectId = uuid.v4();
  final now = DateTime.now();
  final nowIso = now.toUtc().toIso8601String();

  await db.transaction(() async {
    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            id: subjectId,
            spaceId: spaceId,
            firstName: 'Sam',
            lastName: 'Sample',
            notes: const Value(
              'Not a real child — Sam shows what six weeks of captured '
              'moments become. Remove from the setup card on Today.',
            ),
            capabilities: jsonEncode(const {SubjectCaps.isSample: true}),
            createdAt: nowIso,
            updatedAt: nowIso,
          ),
        );
    for (final beat in _samStory) {
      final at = DateTime(
        now.year,
        now.month,
        now.day,
        beat.hour,
        beat.minute,
      ).subtract(Duration(days: beat.daysAgo));
      final atIso = at.toUtc().toIso8601String();
      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: uuid.v4(),
              spaceId: spaceId,
              subjectId: Value(subjectId),
              kind: beat.kind,
              body: Value(beat.body),
              details: jsonEncode(beat.details ?? const <String, Object?>{}),
              recordedBy: memberId,
              recordedAt: atIso,
              updatedAt: atIso,
            ),
          );
    }
    // Point the starter spine at Sam + mark this space as spine-eligible
    // (the marker is permanent; pre-existing spaces never get the spine).
    final space = await db.spacesDao.findById(spaceId);
    if (space != null) {
      final caps = space.caps
          .setting(SpaceCaps.onboardingStarted, true)
          .setting(SpaceCaps.onboardingSampleSubjectId, subjectId);
      await db.spacesDao.updateCapabilities(spaceId, caps.toJson());
    }
  });
  return subjectId;
}

/// Remove Sam and every seeded story row — the starter card's overflow
/// action. Cascading (subject + entries), so callers confirm first.
Future<void> removeSampleChild(
  AppDatabase db, {
  required String spaceId,
  required String subjectId,
}) async {
  await db.transaction(() async {
    await (db.delete(
      db.entries,
    )..where((e) => e.subjectId.equals(subjectId))).go();
    await (db.delete(db.subjects)..where((s) => s.id.equals(subjectId))).go();
    final space = await db.spacesDao.findById(spaceId);
    if (space != null) {
      final caps = space.caps.setting(
        SpaceCaps.onboardingSampleSubjectId,
        null,
      );
      await db.spacesDao.updateCapabilities(spaceId, caps.toJson());
    }
  });
}
