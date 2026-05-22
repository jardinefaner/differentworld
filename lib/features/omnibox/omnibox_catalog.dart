// The catalog builds a flat list with many `entries.add(...)` calls in
// a row — the lint wants cascade syntax there but readability beats
// `..add(...)` chains in this size. Silenced per file.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/widgets/quick_actions.dart'
    show startNewObservation;
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The flat list of every omnibox entry — static actions/pages PLUS
/// dynamic per-noun entries (kids, activities, locations, vehicles,
/// members). Recomputes when any source changes; cheap because no
/// expensive joins.
///
/// Capability-gated: entries the viewer can't access are filtered
/// out at the catalog layer, not at the results UI. Saves the user
/// from seeing "Permission denied" snackbars after tapping.
final omniboxCatalogProvider = Provider<List<OmniboxEntry>>((ref) {
  final viewer = ref.watch(viewerProvider);
  final labels = ref.watch(verticalLabelsProvider);
  final groups = ref.watch(groupsProvider).value ?? const <Group>[];
  final subjects =
      ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
  final activities =
      ref.watch(activitiesProvider).value ?? const <Activity>[];
  final locations =
      ref.watch(locationsProvider).value ?? const <Location>[];
  final vehicles =
      ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
  final members =
      ref.watch(membersInSpaceProvider).value ?? const <Member>[];

  // -- Static pages + actions -------------------------------------------
  final entries = <OmniboxEntry>[
    OmniboxEntry(
      id: 'page.today',
      label: 'Today',
      category: OmniboxCategory.page,
      icon: Icons.today_outlined,
      keywords: const ['home', 'dashboard', 'now'],
      contextTags: const ['morning', 'afternoon'],
      onSelect: (ctx, _) => ctx.go('/'),
    ),
    OmniboxEntry(
      id: 'page.schedule',
      label: 'Schedule',
      category: OmniboxCategory.page,
      icon: Icons.calendar_month_outlined,
      keywords: const [
        'schedule',
        'day',
        'block',
        'rotation',
        'agenda',
        'plan',
        'field trip',
        'trip',
      ],
      contextTags: const ['morning'],
      onSelect: (ctx, _) => ctx.push('/schedule'),
    ),
    OmniboxEntry(
      id: 'page.checklist',
      label: 'Morning checklist',
      category: OmniboxCategory.page,
      icon: Icons.task_alt,
      keywords: const ['attendance', 'check-in', 'morning', 'mark'],
      contextTags: const ['morning'],
      onSelect: (ctx, _) => ctx.push('/checklist'),
    ),
    OmniboxEntry(
      id: 'page.captures',
      label: 'Capture inbox',
      category: OmniboxCategory.page,
      icon: Icons.inbox_outlined,
      keywords: const ['triage', 'inbox', 'captures', 'notes'],
      onSelect: (ctx, _) => ctx.push('/captures'),
    ),
    OmniboxEntry(
      id: 'page.tasks',
      label: 'Tasks',
      category: OmniboxCategory.page,
      icon: Icons.check_circle_outline,
      keywords: const ['todo', 'to-do', 'reminder'],
      onSelect: (ctx, _) => ctx.push('/tasks'),
    ),
    OmniboxEntry(
      id: 'page.insights',
      label: 'Insights',
      category: OmniboxCategory.page,
      icon: Icons.lightbulb_outline,
      keywords: const [
        'patterns',
        'questions',
        'expiring',
        'late',
        'flagged',
      ],
      onSelect: (ctx, _) => ctx.push('/insights'),
    ),
    if (viewer.canObserve)
      OmniboxEntry(
        id: 'page.observations',
        label: 'Observations',
        category: OmniboxCategory.page,
        icon: Icons.menu_book_outlined,
        keywords: const ['notes', 'feed', 'all observations'],
        onSelect: (ctx, _) => ctx.push('/observations'),
      ),
    OmniboxEntry(
      id: 'page.surveys',
      label: 'Surveys',
      category: OmniboxCategory.page,
      icon: Icons.poll_outlined,
      keywords: const ['questionnaire', 'feedback', 'survey'],
      onSelect: (ctx, _) => ctx.push('/surveys'),
    ),
    OmniboxEntry(
      id: 'page.activities',
      label: 'Activities',
      category: OmniboxCategory.page,
      icon: Icons.local_activity_outlined,
      keywords: const [
        'activities',
        'catalog',
        'swimming',
        'archery',
        'art',
        'curriculum',
      ],
      onSelect: (ctx, _) => ctx.push('/activities'),
    ),
    OmniboxEntry(
      id: 'page.locations',
      label: 'Locations',
      category: OmniboxCategory.page,
      icon: Icons.place_outlined,
      keywords: const ['locations', 'pool', 'barn', 'range', 'where'],
      onSelect: (ctx, _) => ctx.push('/settings/locations'),
    ),
    if (viewer is GuardianViewer && viewer.childSubjectIds.isNotEmpty)
      OmniboxEntry(
        id: 'page.messages',
        label: 'Messages',
        category: OmniboxCategory.page,
        icon: Icons.forum_outlined,
        keywords: const ['message', 'chat', 'teacher', 'family'],
        onSelect: (ctx, _) => ctx.push('/messages'),
      ),
    OmniboxEntry(
      id: 'page.review.weekly',
      label: 'Weekly review',
      category: OmniboxCategory.page,
      icon: Icons.play_circle_outline,
      keywords: const ['walk', 'review', 'triage', 'one at a time'],
      contextTags: const ['sunday'],
      onSelect: (ctx, _) => ctx.push('/review'),
    ),
    OmniboxEntry(
      id: 'page.review.yearly',
      label: 'Yearly review',
      category: OmniboxCategory.page,
      icon: Icons.event_note_outlined,
      keywords: const ['year', 'annual', 'reflect', 'foundation'],
      onSelect: (ctx, _) => ctx.push('/review/year'),
    ),
    OmniboxEntry(
      id: 'page.team',
      label: 'Team',
      category: OmniboxCategory.setting,
      icon: Icons.groups_outlined,
      keywords: const ['staff', 'teachers', 'members'],
      onSelect: (ctx, _) => ctx.push('/settings/team'),
    ),
    OmniboxEntry(
      id: 'page.vehicles',
      label: 'Vehicles',
      category: OmniboxCategory.setting,
      icon: Icons.directions_bus_outlined,
      keywords: const ['fleet', 'van', 'bus', 'transport'],
      onSelect: (ctx, _) => ctx.push('/settings/vehicles'),
    ),
    OmniboxEntry(
      id: 'page.settings',
      label: 'Settings',
      category: OmniboxCategory.setting,
      icon: Icons.settings_outlined,
      keywords: const ['preferences', 'admin', 'config'],
      onSelect: (ctx, _) => ctx.push('/settings'),
    ),
    if (viewer.canManageSpace)
      OmniboxEntry(
        id: 'page.program',
        label: 'Program settings',
        category: OmniboxCategory.setting,
        icon: Icons.school_outlined,
        keywords: const ['program', 'space', 'features'],
        onSelect: (ctx, _) => ctx.push('/settings/program'),
      ),

    // -- Actions --------------------------------------------------------
    OmniboxEntry(
      id: 'action.capture',
      label: 'Capture a note',
      subtitle: 'Quick "I noticed…"',
      category: OmniboxCategory.action,
      icon: Icons.bolt_outlined,
      keywords: const ['note', 'jot', 'noticed', 'quick', 'thought'],
      onSelect: (ctx, _) => ctx.push('/captures/new'),
    ),
    // Same gate as the QuickActions tile — needs both `canObserve`
    // AND at least one visible group. Hide on runtime precondition
    // failure rather than letting the user tap into a snackbar.
    if (viewer.canObserve && groups.isNotEmpty)
      OmniboxEntry(
        id: 'action.observation.new',
        label: 'New ${labels.entry.toLowerCase()}',
        category: OmniboxCategory.action,
        icon: Icons.edit_note_outlined,
        keywords: const [
          'note',
          'log',
          'observe',
          'observation',
          'chart',
          'daily update',
        ],
        onSelect: (ctx, ref) {
          unawaited(startNewObservation(ctx, ref));
        },
      ),
    if (viewer.canManageSpace)
      OmniboxEntry(
        id: 'action.classroom.new',
        label: 'Add a ${labels.group.toLowerCase()}',
        category: OmniboxCategory.action,
        icon: Icons.add_business_outlined,
        // Keep keywords broad — these are SEARCH terms, not display
        // labels. A construction user might still type "classroom"
        // out of habit if they came from childcare; we don't want
        // omnibox to miss them.
        keywords: const ['new group', 'create room', 'classroom', 'crew'],
        onSelect: (ctx, _) {
          unawaited(ctx.push('/groups/new'));
        },
      ),
    if (viewer.canManageSpace)
      OmniboxEntry(
        id: 'action.vehicle.new',
        label: 'Add a vehicle',
        category: OmniboxCategory.action,
        icon: Icons.add_circle_outline,
        keywords: const ['new vehicle', 'fleet', 'van', 'bus'],
        onSelect: (ctx, _) {
          unawaited(ctx.push('/settings/vehicles/new'));
        },
      ),
    OmniboxEntry(
      id: 'action.activity.new',
      label: 'New activity',
      category: OmniboxCategory.action,
      icon: Icons.add_circle_outline,
      keywords: const ['new activity', 'add activity', 'create'],
      onSelect: (ctx, _) {
        unawaited(ctx.push('/activities/new'));
      },
    ),
    OmniboxEntry(
      id: 'action.invite',
      label: 'Invite a teammate',
      category: OmniboxCategory.action,
      icon: Icons.person_add_alt_1_outlined,
      keywords: const ['invite', 'add staff', 'add teacher', 'team'],
      onSelect: (ctx, _) => ctx.push('/settings/team'),
    ),
    OmniboxEntry(
      id: 'action.signout',
      label: 'Sign out',
      category: OmniboxCategory.action,
      icon: Icons.logout,
      keywords: const ['log out', 'logout'],
      onSelect: (ctx, ref) {
        unawaited(ref.read(authActionsProvider).signOut());
      },
    ),
  ];

  // -- Dynamic: classrooms ---------------------------------------------
  for (final g in groups) {
    entries.add(OmniboxEntry(
      id: 'classroom:${g.id}',
      label: g.name,
      subtitle: g.ageRange,
      category: OmniboxCategory.classroom,
      icon: Icons.meeting_room_outlined,
      keywords: const ['class', 'room', 'group', 'cohort'],
      groupId: 'classroom:${g.id}',
      onSelect: (ctx, _) => ctx.push('/groups/${g.id}'),
    ));
    if (viewer.canTakeAttendance) {
      entries.add(OmniboxEntry(
        id: 'classroom:${g.id}:attendance',
        label: 'Take attendance · ${g.name}',
        category: OmniboxCategory.action,
        icon: Icons.fact_check_outlined,
        keywords: const ['attendance', 'mark', 'present'],
        groupId: 'classroom:${g.id}',
        onSelect: (ctx, _) => ctx.push('/groups/${g.id}/attendance'),
      ));
    }
    if (viewer.canObserve) {
      entries.add(OmniboxEntry(
        id: 'classroom:${g.id}:observations',
        label: 'Observations · ${g.name}',
        category: OmniboxCategory.page,
        icon: Icons.menu_book_outlined,
        keywords: const ['notes', 'log', 'observation'],
        groupId: 'classroom:${g.id}',
        onSelect: (ctx, _) => ctx.push('/groups/${g.id}/observations'),
      ));
    }
    entries.add(OmniboxEntry(
      id: 'classroom:${g.id}:schedule',
      label: 'Schedule · ${g.name}',
      category: OmniboxCategory.page,
      icon: Icons.calendar_month_outlined,
      keywords: const ['day', 'block', 'rotation'],
      groupId: 'classroom:${g.id}',
      onSelect: (ctx, _) => ctx.push('/schedule'),
    ));
    if (viewer.canManageSpace) {
      entries.add(OmniboxEntry(
        id: 'classroom:${g.id}:student.new',
        label: 'Add a ${labels.subject.toLowerCase()} · ${g.name}',
        category: OmniboxCategory.action,
        icon: Icons.person_add_outlined,
        keywords: const [
          'new student',
          'new patient',
          'new project',
          'new guest',
          'enroll',
          'add kid',
          'add child',
        ],
        groupId: 'classroom:${g.id}',
        onSelect: (ctx, _) =>
            ctx.push('/groups/${g.id}/students/new'),
      ));
    }
  }

  // -- Dynamic: subjects (kids in childcare, patients in healthcare, etc.)
  for (final s in subjects) {
    final fullName = '${s.firstName} ${s.lastName}'.trim();
    final gid = s.groupId;
    entries.add(OmniboxEntry(
      id: 'subject:${s.id}',
      label: fullName,
      subtitle: 'Open profile',
      category: OmniboxCategory.person,
      icon: Icons.child_care_outlined,
      // Broad search terms so omnibox finds people regardless of
      // which vertical-noun the user types.
      keywords: const ['kid', 'child', 'student', 'patient', 'guest'],
      groupId: 'subject:${s.id}',
      onSelect: (ctx, _) {
        if (gid == null) return;
        unawaited(ctx.push('/groups/$gid/students/${s.id}'));
      },
    ));
    if (gid != null && viewer.canObserve) {
      entries.add(OmniboxEntry(
        id: 'subject:${s.id}:progress-report',
        label: 'Progress report · $fullName',
        category: OmniboxCategory.action,
        icon: Icons.description_outlined,
        keywords: const ['report', 'pdf', 'progress', 'parent'],
        groupId: 'subject:${s.id}',
        onSelect: (ctx, _) => ctx.push(
          '/groups/$gid/students/${s.id}/progress-report',
        ),
      ));
      entries.add(OmniboxEntry(
        id: 'subject:${s.id}:observation.new',
        label: 'Quick observation · $fullName',
        category: OmniboxCategory.action,
        icon: Icons.edit_note_outlined,
        keywords: const ['note', 'log', 'observe'],
        groupId: 'subject:${s.id}',
        onSelect: (ctx, _) {
          unawaited(
            ctx.push('/observations/new?groupId=$gid&subjectId=${s.id}'),
          );
        },
      ));
    }
  }

  // -- Dynamic: activities ---------------------------------------------
  for (final a in activities) {
    entries.add(OmniboxEntry(
      id: 'activity:${a.id}',
      label: a.name,
      subtitle: 'Edit activity',
      category: OmniboxCategory.activity,
      icon: Icons.local_activity_outlined,
      keywords: const ['activity'],
      groupId: 'activity:${a.id}',
      onSelect: (ctx, _) => ctx.push('/activities/${a.id}'),
    ));
  }

  // -- Dynamic: locations ----------------------------------------------
  for (final l in locations) {
    entries.add(OmniboxEntry(
      id: 'location:${l.id}',
      label: l.name,
      subtitle: 'Edit location',
      category: OmniboxCategory.place,
      icon: Icons.place_outlined,
      keywords: const ['location', 'place', 'room'],
      groupId: 'location:${l.id}',
      onSelect: (ctx, _) => ctx.push('/settings/locations'),
    ));
  }

  // -- Dynamic: vehicles -----------------------------------------------
  for (final v in vehicles) {
    entries.add(OmniboxEntry(
      id: 'vehicle:${v.id}',
      label: v.name,
      subtitle: v.licensePlate?.toUpperCase(),
      category: OmniboxCategory.vehicle,
      icon: Icons.directions_bus_outlined,
      keywords: const ['vehicle', 'fleet', 'van', 'bus'],
      groupId: 'vehicle:${v.id}',
      onSelect: (ctx, _) => ctx.push('/settings/vehicles/${v.id}'),
    ));
    if (viewer.canDrive) {
      entries.add(OmniboxEntry(
        id: 'vehicle:${v.id}:checkout',
        label: 'Check out · ${v.name}',
        category: OmniboxCategory.action,
        icon: Icons.key_outlined,
        keywords: const ['checkout', 'pre-trip', 'pretrip'],
        groupId: 'vehicle:${v.id}',
        onSelect: (ctx, _) =>
            ctx.push('/settings/vehicles/${v.id}/checkout'),
      ));
      entries.add(OmniboxEntry(
        id: 'vehicle:${v.id}:checkin',
        label: 'Check in · ${v.name}',
        category: OmniboxCategory.action,
        icon: Icons.assignment_turned_in_outlined,
        keywords: const ['checkin', 'post-trip', 'return'],
        groupId: 'vehicle:${v.id}',
        onSelect: (ctx, _) =>
            ctx.push('/settings/vehicles/${v.id}/checkin'),
      ));
    }
  }

  // -- Dynamic: members ------------------------------------------------
  for (final m in members) {
    entries.add(OmniboxEntry(
      id: 'member:${m.id}',
      label: m.displayName,
      subtitle: _roleLabel(m.role),
      category: OmniboxCategory.person,
      icon: Icons.person_outline,
      keywords: const ['teacher', 'staff', 'counselor', 'lead'],
      groupId: 'member:${m.id}',
      onSelect: (ctx, _) => ctx.push('/settings/team/${m.id}'),
    ));
  }

  return entries;
});

String _roleLabel(String? role) => RoleLabels.of(role);
