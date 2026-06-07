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
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/guardians/guardians_providers.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/widgets/substitute_lead_sheet.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/widgets/quick_actions.dart'
    show startNewObservation;
import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
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
  // Pending invites — only needed for director-side revoke actions.
  // We watch unconditionally because providers can't be conditional;
  // the per-entry guard on canInviteStaff handles the gating.
  final pendingInvites = viewer.spaceId == null
      ? const <Invite>[]
      : (ref.watch(pendingInvitesProvider(viewer.spaceId!)).value ??
          const <Invite>[]);

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
      id: 'page.pickup',
      label: 'Pickup board',
      category: OmniboxCategory.page,
      icon: Icons.directions_walk,
      keywords: const [
        'pickup',
        'pick up',
        'dismissal',
        'release',
        'checkout',
        'check-out',
        'go home',
        'sign out',
      ],
      contextTags: const ['afternoon', 'evening'],
      onSelect: (ctx, _) => ctx.push('/pickup'),
    ),
    OmniboxEntry(
      id: 'page.action-words',
      label: 'Action Words',
      category: OmniboxCategory.page,
      icon: Icons.auto_awesome_outlined,
      keywords: const [
        'verbs',
        'words',
        'worlds',
        'pick',
        'action words',
        'reveal',
        'collection',
        'animal',
      ],
      contextTags: const ['morning'],
      onSelect: (ctx, _) => ctx.push('/action-words'),
    ),
    OmniboxEntry(
      id: 'page.mission-board',
      label: 'Today’s board',
      category: OmniboxCategory.page,
      icon: Icons.dashboard_customize_outlined,
      keywords: const [
        'board',
        'do board',
        'tasks',
        'tasks zero',
        'jobs',
        'missions board',
        'big buttons',
      ],
      onSelect: (ctx, _) => ctx.push('/missions/board'),
    ),
    // Incident log — gated on the program feature + a staff who can log
    // or manage (the screen NoAccess-gates the same way, so we don't
    // surface a dead destination).
    if (viewer.featureIncidentReports &&
        (viewer.canObserve || viewer.canManageSpace)) ...[
      OmniboxEntry(
        id: 'page.incidents',
        label: 'Incident log',
        category: OmniboxCategory.page,
        icon: Icons.report_gmailerrorred_outlined,
        keywords: const [
          'incident',
          'injury',
          'accident',
          'report',
          'safety',
          'bump',
          'conflict',
        ],
        onSelect: (ctx, _) => ctx.push('/incidents'),
      ),
      if (viewer.canObserve)
        OmniboxEntry(
          id: 'action.log-incident',
          label: 'Log an incident',
          category: OmniboxCategory.action,
          icon: Icons.add_alert_outlined,
          keywords: const [
            'new incident',
            'report incident',
            'injury',
            'accident',
            'log',
          ],
          onSelect: (ctx, _) => ctx.push('/incidents/new'),
        ),
    ],
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
    OmniboxEntry(
      id: 'page.supplies',
      label: 'Supplies',
      category: OmniboxCategory.page,
      icon: Icons.inventory_2_outlined,
      keywords: const [
        'supplies',
        'inventory',
        'materials',
        'stock',
        'markers',
        'paper',
      ],
      onSelect: (ctx, _) => ctx.push('/settings/supplies'),
    ),
    OmniboxEntry(
      id: 'page.missions',
      label: 'Missions',
      category: OmniboxCategory.page,
      icon: Icons.flag_outlined,
      keywords: const [
        'missions',
        'jobs',
        'helpers',
        'chores',
        'responsibilities',
        'equipment manager',
        'snack helper',
      ],
      onSelect: (ctx, _) => ctx.push('/settings/missions'),
    ),
    OmniboxEntry(
      id: 'page.board',
      label: 'Brainstorm Board',
      category: OmniboxCategory.page,
      icon: Icons.tv,
      keywords: const [
        'board',
        'brainstorm',
        'meeting',
        'agenda',
        'ideas',
        'anonymous',
      ],
      onSelect: (ctx, _) => ctx.push('/board'),
    ),
    // The Thinking Tools library (docs/THINKING_TOOLS.md) — one shelf over the
    // runnable activities + the editorial reference cards.
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'page.tools',
        label: 'Tools',
        category: OmniboxCategory.page,
        icon: Icons.psychology_outlined,
        keywords: const [
          'tools',
          'thinking tools',
          'thinking',
          'toolkit',
          'activities',
          'run with the room',
          'discussion',
          'frameworks',
          'mental models',
        ],
        onSelect: (ctx, _) => ctx.push('/tools'),
      ),
    // Speak — paste a prompt / quote / block, hear it read aloud with big
    // kinetic karaoke subtitles (ElevenLabs). Staff-facing creative tool.
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'page.speak',
        label: 'Speak',
        category: OmniboxCategory.page,
        icon: Icons.graphic_eq,
        keywords: const [
          'speak',
          'read aloud',
          'read it',
          'karaoke',
          'subtitles',
          'captions',
          'lyrics',
          'text to speech',
          'voice',
          'narrate',
          'prompt',
          'quote',
        ],
        onSelect: (ctx, _) => ctx.push('/speak'),
      ),
    // The classroom remote (docs/VISION.md #18) — present a surface on the
    // big screen, drive it from the phone. Staff-only (guardians can't drive
    // the room). Broad keywords surface each by what teachers call the thing.
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'page.present',
        label: 'Present to the room',
        category: OmniboxCategory.page,
        icon: Icons.co_present_outlined,
        keywords: const [
          'present',
          'cast',
          'big screen',
          'projector',
          'room',
          'remote',
          'classroom remote',
          'tv',
        ],
        onSelect: (ctx, _) => ctx.push('/present'),
      ),
    // The app remote (docs/LIVE_SESSIONS.md "the cast model"): make a screen a
    // clean display + drive everything from the phone — pick + switch + control.
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'page.cast',
        label: 'Cast to a screen',
        category: OmniboxCategory.page,
        icon: Icons.cast,
        keywords: const [
          'cast',
          'remote',
          'control',
          'screen',
          'projector',
          'tv',
          'present from phone',
          'phone remote',
        ],
        onSelect: (ctx, _) => ctx.push('/cast'),
      ),
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'present.now-next',
        label: 'Now & Next board',
        category: OmniboxCategory.page,
        icon: Icons.calendar_view_day_outlined,
        keywords: const [
          'now and next',
          'now next',
          'schedule board',
          "what's next",
          'agenda board',
          'present schedule',
        ],
        onSelect: (ctx, _) => ctx.push('/present/now-next'),
      ),
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'present.poll',
        label: 'Quick Poll',
        category: OmniboxCategory.page,
        icon: Icons.how_to_vote_outlined,
        keywords: const [
          'poll',
          'vote',
          'decide',
          'choose',
          'survey the room',
        ],
        onSelect: (ctx, _) => ctx.push('/present/poll'),
      ),
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'present.spotlight',
        label: 'Spotlight — random picker',
        category: OmniboxCategory.page,
        icon: Icons.star_outline,
        keywords: const [
          'spotlight',
          'random',
          'picker',
          'pick a name',
          'fair turns',
          'whose turn',
          'spin',
        ],
        onSelect: (ctx, _) => ctx.push('/present/picker'),
      ),
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'present.signals',
        label: 'Signals — room cues',
        category: OmniboxCategory.page,
        icon: Icons.campaign_outlined,
        keywords: const [
          'signals',
          'cue',
          'attention',
          'eyes up',
          'clean up',
          'quiet',
          'line up',
          'breathe',
          'freeze',
          'transition',
        ],
        onSelect: (ctx, _) => ctx.push('/present/cues'),
      ),
    // The Poster tool — tile one image across N×N letter pages and print
    // big to tape together. Staff-facing maker utility. Broad keywords so
    // it surfaces by whatever the user calls it.
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'page.poster',
        label: 'Poster — print big',
        category: OmniboxCategory.page,
        icon: Icons.grid_view_rounded,
        keywords: const [
          'poster',
          'print big',
          'blow up',
          'enlarge',
          'banner',
          'big print',
          'large print',
          'tile',
          'engineer print',
          'wall art',
          'welcome sign',
          'sign',
        ],
        onSelect: (ctx, _) => ctx.push('/poster'),
      ),
    // Toolkit landing page — broad keywords surface the catalog
    // itself when the user wants to browse rather than jump to a
    // specific tool. Gated by viewer kind: guardians can't reach
    // /settings/toolkit (router redirects them home), so omitting
    // the entry for them avoids a silent bounce-back.
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'page.toolkit',
        label: 'Teacher Toolkit',
        category: OmniboxCategory.setting,
        icon: Icons.menu_book_outlined,
        keywords: const [
          'toolkit',
          'tools',
          'scripts',
          'phrases',
          'teaching moves',
          'in the moment',
        ],
        onSelect: (ctx, _) => ctx.push('/settings/toolkit'),
      ),
    // Through My Eyes photo curriculum — landing entry. Subject-
    // matter keywords (photo, camera, gallery) help directors and
    // counselors who think of it by the activity rather than the
    // catalog name.
    if (viewer is! GuardianViewer)
      OmniboxEntry(
        id: 'page.curriculum.photo',
        label: 'Through My Eyes',
        subtitle: 'Photo curriculum · 3 weeks, 6 sessions',
        category: OmniboxCategory.setting,
        icon: Icons.photo_camera_outlined,
        keywords: const [
          'through my eyes',
          'photo curriculum',
          'photography',
          'camera',
          'photo program',
          'gallery',
          'six games',
        ],
        onSelect: (ctx, _) => ctx.push('/settings/curricula/photo'),
      ),
    // Per-tool entries — typing "cool down" or "meltdown" should
    // land directly on the Cool Down detail screen, not on the
    // catalog top. Crisis-retrieval target is 1 tap from anywhere
    // in the app. Auto-generated from the catalog so Wave 162
    // overrides slot in for free.
    if (viewer is! GuardianViewer)
      for (final tool in allToolkitTools)
        OmniboxEntry(
          id: 'toolkit.tool.${tool.slug}',
          label: tool.name,
          subtitle: 'Toolkit · ${categoryById(tool.categoryId).name}',
          category: OmniboxCategory.setting,
          icon: Icons.bolt_outlined,
          keywords: [
            tool.name.toLowerCase(),
            // Strip leading "The " when present so a search for
            // "Cool Down" doesn't only match "The Cool Down".
            if (tool.name.toLowerCase().startsWith('the '))
              tool.name.toLowerCase().substring(4),
            // Surface category + situation keywords.
            categoryById(tool.categoryId).name.toLowerCase(),
            ...tool.when.toLowerCase().split(' ').where((w) => w.length > 3),
          ],
          onSelect: (ctx, _) =>
              ctx.push('/settings/toolkit/${tool.slug}'),
        ),
    OmniboxEntry(
      id: 'page.roles',
      label: 'Roles & permissions',
      category: OmniboxCategory.setting,
      icon: Icons.shield_outlined,
      keywords: const [
        'roles',
        'permissions',
        'who can do what',
        'caps',
        'capability',
      ],
      onSelect: (ctx, _) => ctx.push('/settings/roles'),
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
      onSelect: (ctx, _) => ctx.push('/vehicles'),
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
          unawaited(ctx.push('/vehicles/new'));
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
    // Staff invite — directors only. Lands directly on the create
    // form (not the team list) so the user is one tap from the form
    // they came to fill. Hidden for non-directors per the "if you
    // can't do it, don't show it" rule.
    if (viewer.canInviteStaff)
      OmniboxEntry(
        id: 'action.invite.staff',
        label: 'Invite a teammate',
        category: OmniboxCategory.action,
        icon: Icons.person_add_alt_1_outlined,
        keywords: const [
          'invite', 'add staff', 'add teacher', 'add counselor',
          'add specialist', 'add substitute', 'team', 'hire',
        ],
        onSelect: (ctx, _) => ctx.push('/settings/team/invite/new'),
      ),
    // My profile — direct path for the signed-in staff member to
    // their own detail screen. Most-asked-for from the omnibox path
    // since cert / role / photo edits all live there. Guardians
    // don't have a member detail surface (they edit themselves via
    // the family lens preferences); hide the entry for them.
    if (viewer is! GuardianViewer && viewer.memberId != null)
      OmniboxEntry(
        id: 'action.profile.self',
        label: 'My profile',
        category: OmniboxCategory.action,
        icon: Icons.account_circle_outlined,
        keywords: const [
          'me', 'profile', 'account', 'my account', 'cert',
          'certification', 'photo', 'avatar',
        ],
        onSelect: (ctx, _) =>
            ctx.push('/settings/team/${viewer.memberId}'),
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
    // Pat persona — one-tap "X is out today, Y is covering." Opens the
    // substitute-lead sheet directly without first navigating into the
    // schedule editor (the persona-audit recommendation, 2026-05-22).
    // Gated by canManageSchedule because the sheet writes
    // lead_substitute_member_id, same write the editor uses.
    if (viewer.canManageSchedule) {
      entries.add(OmniboxEntry(
        id: 'classroom:${g.id}:cover',
        label: 'Cover today · ${g.name}',
        category: OmniboxCategory.action,
        icon: Icons.person_add_alt_1,
        keywords: const [
          'cover',
          'substitute',
          'sub',
          'absent',
          'out today',
          'lead out',
          'callout',
        ],
        groupId: 'classroom:${g.id}',
        onSelect: (ctx, _) => unawaited(SubstituteLeadSheet.show(
          ctx,
          groupId: g.id,
          groupName: g.name,
          date: _todayIsoLocal(),
        )),
      ));
    }
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
  //
  // Subjects without a `groupId` can't navigate anywhere — the profile
  // route is nested under the cohort (`/groups/:gid/students/:sid`).
  // Per the "if the user isn't able to do it, do not show it" rule
  // (2026-05-22), we drop those entries entirely instead of showing
  // them with a silent-noop tap.
  for (final s in subjects) {
    final gid = s.groupId;
    if (gid == null) continue;
    final fullName = '${s.firstName} ${s.lastName}'.trim();
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
      onSelect: (ctx, _) =>
          unawaited(ctx.push('/groups/$gid/students/${s.id}')),
    ));
    // `gid` is guaranteed non-null here (we `continue`d above).
    if (viewer.canObserve) {
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
    // Invite a parent — per-subject action surfaced for directors so
    // they can mint a guardian invite for a specific kid without
    // drilling into the kid's profile first. Routes to the subject
    // edit screen where the inline Guardians editor lives (the
    // existing `_handleAddGuardian` flow runs from there). Gated on
    // canManageSpace because creating a guardians row + minting an
    // invite is a director action.
    if (viewer.canManageSpace) {
      entries.add(OmniboxEntry(
        id: 'subject:${s.id}:invite.parent',
        label: 'Invite a parent · $fullName',
        category: OmniboxCategory.action,
        icon: Icons.family_restroom_outlined,
        keywords: const [
          'parent', 'family', 'mom', 'dad', 'guardian', 'invite',
          'invite parent', 'invite family',
        ],
        groupId: 'subject:${s.id}',
        onSelect: (ctx, _) =>
            ctx.push('/groups/$gid/students/${s.id}/edit'),
      ));
    }
    // Messages — staff path to the per-child thread. Wave 100: the
    // entry used to push subject-detail and let the user find the
    // guardian, but the label promised a thread; users would tap
    // expecting a thread and land on a profile. Now: at tap time
    // we read `guardiansForSubjectProvider`; if there's exactly one
    // guardian, push the thread URL directly; if there are 0 or 2+,
    // fall back to subject-detail (it lists every guardian) and
    // surface a snackbar so the user knows why. Gated on canObserve
    // because anyone who logs observations may need to ping family.
    if (viewer.canObserve) {
      entries.add(OmniboxEntry(
        id: 'subject:${s.id}:messages',
        label: 'Messages · $fullName',
        category: OmniboxCategory.action,
        icon: Icons.forum_outlined,
        keywords: const [
          'message', 'messages', 'chat', 'family', 'parent', 'mom',
          'dad', 'guardian',
        ],
        groupId: 'subject:${s.id}',
        onSelect: (ctx, ref) async {
          final guardians =
              await ref.read(guardiansForSubjectProvider(s.id).future);
          if (!ctx.mounted) return;
          if (guardians.length == 1) {
            unawaited(
              ctx.push('/messages/${s.id}/${guardians.first.id}'),
            );
            return;
          }
          // 0 guardians: subject-detail is where the user adds one.
          // 2+ guardians: subject-detail lists them and the user
          // picks the thread.
          unawaited(ctx.push('/groups/$gid/students/${s.id}'));
          if (guardians.isEmpty) {
            ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
              const SnackBar(
                content: Text(
                  'No guardians linked yet — add one to start messaging.',
                ),
              ),
            );
          }
        },
      ));
    }
    // Mark absent today — single-tap chore for the most common
    // attendance write. Today this requires opening the attendance
    // screen for the cohort + finding the kid + tapping Absent;
    // floor staff often know about a callout 30 seconds before
    // they can free a hand. Tap → fires the upsert + snackbar.
    // Not destructive — director / staff can flip it back from the
    // attendance screen.
    if (viewer.canTakeAttendance) {
      entries.add(OmniboxEntry(
        id: 'subject:${s.id}:attendance.absent',
        label: 'Mark absent today · $fullName',
        category: OmniboxCategory.action,
        icon: Icons.event_busy_outlined,
        keywords: const [
          'absent', 'absence', 'out', 'callout', 'sick', 'not here',
          'missing', 'check in',
        ],
        groupId: 'subject:${s.id}',
        onSelect: (ctx, ref) async {
          try {
            await ref.read(attendanceActionsProvider).setStatus(
                  groupId: gid,
                  subjectId: s.id,
                  date: _todayIsoLocal(),
                  status: AttendanceStatus.absent,
                );
            if (!ctx.mounted) return;
            ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
              SnackBar(
                content: Text('$fullName marked absent.'),
                action: SnackBarAction(
                  label: 'Open attendance',
                  onPressed: () =>
                      ctx.push('/groups/$gid/attendance'),
                ),
              ),
            );
          } on Exception catch (e, st) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: e,
                stack: st,
                library: 'attendance',
              ),
            );
            if (!ctx.mounted) return;
            ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
              const SnackBar(
                content: Text('Could not mark absent. Try again.'),
              ),
            );
          }
        },
      ));
    }
  }

  // -- Dynamic: pending invites (director admin) ------------------------
  // Per-pending-invite "Revoke" actions. Directors live in the team
  // screen for this today; the omnibox shortens it to one keyword.
  // Gated on canInviteStaff (same cap that controls who can create
  // invites). Destructive-confirm before the revoke fires.
  if (viewer.canInviteStaff) {
    for (final inv in pendingInvites) {
      final label = _inviteShortLabel(inv);
      entries.add(OmniboxEntry(
        id: 'invite:${inv.id}:revoke',
        label: 'Revoke pending invite · $label',
        category: OmniboxCategory.action,
        icon: Icons.cancel_outlined,
        keywords: const [
          'revoke', 'cancel', 'pending', 'invite', 'remove',
        ],
        onSelect: (ctx, ref) async {
          final ok = await confirmDestructive(
            ctx,
            title: 'Revoke this invite?',
            message:
                'The code stops working immediately. The recipient '
                "won't be able to join with it.",
            confirmLabel: 'Revoke',
          );
          if (!ok || !ctx.mounted) return;
          await ref.read(inviteActionsProvider).revoke(inv.id);
          if (!ctx.mounted) return;
          ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
            SnackBar(content: Text('Revoked invite for $label.')),
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
      onSelect: (ctx, _) => ctx.push('/vehicles/${v.id}'),
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
            ctx.push('/vehicles/${v.id}/checkout'),
      ));
      entries.add(OmniboxEntry(
        id: 'vehicle:${v.id}:checkin',
        label: 'Check in · ${v.name}',
        category: OmniboxCategory.action,
        icon: Icons.assignment_turned_in_outlined,
        keywords: const ['checkin', 'post-trip', 'return'],
        groupId: 'vehicle:${v.id}',
        onSelect: (ctx, _) =>
            ctx.push('/vehicles/${v.id}/checkin'),
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

/// Today's date as `YYYY-MM-DD` in the device's local zone. The
/// schedule DAO expects this exact shape — it indexes blocks by the
/// `date` column (date type) without any zone conversion.
String _todayIsoLocal() => todayKey();

/// Short human label for an invite — used in the omnibox revoke
/// entry so a director can tell two pending invites apart at a
/// glance. Preference: email (most specific) → role-by-shortcode
/// fallback. Email may be null; code is always present.
String _inviteShortLabel(Invite inv) {
  final email = inv.email;
  if (email != null && email.isNotEmpty) return email;
  return '${inv.role} · ${inv.code ?? "(no code)"}';
}
