import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Family-lens reads that the local Drift mirror can't satisfy.
///
/// **Why this file exists.** Guardians have a `members.space_id = null`
/// row (the `handle_new_user` trigger creates a row for every auth
/// identity, but guardians never join a space the way staff do). The
/// `by_space` PowerSync stream gates each query on
/// `space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`
/// → `IN (NULL)` → false. So per-subject tables (subjects, attendance,
/// entries, attachments) never reach a guardian's device.
///
/// The new `by_guardian` stream picks up rows keyed DIRECTLY on a
/// guardian id (guardians, spaces, subject_guardians, messages,
/// export_recipients) — those are now offline-first. But subjects /
/// attendance / entries / attachments are per-subject and need a
/// 2-level subquery (subject_id → subject_guardians → guardian →
/// user_id) which PowerSync's SQL subset hasn't been verified to
/// accept. Until we settle that, the family screens read those tables
/// here via direct PostgREST. RLS is already loose-via-`for all`
/// on these tables (see migration 20260517000003) so the queries
/// resolve correctly for any authenticated user; the
/// `viewer.canSeeSubject(...)` guards inside each provider keep one
/// guardian from peeking at another family's data.
///
/// Trade-off: family-lens per-subject reads are NOT offline-first.
/// Cold launch without network shows empty until the round-trip lands.
/// Acceptable for the per-child timeline (parents check this online
/// during the day); messages stay offline-first because they read
/// from Drift via the new sync stream.

/// Subjects (children) the signed-in guardian is linked to. Replaces
/// the Drift join in `db.guardiansDao.watchChildrenFor` for the
/// guardian path — subjects aren't local for guardians yet.
///
/// Server-side join via the PostgREST `!inner` syntax — only returns
/// subjects whose `subject_guardians` row matches the guardian's id.
/// Empty list (not error) when the viewer isn't a guardian.
// ignore: specify_nonobvious_property_types
final familyChildrenProvider =
    FutureProvider.autoDispose<List<Subject>>((ref) async {
  final viewer = ref.watch(viewerProvider);
  if (viewer is! GuardianViewer) return const <Subject>[];
  final supabase = Supabase.instance.client;
  final rows = await supabase
      .from('subjects')
      .select('*, subject_guardians!inner(guardian_id)')
      .eq('subject_guardians.guardian_id', viewer.guardian.id)
      .order('first_name');
  return [
    for (final r in rows) _subjectFromMap(r),
  ];
});

/// One Subject by id for the family lens. Returns null when the
/// signed-in guardian isn't linked to this kid — defensive layer on
/// top of the router gate.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final familySubjectByIdProvider =
    FutureProvider.autoDispose.family<Subject?, String>((ref, id) async {
  final viewer = ref.watch(viewerProvider);
  if (viewer is! GuardianViewer) return null;
  if (!viewer.canSeeSubject(id)) return null;
  final supabase = Supabase.instance.client;
  final row = await supabase
      .from('subjects')
      .select()
      .eq('id', id)
      .maybeSingle();
  if (row == null) return null;
  return _subjectFromMap(row);
});

/// Today's attendance row for one subject. Single-row equivalent of
/// the staff-side `attendanceForDayProvider` (which is per-group).
typedef FamilyAttendanceKey = ({String subjectId, String dateIso});

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final familyAttendanceForSubjectProvider =
    FutureProvider.autoDispose.family<AttendanceRecord?, FamilyAttendanceKey>(
  (ref, key) async {
    final viewer = ref.watch(viewerProvider);
    if (viewer is! GuardianViewer) return null;
    if (!viewer.canSeeSubject(key.subjectId)) return null;
    final supabase = Supabase.instance.client;
    final row = await supabase
        .from('attendance_records')
        .select()
        .eq('subject_id', key.subjectId)
        .eq('date', key.dateIso)
        .maybeSingle();
    if (row == null) return null;
    return _attendanceFromMap(row);
  },
);

/// Entries for a subject, optionally filtered by kind. Newest first,
/// capped at 100 rows so the round-trip stays bounded.
typedef FamilyEntriesKey = ({String subjectId, String? kind});

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final familyEntriesForSubjectProvider =
    FutureProvider.autoDispose.family<List<Entry>, FamilyEntriesKey>(
  (ref, key) async {
    final viewer = ref.watch(viewerProvider);
    if (viewer is! GuardianViewer) return const <Entry>[];
    if (!viewer.canSeeSubject(key.subjectId)) return const <Entry>[];
    final supabase = Supabase.instance.client;
    final kind = key.kind;
    final filtered = kind == null
        ? supabase.from('entries').select().eq('subject_id', key.subjectId)
        : supabase
            .from('entries')
            .select()
            .eq('subject_id', key.subjectId)
            .eq('kind', kind);
    final rows = await filtered
        .order('recorded_at', ascending: false)
        .limit(100);
    return [
      for (final r in rows) _entryFromMap(r),
    ];
  },
);

