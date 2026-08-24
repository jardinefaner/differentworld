import 'dart:async';

import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/groups/room_skin_background.dart';
import 'package:differentworld/features/groups/room_skin_picker.dart';
import 'package:differentworld/features/groups/room_skins.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_grid.dart';
import 'package:differentworld/shared/widgets/route_title.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:differentworld/shared/widgets/status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  String _query = '';
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final labels = ref.watch(verticalLabelsProvider);
    final groupAsync = ref.watch(_groupProvider(widget.groupId));
    final subjectsAsync = ref.watch(subjectsInGroupProvider(widget.groupId));
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the room overview (header + skin chip +
    // search + roster) re-lays as bento tiles over the SAME providers; off
    // keeps the existing Column + ResponsiveGrid. The RoomSkinBackground
    // (EdgeScaffold.background) and every action are untouched either way.
    final bento = bentoEnabled(ref, perScreen: null);

    final group = groupAsync.value;
    final groupId = widget.groupId;
    // The room's own theme, decaled subtly behind the Calm content.
    final roomSkin = group == null ? null : roomSkinForGroup(group);
    // Wave 108: dynamic tab title — the classroom name.
    return RouteTitle(
      title: group?.name.trim().isNotEmpty == true ? group!.name : labels.group,
      child: EdgeScaffold(
        background: roomSkin == null
            ? null
            : RoomSkinBackground(skin: roomSkin, decal: true, animate: true),
        actions: [
          // Primary verb: add a subject (director-only). For everyone
          // else, take-attendance is the most frequent so it takes the
          // primary slot.
          if (viewer.canManageSpace &&
              (subjectsAsync.value?.isNotEmpty ?? false))
            PrimaryActionButton(
              tooltip: 'Add a ${labels.subject.toLowerCase()}',
              icon: Icons.person_add_outlined,
              onPressed: () => context.push('/groups/$groupId/students/new'),
            )
          else if (viewer.canTakeAttendance)
            PrimaryActionButton(
              tooltip: 'Take ${labels.attendanceNoun.toLowerCase()}',
              icon: Icons.fact_check_outlined,
              onPressed: () => context.push('/groups/$groupId/attendance'),
            ),
          // Secondary attendance entry when the primary is "add subject"
          // (director) — they still take attendance often enough.
          if (viewer.canManageSpace && viewer.canTakeAttendance)
            SecondaryActionButton(
              tooltip: 'Take ${labels.attendanceNoun.toLowerCase()}',
              icon: Icons.fact_check_outlined,
              onPressed: () => context.push('/groups/$groupId/attendance'),
            ),
          // Secondary actions live in an overflow menu — the AppBar is
          // tight on phones, especially with the sync indicator.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'observations':
                  unawaited(context.push('/groups/$groupId/observations'));
                case 'arrange':
                  unawaited(context.push('/groups/$groupId/arrange'));
                case 'coverage':
                  unawaited(context.push('/groups/$groupId/coverage'));
                case 'edit':
                  unawaited(context.push('/groups/$groupId/edit'));
              }
            },
            itemBuilder: (_) => [
              if (viewer.canObserve || viewer.canManageSpace)
                const PopupMenuItem(
                  value: 'observations',
                  child: ListTile(
                    leading: Icon(Icons.menu_book_outlined),
                    title: Text('Observations'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              // The Room console's instruments (docs/ROTATION.md).
              const PopupMenuItem(
                value: 'arrange',
                child: ListTile(
                  leading: Icon(Icons.groups_2_outlined),
                  title: Text('Make groups'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'coverage',
                child: ListTile(
                  leading: Icon(Icons.hub_outlined),
                  title: Text('Who hasn’t worked together'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (group != null && viewer.canManageSpace)
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit classroom'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
          const SyncStatusIndicator(),
        ],
        body: subjectsAsync.when(
          loading: () => const LoadingSlot(),
          error: (err, _) => ErrorState(
            title: 'Could not load students',
            onRetry: () => ref.invalidate(subjectsInGroupProvider(groupId)),
          ),
          data: (subjects) {
            if (subjects.isEmpty) {
              // Director can self-serve; everyone else sees a dead-end
              // otherwise. Surface the team directory as the next-step
              // affordance so the assistant can ping whoever runs the
              // program.
              if (viewer.canManageSpace) {
                return EmptyState(
                  icon: Icons.child_care_outlined,
                  title: 'No ${labels.subjectPlural.toLowerCase()} yet',
                  message:
                      'Add your first ${labels.subject.toLowerCase()} to '
                      'start taking ${labels.attendanceNoun.toLowerCase()} '
                      'and logging ${labels.entryPlural.toLowerCase()}.',
                  action: FilledButton.icon(
                    onPressed: () =>
                        context.push('/groups/$groupId/students/new'),
                    icon: const Icon(Icons.add),
                    label: Text('Add ${labels.subject.toLowerCase()}'),
                  ),
                );
              }
              return EmptyState(
                icon: Icons.child_care_outlined,
                title: 'No ${labels.subjectPlural.toLowerCase()} yet',
                message:
                    "Your ${RoleLabels.of('director', vertical: labels.vertical).toLowerCase()} "
                    "will set up this ${labels.group.toLowerCase()}'s roster. "
                    'Need to follow up? Open the team directory.',
                action: FilledButton.tonalIcon(
                  onPressed: () => context.push('/settings/team'),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Open team directory'),
                ),
              );
            }
            // Default sort: by first name, alphabetical. Insertion
            // order isn't meaningful to a teacher scanning the roster.
            final sorted = [...subjects]
              ..sort(
                (a, b) => a.firstName.toLowerCase().compareTo(
                  b.firstName.toLowerCase(),
                ),
              );
            final filtered = _query.isEmpty
                ? sorted
                : sorted.where((s) {
                    final name = '${s.firstName} ${s.lastName}'.toLowerCase();
                    return name.contains(_query.toLowerCase());
                  }).toList();

            // Wave 110: header + search field as siblings ABOVE the
            // grid (they're not roster cards). The roster itself
            // flows into a ResponsiveGrid so a class of 24 kids
            // renders as 2 columns at tablet, 3 columns at desktop
            // instead of a 1920-wide single column.
            //
            // The header / skin chip / search are built once and shared by both
            // layouts so they never drift. The search TextField keeps a stable
            // key so re-laying around it (the bento tile vs the flat Column)
            // can't poison its Element / drop the IME (CLAUDE.md "Stack children
            // without keys").
            final identity = _RoomIdentity(
              title: group?.name ?? labels.group,
              subtitle: group?.ageRange,
              group: group,
              query: _query,
              controller: _searchCtl,
              onChanged: (v) => setState(() => _query = v),
              onClear: () {
                _searchCtl.clear();
                setState(() => _query = '');
              },
            );

            if (bento) {
              // Identity (name + skin + search) leads as a full-width banner;
              // the roster is the tall full-width tile below. Both wide → the
              // 1-D Wrap packs into clean single-column runs at every width.
              // The roster renders as a shrink-wrapping (non-scrolling) grid so
              // it's safe inside the outer scroll + the bento cell's unbounded
              // max height (docs/GRID.md).
              return ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
                children: [
                  BentoGrid(
                    tiles: [
                      BentoTile(
                        id: 'identity',
                        span: const BentoSpan.wide(),
                        child: identity,
                      ),
                      BentoTile(
                        id: 'roster',
                        span: const BentoSpan.wide(rows: 2),
                        child: _RosterGrid(
                          subjects: filtered,
                          groupId: groupId,
                          shrinkWrap: true,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                Expanded(
                  child: _RosterGrid(
                    subjects: filtered,
                    groupId: groupId,
                    shrinkWrap: false,
                  ),
                ),
              ],
            );
          },
        ),
        // FAB removed — "Add student" lives in the top-right primary
        // action pill (see actions above) for directors. Take-attendance
        // remains the primary verb for non-directors.
      ),
    );
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _groupProvider = StreamProvider.family<Group?, String>(
  (ref, groupId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.groupsDao.watchById(groupId);
  },
);

/// The room's identity block — name + age, the permanent skin chip, and the
/// roster search pill. Shared by the flat + bento layouts so they never drift.
class _RoomIdentity extends StatelessWidget {
  const _RoomIdentity({
    required this.title,
    required this.subtitle,
    required this.group,
    required this.query,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final String title;
  final String? subtitle;
  final Group? group;
  final String query;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    return Column(
      // Shrink-wrap: in the bento path this fills a min-height / unbounded-max
      // cell; in the flat path it's a non-Expanded Column child (docs/GRID.md).
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ContentHeader(title: title, subtitle: subtitle, bottomGap: 8),
        ),
        // The room's permanent theme skin (docs/VISION.md).
        if (group != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: RoomSkinChip(group: group),
          ),
        // Search pill — useful when rosters cross 10 kids.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            // Stable key: re-laying this field between the flat Column and a
            // bento tile must not poison its Element / drop the IME (CLAUDE.md
            // "Stack children without keys").
            key: const ValueKey('group-roster-search'),
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Find a student…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onClear,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The roster as a responsive grid of `_SubjectTile`s. `shrinkWrap` chooses
/// between the flat layout's scrollable `ResponsiveGrid` (lives in an
/// `Expanded`, scrolls itself) and the bento layout's non-scrolling grid
/// (lives inside the outer ListView + a bento cell — shrink-wraps so it never
/// nests an unbounded scrollable; docs/GRID.md).
class _RosterGrid extends StatelessWidget {
  const _RosterGrid({
    required this.subjects,
    required this.groupId,
    required this.shrinkWrap,
  });

  final List<Subject> subjects;
  final String groupId;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (!shrinkWrap) {
      return ResponsiveGrid(
        itemCount: subjects.length,
        // Roster tiles are short (avatar + name + age).
        // 3.0 = wide-and-short — fits more kids on screen.
        aspectRatio: 3,
        itemMaxWidth: 320,
        itemBuilder: (_, i) =>
            _SubjectTile(subject: subjects[i], groupId: groupId),
      );
    }
    return GridView.builder(
      // Inside the outer ListView — don't scroll, just take the height the
      // rows need.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3,
      ),
      itemCount: subjects.length,
      itemBuilder: (_, i) =>
          _SubjectTile(subject: subjects[i], groupId: groupId),
    );
  }
}

class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({required this.subject, required this.groupId});

  final Subject subject;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ageLine = _ageLine(subject.dob);
    final fullName = '${subject.firstName} ${subject.lastName}';
    final records =
        ref
            .watch(
              attendanceForDayProvider(
                (groupId: groupId, date: todayIso()),
              ),
            )
            .value ??
        const <AttendanceRecord>[];
    AttendanceStatus? today;
    for (final r in records) {
      if (r.subjectId != subject.id) continue;
      today = AttendanceStatus.fromDb(r.status);
      break;
    }
    final dotKind = switch (today) {
      AttendanceStatus.present => StatusDotKind.calm,
      AttendanceStatus.late ||
      AttendanceStatus.absent => StatusDotKind.needsAttention,
      AttendanceStatus.earlyPickup ||
      AttendanceStatus.excused => StatusDotKind.progress,
      null => StatusDotKind.neutral,
    };

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          PersonAvatar(
            name: fullName,
            photoUrl: subject.photoUrl,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: StatusDot(kind: dotKind, size: 10, glow: false),
            ),
          ),
        ],
      ),
      title: EntityLink(
        entity: EntityRef(
          kind: EntityKind.subject,
          id: subject.id,
          label: fullName,
        ),
        padded: false,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: ageLine == null ? null : Text(ageLine),
      // Wave 101: hide-don't-disable. If the subject is in this group's
      // roster, `groupId` is always set — but a tap target with no
      // handler is the worst shape. Drop the chevron + tap when null
      // so the row degrades to a plain identity tile rather than
      // promising navigation it won't deliver.
      trailing: subject.groupId == null
          ? null
          : const Icon(Icons.chevron_right),
      onTap: subject.groupId == null
          ? null
          : () => unawaited(
              context.push('/groups/${subject.groupId}/students/${subject.id}'),
            ),
    );
  }

  static String? _ageLine(String? dobIso) {
    if (dobIso == null || dobIso.isEmpty) return null;
    final dob = DateTime.tryParse(dobIso);
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    var months = now.month - dob.month;
    if (now.day < dob.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years <= 0) return '$months mo';
    if (months == 0) return '$years yr';
    return '$years yr $months mo';
  }
}
