import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/groups/room_skins.dart';
import 'package:differentworld/features/photos/photo_consent_providers.dart';
import 'package:differentworld/features/rooms/room_load_providers.dart';
import 'package:differentworld/features/schedule/block_edit_screen.dart'
    show BlockEditArgs;
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/inline_add.dart';
import 'package:differentworld/shared/widgets/inline_editable_text.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/person_face_wrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// One room, one page (docs/ROOM_SETUP.md).
///
/// Setting up a single classroom used to mean seven screens across four
/// feature folders, reached from three different places in the nav: name it
/// in `/groups/new`, staff it in `/team`, fill it in `students/new`, build
/// the activity catalogue in `/settings/activities`, shape a day in
/// `/schedule/day-templates`, place blocks in `/schedule/block`, repeat it
/// in `/schedule/template`. Nobody holds that map in their head.
///
/// The bands here are in the order the work actually happens, and each one
/// shows STATE rather than a link onward — you see fourteen faces, not
/// "Manage children". Adding happens in place via [InlineAdd]; nothing on
/// this page navigates away to add one more of something.
///
/// **Configure, not operate.** Attendance, Pick Me and observations are
/// things you do DURING a shift and they live on Today, which already leads
/// by the clock. Mixing them into the room screen is what produced a
/// six-item overflow menu sitting next to "edit the room's name".
///
/// **The time band edits the recurring shape, not today.** Editing a live
/// day from a setup page is how you cancel a session that is running.
class RoomSetupScreen extends ConsumerWidget {
  const RoomSetupScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = (ref.watch(groupsProvider).value ?? const <Group>[])
        .where((g) => g.id == groupId)
        .firstOrNull;

