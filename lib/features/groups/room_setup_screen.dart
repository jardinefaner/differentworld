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
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/inline_add.dart';
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
          Text(group.name, style: theme.textTheme.headlineSmall),
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
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Rename, skin, limits'),
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
          InlineAdd(
            hint: 'Add a child',
            onSubmit: (v) => _add(ref, v),
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
          TextButton.icon(
            onPressed: () => unawaited(context.push('/team')),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Assign an adult'),
          ),
        ],
      ),
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
              Padding(
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
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => unawaited(context.push('/schedule')),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add a block'),
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
