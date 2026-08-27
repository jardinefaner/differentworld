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
    this.journey,
    this.route,
    this.note,
  });

  final String label;
  final WorkKind kind;

  /// The JOURNEY — what is happening when a person needs this. Written as
  /// the moment, not the feature: "an adult arrives for a child", not
  /// "pickup management". A row that cannot describe its moment is a
  /// capability key wearing a button, and this list had two of those.
  final String? journey;

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

  // Returns null when the work has nowhere to happen — a person with no
  // room cannot "pick someone fairly", and showing it as available with a
  // dead tap is the exact failure this list exists to prevent. Blocked
  // items still render: knowing you are missing something is the point.
  WorkItem? gated({
    required bool allowed,
    required String label,
    required String journey,
    String? route,
    String? blockedNote,
    WorkKind blockedKind = WorkKind.needsSomeone,
  }) => allowed
      ? (route == null
            ? null
            : WorkItem(
                label: label,
                kind: WorkKind.can,
                journey: journey,
                route: route,
              ))
      : WorkItem(
          label: label,
          kind: blockedKind,
          journey: journey,
          note: blockedNote,
        );

  return [
    (
      title: 'Every day',
      items: <WorkItem>[
        ?gated(
          allowed: viewer.canTakeAttendance,
          label: 'Take attendance',
          journey: 'Your block is starting and you need the register',
          route: inRoom('attendance') ?? '/checklist',
          blockedNote: 'Ask whoever runs the program',
        ),
        ?gated(
          allowed: viewer.canObserve,
          label: 'Write an observation',
          journey: 'A child did something worth remembering',
          route: inRoom('observations') ?? '/observations',
          blockedNote: 'Ask whoever runs the program',
        ),
        // Deliberately routes to the capture form, not the inbox: this is
        // the "hands full, write it down now" moment, and landing on a
        // triage list would make you find the button yourself.
        ?gated(
          allowed: viewer.canObserve,
          label: 'Capture a moment',
          journey: 'No time to write it up properly — file it later',
          route: '/captures/new',
          blockedNote: 'Ask whoever runs the program',
        ),
      ],
    ),
    (
      title: 'Running the room',
      items: <WorkItem>[
        ?gated(
          allowed: viewer.canManageSchedule,
          label: 'Change the day',
          journey: 'It rained, or a session needs moving',
          route: '/schedule',
          blockedNote: 'Ask whoever runs the schedule',
        ),
        ?gated(
          allowed: true,
          label: 'Pick someone fairly',
          journey: 'You need one child and want it to be fair',
          route: inRoom('turns'),
        ),
        ?gated(
          allowed: viewer.canAuthorizePickup,
          label: 'Release a child',
          journey: 'An adult has arrived for someone',
          route: '/pickup',
          blockedNote: 'Belongs to whoever holds the room',
        ),
        ?gated(
          allowed: viewer.canOpenBuilding || viewer.canCloseBuilding,
          label: 'Open or close the building',
          journey: 'You are first in, or last out',
          route: '/runbook',
          blockedNote: 'Ask whoever runs the program',
        ),
      ],
    ),
    (
      title: 'Setting things up',
      items: <WorkItem>[
        // Three destinations, not one vague "/program" — you arrive at each
        // for a different reason and they are different screens.
        ?gated(
          allowed: viewer.canManageStructure,
          label: 'Add a room',
          journey: 'A new cohort needs somewhere to be',
          route: '/groups/new',
          blockedNote: 'Ask whoever runs the program',
        ),
        ?gated(
          allowed: viewer.canManageStructure,
          label: 'Add a place',
          journey: 'You discovered the back field is usable',
          route: '/settings/locations',
          blockedNote: 'Ask whoever runs the program',
        ),
        ?gated(
          allowed: viewer.canManageStructure,
          label: 'Enrol a child',
          journey: 'Somebody new started today',
          route: inRoom('students/new'),
          blockedNote: 'Ask whoever runs the program',
        ),
        ?gated(
          allowed: viewer.canInviteStaff,
          label: 'Invite a teammate',
          journey: 'Someone joined the staff',
          route: '/settings/team/invite/new',
          blockedNote: 'Program managers only',
        ),
      ],
    ),
    (
      title: 'Needs a licence',
      items: <WorkItem>[
        // canDrive is the ONLY cert-gated capability with a real feature
        // behind it. `canAdministerMedication` was here too and has been
        // removed: it has no route, no screen and no feature folder
        // anywhere in the app, so offering it was promising work the app
        // cannot do — which is worse than a wrong link.
        ?gated(
          allowed: viewer.canDrive,
          label: 'Drive program vehicles',
          journey: 'A field trip needs a driver',
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