    return EdgeScaffold(
      backFallbackRoute: '/program',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: group == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
                    children: [
                      _RoomHeader(group: group),
                      const SizedBox(height: 16),
                      _Instruments(groupId: group.id),
                      const SizedBox(height: 20),
                      _ChildrenBand(group: group),
                      const SizedBox(height: 22),
                      _StaffBand(group: group),
                      const SizedBox(height: 22),
                      _TimeBand(group: group),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The daily verbs, on the room, visible.
///
/// These used to live behind a `⋯` holding seven items, which is where a
/// feature goes to not be found — and two identical overflow menus on one
/// screen is worse than the buttons they replaced. They cause things
/// (take a register, pick a child, write something down), so they are
/// pressable shapes rather than links.
class _Instruments extends ConsumerWidget {
  const _Instruments({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final items = <({IconData icon, String label, String route})>[
      if (viewer.canTakeAttendance)
        (
          icon: Icons.fact_check_outlined,
          label: 'Attendance',
          route: '/groups/$groupId/attendance',
        ),
      if (viewer.canObserve)
        (
          icon: Icons.visibility_outlined,
          label: 'Observations',
          route: '/groups/$groupId/observations',
        ),
      (
        icon: Icons.touch_app_outlined,
        label: 'Pick me',
        route: '/groups/$groupId/turns',
      ),
      (
        icon: Icons.groups_2_outlined,
        label: 'Make groups',
        route: '/groups/$groupId/arrange',
      ),
      (
        icon: Icons.record_voice_over_outlined,
        label: 'Talk time',
        route: '/groups/$groupId/talk',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in items)
            ActionChip(
              key: ValueKey('instrument-${i.route}'),
              avatar: Icon(i.icon, size: 18),
              label: Text(i.label),
              onPressed: () => unawaited(context.push(i.route)),
            ),
        ],
      ),
    );
  }
}

/// The room's own identity, in its own skin — a room should read as a place
/// before it reads as a record.
class _RoomHeader extends ConsumerWidget {
  const _RoomHeader({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final skin = roomSkinForGroup(group);
    final ageBand = group.caps.getString(GroupCaps.ageBand);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (skin != null)
            Text(
              skin.name,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 2),
          // UPDATE happens where the thing is DISPLAYED. Renaming a room is
          // one field, so sending someone to a form for it is the same
          // mistake create was making. The deeper settings keep their form
          // below, because they genuinely are one.
          InlineEditableText(
            value: group.name,
            placeholder: 'Name this room',
            style: theme.textTheme.headlineSmall,
            editable: ref.watch(viewerProvider).canManageSpace,
            onCommit: (next) async {
              final db = await ref.read(appDatabaseProvider.future);
              await db.groupsDao.update_(id: group.id, name: next);
            },
          ),
          if (ageBand != null && ageBand.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              ageBand,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  unawaited(context.push('/groups/${group.id}/edit')),
              icon: const Icon(Icons.tune_outlined, size: 18),
              // DELETE is deliberately not offered here. A room holds
              // children, so the verb that belongs in reach is CLOSE —
              // reversible, keeps every record — and it lives with the
              // other settings rather than one tap from the roster.
              label: const Text('Age range, limits, closing'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled band with the Calm left edge. Local rather than shared because
/// the heading carries a live right-hand status line, which no existing
/// primitive does.
class _Band extends StatelessWidget {
  const _Band({
    required this.title,
    required this.status,
    required this.child,
    this.statusColor,
  });

  final String title;
  final String status;
  final Color? statusColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
          ),
        ),
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor ?? theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChildrenBand extends ConsumerWidget {
  const _ChildrenBand({required this.group});

  final Group group;

  Future<void> _add(WidgetRef ref, String value) async {
    final spaceId = ref.read(viewerProvider).spaceId;
    if (spaceId == null) return;
    // One field, not a form: a first name is enough to exist. Everything
    // else about a child can be filled in later from their own page, and
    // demanding it up front is what makes adding fourteen children a chore
    // people put off until the data is stale.
    final parts = value.split(RegExp(r'\s+'));
    final db = await ref.read(appDatabaseProvider.future);
    await db.subjectsDao.create(
      id: const Uuid().v4(),
      spaceId: spaceId,
      groupId: group.id,
      firstName: parts.first,
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster =
        ref.watch(subjectsInGroupProvider(group.id)).value ?? const <Subject>[];
    final defaultAllows = ref.watch(spaceDefaultAllowsPhotosProvider);

    return _Band(
      title: 'Who’s in it',
      status: roster.length == 1 ? '1 child' : '${roster.length} children',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (roster.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Nobody yet. Type a name and press enter — you can add the '
                'rest of their details any time.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            PersonFaceWrap(
              radius: 18,
              // No overflow cap on the room's own page: "+9" is right on an
              // instrument, where the point is a glance, and wrong here,
              // where the point is the whole class.
              max: 200,
              people: [
                for (final s in roster)
                  FacePerson(
                    name: '${s.firstName} ${s.lastName}'.trim(),
                    photoUrl: consentedPhotoUrl(
                      s,
                      defaultAllows: defaultAllows,
                    ),
                    onTap: () => unawaited(
                      context.push('/groups/${group.id}/students/${s.id}'),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              InlineAdd(
                hint: 'Add a child',
                onSubmit: (v) => _add(ref, v),
              ),
              if (roster.length > 8) ...[
                const SizedBox(width: 8),
                // Search earns its place only once the faces stop being
                // scannable. Below that it is a control nobody needs, sitting
                // where a control you DO need could be.
                TextButton.icon(
                  onPressed: () => unawaited(
                    context.push('/groups/${group.id}/roster'),
                  ),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffBand extends ConsumerWidget {
  const _StaffBand({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assigned =
        ref.watch(staffOnGroupProvider(group.id)).value ?? const [];
    final load = ref.watch(roomLoadProvider(group.id));
    final short = load.understaffed;

    return _Band(
      title: 'Who’s on it',
      status: short
          ? 'needs ${load.staffShort} more'
          : assigned.length == 1
          ? '1 adult'
          : '${assigned.length} adults',
      statusColor: short ? theme.colorScheme.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssignedStaff(groupId: group.id, assigned: assigned),
          // The ratio warning belongs HERE, beside the people who fix it —
          // not on a separate compliance screen you visit after the fact.
          if (short) ...[
            const SizedBox(height: 8),
            Text(
              '${load.childrenPresent} children at '
              '1:${load.ratioChildrenPerAdult} needs ${load.staffRequired} '
              'adults.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _AssignAdult(groupId: group.id, assigned: assigned),
        ],
      ),
    );
  }
}

/// Assigning an adult is TAPPING one, not visiting the team screen.
///
/// The people already exist — the whole job is "put that person on this
/// room", and routing to /team to do it is what made room setup a tour of
/// the app. Everyone not already on the room shows as a tappable chip; tap
/// and they are on it.
class _AssignAdult extends ConsumerStatefulWidget {
  const _AssignAdult({required this.groupId, required this.assigned});

  final String groupId;
  final List<GroupMember> assigned;

  @override
  ConsumerState<_AssignAdult> createState() => _AssignAdultState();
}

class _AssignAdultState extends ConsumerState<_AssignAdult> {
  bool _open = false;

  Future<void> _assign(Member m) async {
    final spaceId = ref.read(viewerProvider).spaceId;
    if (spaceId == null) return;
    final db = await ref.read(appDatabaseProvider.future);
    await db.groupMembersDao.assign(
      groupId: widget.groupId,
      memberId: m.id,
      spaceId: spaceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onRoom = {for (final g in widget.assigned) g.memberId};
    final available = [
      for (final m
          in ref.watch(membersInSpaceProvider).value ?? const <Member>[])
        if (!onRoom.contains(m.id)) m,
    ];

    if (!_open) {
      return TextButton.icon(
        onPressed: () => setState(() => _open = true),
        icon: const Icon(Icons.person_add_outlined, size: 18),
        label: const Text('Assign an adult'),
      );
    }
    if (available.isEmpty) {
      return Text(
        'Everyone on the team is already on this room.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // An instruction that exists only while it is NEWS — it appears
        // when you open the picker and goes when you close it, rather than
        // living on the screen forever as a sign on a wall.
        Text(
          'Tap whoever is on this room.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in available)
              ActionChip(
                key: ValueKey('assign-${m.id}'),
                avatar: PersonAvatar(
                  name: m.displayName,
                  photoUrl: m.avatarUrl,
                  radius: 12,
                ),
                label: Text(m.displayName),
                onPressed: () => unawaited(_assign(m)),
              ),
            ActionChip(
              key: const ValueKey('assign-done'),
              label: const Text('Done'),
              onPressed: () => setState(() => _open = false),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssignedStaff extends ConsumerWidget {
  const _AssignedStaff({required this.groupId, required this.assigned});

  final String groupId;
  final List<GroupMember> assigned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (assigned.isEmpty) {
      return Text(
        'No adult assigned yet.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final members = ref.watch(membersInSpaceProvider).value ?? const <Member>[];
    final byId = {for (final m in members) m.id: m};
    return PersonFaceWrap(
      radius: 18,
      people: [
        for (final gm in assigned)
          FacePerson(
            name: byId[gm.memberId]?.displayName ?? 'Staff',
            photoUrl: byId[gm.memberId]?.avatarUrl,
          ),
      ],
    );
  }
}

class _TimeBand extends ConsumerWidget {
  const _TimeBand({required this.group});

  final Group group;

  /// A day is built in SEQUENCE, so a new block starts when the last one
  /// ends. Asking for two timestamps per block is what turns "add lunch" into
  /// a form; the times stay editable by tapping the row, which is the rare
  /// case rather than the default one.
  Future<void> _addBlock(
    WidgetRef ref,
    List<ScheduleBlock> blocks,
    String title,
  ) async {
    final spaceId = ref.read(viewerProvider).spaceId;
    if (spaceId == null) return;
    final now = DateTime.now();
    final lastEnd = blocks.isEmpty
        ? null
        : blocks
              .map((b) => DateTime.tryParse(b.endAt))
              .whereType<DateTime>()
              .fold<DateTime?>(
                null,
                (a, b) => a == null || b.isAfter(a) ? b : a,
              );
    // Falls back to the afterschool program start, which is when a day with
    // nothing in it almost always begins here.
    final start = lastEnd ?? DateTime(now.year, now.month, now.day, 15, 45);
    final db = await ref.read(appDatabaseProvider.future);
    await db.scheduleDao.create(
      spaceId: spaceId,
      groupId: group.id,
      date: todayKey(),
      startAt: start,
      endAt: start.add(const Duration(minutes: 45)),
      title: title,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocks =
        ref
            .watch(
              scheduleDayForGroupProvider((
                groupId: group.id,
                date: todayKey(),
              )),
            )
            .value ??
        const <ScheduleBlock>[];

    return _Band(
      title: 'What happens, and when',
      status: blocks.isEmpty ? 'nothing yet' : '${blocks.length} blocks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (blocks.isEmpty)
            Text(
              'No shape to the day yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final b in blocks)
              InkWell(
                key: ValueKey('block-${b.id}'),
                // BlockEditScreen takes its arguments through go_router's
                // `extra`, NOT a query id — a `?id=` link silently falls
                // back to the schedule screen, which is a tap that navigates
                // somewhere the user did not ask to go.
                onTap: () => unawaited(
                  context.push<void>(
                    '/schedule/block',
                    extra:
                        (
                              groupId: group.id,
                              defaultStart:
                                  DateTime.tryParse(b.startAt) ??
                                  DateTime.now(),
                              existing: b,
                              prefillCurriculumSlug: null,
                            )
                            as BlockEditArgs,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 58,
                        child: Text(
                          _time(b.startAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          b.title?.trim().isNotEmpty ?? false
                              ? b.title!
                              : _kindLabel(b.kind),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 12),
          InlineAdd(
            hint: 'Add a block',
            onSubmit: (v) => _addBlock(ref, blocks, v),
          ),
        ],
      ),
    );
  }

  String _time(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt == null ? '' : timeOfDay(dt);
  }

  String _kindLabel(String kind) => switch (kind) {
    'field_trip' => 'Field trip',
    'break' => 'Break',
    'closed' => 'Closed',
    _ => 'Activity',
  };
}
