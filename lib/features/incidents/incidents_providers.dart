import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

/// The kinds of incident an afterschool program logs. Stored as the
/// `incident_type` string in the entry's `details` JSON. Adding a type
/// is forward-compatible: an unknown stored value resolves to [other].
enum IncidentType {
  injury('injury', 'Injury / bump', Icons.healing_outlined),
  conflict('conflict', 'Conflict', Icons.sentiment_dissatisfied_outlined),
  behavior('behavior', 'Behavior', Icons.report_gmailerrorred_outlined),
  illness('illness', 'Illness', Icons.sick_outlined),
  medical('medical', 'Allergy / medical', Icons.medical_services_outlined),
  other('other', 'Other', Icons.more_horiz);

  const IncidentType(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;

  static IncidentType fromId(String? id) => values.firstWhere(
        (t) => t.id == id,
        orElse: () => IncidentType.other,
      );
}

/// A structured incident — a typed, parsed view over an `entries` row of
/// `kind='incident'`. The narrative lives in [Entry.body]; the structured
/// fields are parsed out of `details` JSON.
class Incident {
  const Incident({
    required this.entry,
    required this.type,
    required this.narrative,
    required this.actionTaken,
    required this.parentNotified,
    required this.familyNote,
  });

  factory Incident.fromEntry(Entry entry) {
    Map<String, dynamic> details;
    try {
      final decoded = jsonDecode(entry.details);
      details = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      details = <String, dynamic>{};
    }
    final note = (details['family_note'] as String?)?.trim();
    return Incident(
      entry: entry,
      type: IncidentType.fromId(details['incident_type'] as String?),
      narrative: (entry.body ?? '').trim(),
      actionTaken: (details['action_taken'] as String?)?.trim(),
      parentNotified: details['parent_notified'] == true,
      familyNote: (note == null || note.isEmpty) ? null : note,
    );
  }

  final Entry entry;
  final IncidentType type;

  /// The full internal narrative — STAFF-ONLY. Can name other children
  /// (a conflict), so it must never reach a family surface.
  final String narrative;
  final String? actionTaken;
  final bool parentNotified;

  /// The family-facing summary staff explicitly wrote — the only free
  /// text safe to show a guardian. Null when staff didn't write one.
  final String? familyNote;

  String get id => entry.id;
  String? get subjectId => entry.subjectId;
  String get recordedAt => entry.recordedAt;

  /// Whether this incident has been *surfaced* to the family — staff
  /// either notified them or wrote a family note. The family lens shows
  /// only surfaced incidents, so a just-logged internal one doesn't pop
  /// up before staff have processed it.
  bool get familyVisible => parentNotified || familyNote != null;
}

/// Every incident in the signed-in user's program, scoped to what the
/// viewer can see (director: all; teacher: only their assigned cohorts),
/// newest first. Same visibility shape as [observationsInSpaceProvider].
final incidentsInSpaceProvider = StreamProvider<List<Incident>>((ref) async* {
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
    kind: EntryKind.incident,
  );
  if (viewer.seesAllClassrooms || memberId == null) {
    yield* entries.map(_toIncidents);
    return;
  }
  final assignments = db.groupMembersDao.watchForMember(memberId);
  yield* Rx.combineLatest2<List<Entry>, List<GroupMember>, List<Incident>>(
    entries,
    assignments,
    (entryList, assigns) {
      final ids = assigns.map((a) => a.groupId).toSet();
      return _toIncidents(
        entryList
            .where((e) => e.groupId == null || ids.contains(e.groupId))
            .toList(growable: false),
      );
    },
  );
});

List<Incident> _toIncidents(List<Entry> entries) =>
    entries.map(Incident.fromEntry).toList(growable: false);

/// Incidents for a single child, newest first — drives the per-subject
/// safety history.
// ignore: specify_nonobvious_property_types
final incidentsForSubjectProvider =
    StreamProvider.autoDispose.family<List<Incident>, String>(
  (ref, subjectId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.entriesDao
        .watchForSubject(subjectId: subjectId, kind: EntryKind.incident)
        .map(_toIncidents);
  },
);

/// The canonical incident `details` JSON shape — `{incident_type,
/// action_taken?, parent_notified}`. Used by the "mark notified" amend;
/// `EntryActions.createIncident` builds the same shape at log time.
String incidentDetailsJson({
  required String incidentType,
  required bool parentNotified,
  String? actionTaken,
  String? familyNote,
}) {
  final details = <String, dynamic>{
    'incident_type': incidentType,
    if (actionTaken != null && actionTaken.trim().isNotEmpty)
      'action_taken': actionTaken.trim(),
    if (familyNote != null && familyNote.trim().isNotEmpty)
      'family_note': familyNote.trim(),
    'parent_notified': parentNotified,
  };
  return jsonEncode(details);
}

/// Amends logged incidents (currently just the family-notified flag).
class IncidentActions {
  IncidentActions(this._ref);

  final Ref _ref;

  /// Flip a logged incident's family-notified flag — for the common
  /// "log now, call the parent later" flow. Preserves the type +
  /// action narrative; only the flag changes. Optimistic local write.
  Future<void> setParentNotified(
    Incident incident, {
    required bool notified,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.updateDetails(
      id: incident.id,
      detailsJson: incidentDetailsJson(
        incidentType: incident.type.id,
        actionTaken: incident.actionTaken,
        familyNote: incident.familyNote,
        parentNotified: notified,
      ),
    );
  }
}

final incidentActionsProvider =
    Provider<IncidentActions>(IncidentActions.new);
