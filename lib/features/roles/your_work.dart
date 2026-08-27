import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter/material.dart';

/// What THIS person can do, derived from their capabilities.
///
/// The app hides on capability in ~55 places, so a person who lacks
/// something sees nothing at all — and silence is indistinguishable from
/// "that feature doesn't exist". A Kitchen Staff member and a Group Leader
/// open the same app and see two different products, with no way to tell
/// which parts are missing versus forbidden.
///
/// This is the one surface that answers it, and it is DERIVED rather than
/// authored: it reads the same getters the gates read, so it cannot drift
/// into promising something the app then refuses. A hand-written per-role
/// list would be wrong within a wave.
enum WorkKind {
  /// Yours to do, right now.
  can,

  /// Blocked, and YOU can unblock it — a certificate, a licence on file.
  /// Separated because it is a next step, not a wall.
  needsCert,

  /// Blocked by a decision somebody else makes. Names who to ask.
  needsSomeone,
}

class WorkItem {
  const WorkItem({
    required this.label,
    required this.kind,
    this.route,
    this.note,
  });

  final String label;
  final WorkKind kind;

  /// Where to go and do it. Null when blocked — offering a route into a
  /// screen that will refuse you is worse than offering none.
  final String? route;

  /// Why it is blocked. One short line.
  final String? note;

  bool get open => kind == WorkKind.can;
}

/// A titled cluster of work.
typedef WorkGroup = ({String title, List<WorkItem> items});

/// Build this viewer's work list.
///
/// Ordered by how often a person touches it, not by permission tier: the
/// things you do every shift come first and the administrative things you
/// do twice a term come last, whether or not you can do them.
List<WorkGroup> workFor(Viewer viewer, {String? primaryGroupId}) {
  final room = primaryGroupId;
  String? inRoom(String suffix) =>
      room == null ? null : '/groups/$room/$suffix';

  WorkItem gated({
    required bool allowed,
    required String label,
    String? route,
    String? blockedNote,
    WorkKind blockedKind = WorkKind.needsSomeone,
  }) => allowed
      ? WorkItem(label: label, kind: WorkKind.can, route: route)
      : WorkItem(label: label, kind: blockedKind, note: blockedNote);

  return [
    (
      title: 'Every day',
      items: [
        gated(
          allowed: viewer.canTakeAttendance,
          label: 'Take attendance',
          route: inRoom('attendance') ?? '/checklist',
          blockedNote: 'Ask whoever runs the program',
        ),
        gated(
          allowed: viewer.canObserve,
          label: 'Write an observation',
          route: '/captures/new',
          blockedNote: 'Ask whoever runs the program',
        ),
        gated(
          allowed: viewer.canRecordMeal,
          label: 'Record a meal',
          route: inRoom('attendance'),
          blockedNote: 'Ask whoever runs the program',
        ),
      ],
    ),
    (
      title: 'The room',
      items: [
        gated(
          allowed: viewer.canManageSchedule,
          label: 'Add and change blocks',
          route: '/schedule',
          blockedNote: 'Ask whoever runs the schedule',
        ),
        gated(
          allowed: viewer.canAuthorizePickup,
          label: 'Authorize a pickup',
          route: '/pickup',
          blockedNote: 'Belongs to whoever holds the room',
        ),
        gated(
          allowed: viewer.canOpenBuilding || viewer.canCloseBuilding,
          label: 'Open and close the building',
          route: '/runbook',
          blockedNote: 'Ask whoever runs the program',
        ),
      ],
    ),
    (
      title: 'The program',
      items: [
        gated(
          allowed: viewer.canManageStructure,
          label: 'Add rooms, places and vehicles',
          route: '/program',
          blockedNote: 'Ask whoever runs the program',
        ),
        gated(
          allowed: viewer.canManageStructure,
          label: 'Enrol a child',
          route: '/program',
          blockedNote: 'Ask whoever runs the program',
        ),
        gated(
          allowed: viewer.canInviteStaff,
          label: 'Invite a teammate',
          route: '/settings/team',
          blockedNote: 'Program managers only',
        ),
      ],
    ),
    (
      title: 'Needs a certificate',
      items: [
        // Cert-gated, so even a Program Manager ships FALSE. These are the
        // only blocks a person can clear THEMSELVES, which is why they get
        // their own heading instead of sitting among the "ask someone" rows
        // looking identical to a wall.
        gated(
          allowed: viewer.canAdministerMedication,
          label: 'Give medication',
          route: '/settings/team',
          blockedKind: WorkKind.needsCert,
          blockedNote: 'Add a certificate to your profile',
        ),
        gated(
          allowed: viewer.canDrive,
          label: 'Drive program vehicles',
          route: '/vehicles',
          blockedKind: WorkKind.needsCert,
          blockedNote: 'Add a licence to your profile',
        ),
      ],
    ),
  ];
}

/// The one line a person reads first — what they can do, and how much of
/// what they cannot is theirs to fix.
String workSummary(List<WorkGroup> groups) {
  final all = [for (final g in groups) ...g.items];
  final open = all.where((i) => i.open).length;
  final fixable = all.where((i) => i.kind == WorkKind.needsCert).length;
  if (fixable == 0) return '$open things you can do';
  return '$open things you can do · $fixable you could unlock';
}

IconData iconFor(WorkKind kind) => switch (kind) {
  WorkKind.can => Icons.check,
  WorkKind.needsCert => Icons.badge_outlined,
  WorkKind.needsSomeone => Icons.lock_outline,
};