/// Attachments for an entity (entry id, subject id, …) for the
/// family lens. Same shape as the staff
/// `attachmentsForEntityProvider`, but PostgREST-backed.
///
/// Carries the **owning subject_id** alongside the (kind, id) pair so
/// we can gate on `viewer.canSeeSubject(...)` BEFORE issuing the
/// query. RLS on `attachments` is wide-open (per migration
/// 20260517000003's `for all using (true)` pattern) so without this
/// guard a guardian who guessed an entry/subject id could pull
/// attachments belonging to another family's child. The viewer-side
/// check enforces the principle the other family providers establish.
typedef FamilyAttachmentsKey = ({
  String kind,
  String id,
  String subjectId,
});

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final familyAttachmentsForEntityProvider =
    FutureProvider.autoDispose.family<List<Attachment>, FamilyAttachmentsKey>(
  (ref, key) async {
    final viewer = ref.watch(viewerProvider);
    if (viewer is! GuardianViewer) return const <Attachment>[];
    if (!viewer.canSeeSubject(key.subjectId)) return const <Attachment>[];
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('attachments')
        .select()
        .eq('entity_kind', key.kind)
        .eq('entity_id', key.id)
        .order('sort_order', ascending: true, nullsFirst: false)
        .order('created_at', ascending: true);
    return [
      for (final r in rows) _attachmentFromMap(r),
    ];
  },
);

// ---------------------------------------------------------------------
// Converters — PostgREST snake_case → Drift model. Each one mirrors the
// table's Drift class field-for-field. `details` and `capabilities`
// arrive as decoded JSON (Map/List) from PostgREST; we re-encode to
// the JSON-string shape Drift stores locally so consumer code that
// reads `entry.details` as a JSON string keeps working.

Subject _subjectFromMap(Map<String, dynamic> r) => Subject(
      id: r['id'] as String,
      spaceId: r['space_id'] as String,
      groupId: r['group_id'] as String?,
      firstName: (r['first_name'] as String?) ?? '',
      lastName: (r['last_name'] as String?) ?? '',
      dob: r['dob'] as String?,
      photoUrl: r['photo_url'] as String?,
      allergies: r['allergies'] as String?,
      notes: r['notes'] as String?,
      capabilities: _jsonString(r['capabilities']),
      dropoffWindowStart: r['dropoff_window_start'] as String?,
      dropoffWindowEnd: r['dropoff_window_end'] as String?,
      pickupWindowStart: r['pickup_window_start'] as String?,
      pickupWindowEnd: r['pickup_window_end'] as String?,
      createdAt: r['created_at'] as String,
      updatedAt: r['updated_at'] as String,
    );

AttendanceRecord _attendanceFromMap(Map<String, dynamic> r) => AttendanceRecord(
      id: r['id'] as String,
      spaceId: r['space_id'] as String,
      groupId: r['group_id'] as String?,
      subjectId: r['subject_id'] as String,
      date: r['date'] as String,
      status: r['status'] as String,
      notes: r['notes'] as String?,
      recordedBy: r['recorded_by'] as String,
      recordedAt: r['recorded_at'] as String,
      updatedAt: r['updated_at'] as String,
    );

Entry _entryFromMap(Map<String, dynamic> r) => Entry(
      id: r['id'] as String,
      spaceId: r['space_id'] as String,
      groupId: r['group_id'] as String?,
      subjectId: r['subject_id'] as String?,
      kind: r['kind'] as String,
      // Drift `body` is mapped to the server column `text` via
      // `.named('text')`. PostgREST returns the server name.
      body: r['text'] as String?,
      photoUrl: r['photo_url'] as String?,
      details: _jsonString(r['details']),
      recordedBy: r['recorded_by'] as String,
      recordedAt: r['recorded_at'] as String,
      updatedAt: r['updated_at'] as String,
    );

Attachment _attachmentFromMap(Map<String, dynamic> r) => Attachment(
      id: r['id'] as String,
      spaceId: r['space_id'] as String,
      entityKind: r['entity_kind'] as String,
      entityId: r['entity_id'] as String,
      url: r['url'] as String,
      thumbUrl: r['thumb_url'] as String?,
      mimeType: (r['mime_type'] as String?) ?? 'image/jpeg',
      caption: r['caption'] as String?,
      sortOrder: r['sort_order'] as int?,
      uploadedBy: r['uploaded_by'] as String?,
      takenAt: r['taken_at'] as String?,
      createdAt: r['created_at'] as String,
      updatedAt: r['updated_at'] as String,
    );

String _jsonString(Object? raw) {
  if (raw == null) return '{}';
  if (raw is String) return raw;
  return jsonEncode(raw);
}
