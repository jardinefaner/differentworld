import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_read_providers.dart';
import 'package:differentworld/features/heroes/hero_catalog.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/recap/recap_model.dart'
    show RecapChildInput, recapDetailsForChild;
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// The READ side of this feature — `EntryKind` + every query provider — lives in
// entries_read_providers.dart and is re-exported here, so every existing
// `import '…/entries_providers.dart'` keeps seeing those symbols unchanged.
// This file is the WRITE side: the EntryActions command surface.
export 'package:differentworld/features/entries/entries_read_providers.dart';

/// Optimistic write surface over the unified `entries` table. Every mutator
/// commits to local SQLite in one frame (PowerSync uploads later); each maps a
/// domain action — observe, log a mood, set a project — to a row of the right
/// [EntryKind].
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
    // Tag the attachment rows the same way the entry is tagged, so a new
    // observation photo is directly block/child-queryable (the migration
    // backfilled only EXISTING rows). subjectId → this photo is OF this
    // child (family-side canSeeSubject gating uses it); scheduleBlockId →
    // it flows to the block's recap.
    await _attachPhotos(
      entryId: entryId,
      photoUrls: photoUrls,
      photoIds: photoIds,
      subjectId: subjectId,
      scheduleBlockId: scheduleBlockId,
    );
    return entryId;
  }

  /// Persist [photoUrls] as ordered `attachments` rows (entity_kind:
  /// 'entry') on [entryId] — the shared tail of every photo-bearing
  /// mutator. [photoIds] (aligned by index) pins each attachment's id;
  /// REQUIRED for offline correctness when a url is a `pending:` token
  /// (see [createObservation]'s doc). [subjectId] / [scheduleBlockId]
  /// tag the rows when the capture context knows them; null is identical
  /// to omitting the optional params on [AttachmentActions.add].
  Future<void> _attachPhotos({
    required String entryId,
    required List<String> photoUrls,
    required List<String> photoIds,
    String? subjectId,
    String? scheduleBlockId,
  }) async {
    if (photoUrls.isEmpty) return;
    final attachments = _ref.read(attachmentActionsProvider);
    for (var i = 0; i < photoUrls.length; i++) {
      await attachments.add(
        id: i < photoIds.length ? photoIds[i] : null,
        entityKind: 'entry',
        entityId: entryId,
        url: photoUrls[i],
        sortOrder: i,
        subjectId: subjectId,
        scheduleBlockId: scheduleBlockId,
      );
    }
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
    String? role,
    String? id,
  }) async {
    final details = <String, dynamic>{
      'world_id': ?worldId,
      'day': ?day,
      // The ROLE this piece was made practising (role-card capture), so the
      // trail/role-card can count "was a Bee 4x this week". Null for general work.
      'role': ?role,
    };
    final entryId = await _create(
      kind: EntryKind.workSample,
      subjectId: subjectId,
      groupId: groupId,
      body: caption,
      detailsJson: jsonEncode(details),
      id: id,
    );
    await _attachPhotos(
      entryId: entryId,
      photoUrls: photoUrls,
      photoIds: photoIds,
    );
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
    await _attachPhotos(
      entryId: entryId,
      photoUrls: photoUrls,
      photoIds: photoIds,
    );
    return entryId;
  }

  /// Upsert a child's **Hero** (docs/VISION.md 2026-06-19). One evolving row
  /// per child: if a hero entry already exists, its `details` are rewritten in
  /// place (the hero "grows"); else a new one is created. A new drawing photo,
  /// when provided, is attached to the hero entry via the same offline-safe
  /// path as every other attachment (the `photoIds[i]` MUST equal the id passed
  /// to `uploadOnly` so a deferred offline upload patches the right row).
  Future<String> recordHero({
    required String subjectId,
    required HeroDraft draft,
    String? groupId,
    List<String> photoUrls = const [],
    List<String> photoIds = const [],
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final existing = await db.entriesDao
        .watchForSubject(subjectId: subjectId, kind: EntryKind.hero, limit: 1)
        .first;
    final String entryId;
    if (existing.isNotEmpty) {
      entryId = existing.first.id;
      await db.entriesDao.updateDetails(
        id: entryId,
        detailsJson: draft.toDetailsJson(),
      );
    } else {
      entryId = await _create(
        kind: EntryKind.hero,
        subjectId: subjectId,
        groupId: groupId,
        detailsJson: draft.toDetailsJson(),
      );
    }
    await _attachPhotos(
      entryId: entryId,
      photoUrls: photoUrls,
      photoIds: photoIds,
    );
    return entryId;
  }

  /// Record a child's **daily response** (docs/VISION.md 2026-06-19) — their
  /// answer to a Question / Quote / Mission of the Day, a drawing or a
  /// sentence. Accumulative: one row per answer (subjectId → their Book; null
  /// → the room answered together). A drawing, when provided, rides as an
  /// attachment via the offline-safe pinned-id path.
  Future<String> recordDailyResponse({
    required String promptKind,
    required String promptText,
    String? subjectId,
    String? groupId,
    String? responseText,
    List<String> photoUrls = const [],
    List<String> photoIds = const [],
    String? id,
  }) async {
    final trimmed = responseText?.trim();
    final entryId = await _create(
      kind: EntryKind.dailyResponse,
      subjectId: subjectId,
      groupId: groupId,
      body: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      detailsJson: jsonEncode(<String, dynamic>{
        'prompt_kind': promptKind,
        'prompt_text': promptText,
      }),
      id: id,
    );
    await _attachPhotos(
      entryId: entryId,
      photoUrls: photoUrls,
      photoIds: photoIds,
    );
    return entryId;
  }

  /// Send the **daily parent recap** for a room (docs/VISION.md 2026-06-19):
  /// one entry PER CHILD, each carrying the room's shared day + that child's own
  /// moments, scrubbed of every other child's name. UPSERTS by (subject, recap,
  /// date) so re-sending the same day updates in place instead of duplicating.
  Future<void> recordRecap({
    required String groupId,
    required String date,
    required List<String> activities,
    required List<RecapChildInput> children,
    String? question,
    String? momentNote,
  }) async {
    if (children.isEmpty) return;
    final db = await _ref.read(appDatabaseProvider.future);
    // The full roster name pool — each child's copy scrubs everyone else's.
    final pool = <String>{for (final c in children) ...c.ownNames};
    for (final child in children) {
      final others = pool.difference(child.ownNames);
      final details = jsonEncode(
        recapDetailsForChild(
          date: date,
          activities: activities,
          question: question,
          momentNote: momentNote,
          child: child,
          otherNames: others,
        ),
      );
      // Upsert by (subject, recap, date): find this child's recap row for today.
      final existing = await db.entriesDao
          .watchForSubject(
            subjectId: child.subjectId,
            kind: EntryKind.recap,
            limit: 30,
          )
          .first;
      Entry? match;
      for (final e in existing) {
        if (_recapDateOf(e) == date) {
          match = e;
          break;
        }
      }
      if (match != null) {
        await db.entriesDao.updateDetails(id: match.id, detailsJson: details);
      } else {
        await _create(
          kind: EntryKind.recap,
          subjectId: child.subjectId,
          groupId: groupId,
          detailsJson: details,
        );
      }
    }
  }

  /// The `date` stored in a recap entry's details (empty if unparseable).
  String _recapDateOf(Entry e) {
    try {
      final d = jsonDecode(e.details);
      if (d is Map && d['date'] is String) return d['date'] as String;
    } on Object {
      // A malformed row just won't match — never throws into the upsert.
    }
    return '';
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

  /// Re-insert a deleted entry verbatim — the `deleteWithUndo` undo path.
  Future<void> restore(Entry entry) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.restore(entry);
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
  }) => _upsertSubjectWeek(
    subjectId: subjectId,
    week: week,
    groupId: groupId,
    kind: EntryKind.weekLog,
    mutate: (d) {
      if (milestone != null) d['milestone'] = milestone.trim();
      if (spell != null) d['spell'] = spell.trim();
      if (ally != null) d['ally'] = ally.trim();
      return d;
    },
  );

  /// Upsert the single (subject, week) row of [kind], applying [mutate] to its
  /// details map — shared by the week log, the per-child weekly intention, and
  /// the project (docs/VISION.md 2026-06-19).
  Future<void> _upsertSubjectWeek({
    required String subjectId,
    required int week,
    required String kind,
    required Map<String, dynamic> Function(Map<String, dynamic>) mutate,
    String? groupId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final rows = await db.entriesDao
        .watchForSubject(subjectId: subjectId, kind: kind)
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
    details = mutate(details);
    if (existing != null) {
      await db.entriesDao.updateDetails(
        id: existing.id,
        detailsJson: jsonEncode(details),
      );
    } else {
      await _create(
        kind: kind,
        subjectId: subjectId,
        groupId: groupId,
        detailsJson: jsonEncode(details),
      );
    }
  }

  /// Set a child's **weekly intention** — theirs alone, one row per
  /// (subject, week), upserted so editing it doesn't add a row.
  Future<void> setWeeklyIntention({
    required String subjectId,
    required int week,
    required String text,
    String? groupId,
  }) => _upsertSubjectWeek(
    subjectId: subjectId,
    week: week,
    groupId: groupId,
    kind: EntryKind.weeklyIntention,
    mutate: (d) => d..['text'] = text.trim(),
  );

  /// Create or replace a child's **project** for the week — title + steps. Keeps
  /// `done` when only the title changes; re-clamps it when the step list
  /// changes. One row per (subject, week).
  Future<void> setProject({
    required String subjectId,
    required int week,
    required String title,
    required List<String> steps,
    String? groupId,
  }) => _upsertSubjectWeek(
    subjectId: subjectId,
    week: week,
    groupId: groupId,
    kind: EntryKind.project,
    mutate: (d) {
      final trimmed = [for (final s in steps) s.trim()]
        ..removeWhere((s) => s.isEmpty);
      d['title'] = title.trim();
      d['steps'] = trimmed;
      final prevDone = (d['done'] as num?)?.toInt() ?? 0;
      d['done'] = prevDone.clamp(0, trimmed.length);
      return d;
    },
  );

  /// Update a child's project progress — how many steps are done (clamped to
  /// the step count).
  Future<void> setProjectProgress({
    required String subjectId,
    required int week,
    required int done,
    String? groupId,
  }) => _upsertSubjectWeek(
    subjectId: subjectId,
    week: week,
    groupId: groupId,
    kind: EntryKind.project,
    mutate: (d) {
      final total = (d['steps'] as List?)?.length ?? 0;
      d['done'] = done.clamp(0, total);
      return d;
    },
  );

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
