import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/entries/widgets/observation_form_sheet.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/subjects/widgets/alerts_section.dart';
import 'package:differentworld/features/subjects/widgets/attendance_strip.dart';
import 'package:differentworld/features/subjects/widgets/guardians_list.dart';
import 'package:differentworld/features/subjects/widgets/observation_item.dart';
import 'package:differentworld/features/subjects/widgets/pickup_list.dart';
import 'package:differentworld/features/subjects/widgets/today_status_card.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Per-child timeline. Same screen for staff (reached via classroom →
/// student) and family (reached via Family Today → child card). The
/// viewer controls what's editable.
///
/// Sections, top to bottom:
/// - Header: avatar + name + age + classroom name + status today
/// - Alerts: allergies / IEP / medical conditions (the things you
///   want anyone to know before they touch the kid)
/// - Observations: full feed, newest first; FAB to add for canObserve
/// - Attendance: last ~60 days as colored dots
/// - Family: linked guardians, read-only for everyone but director
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);

    // Guardians can only see THEIR kids.
    if (viewer is GuardianViewer && !viewer.canSeeSubject(subjectId)) {
      return const EdgeScaffold(
        body: NoAccess(
          title: "That isn't one of your children.",
        ),
      );
    }

    final subjectAsync = ref.watch(subjectByIdProvider(subjectId));

    return EdgeScaffold(
      actions: [
        if (viewer.canManageProgram && subjectAsync.value != null)
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              final gid = subjectAsync.value!.groupId ?? '';
              if (gid.isEmpty) return;
              unawaited(
                context.push('/groups/$gid/students/$subjectId/edit'),
              );
            },
          ),
        const SyncStatusIndicator(),
      ],
      floatingActionButton: (viewer.canObserve && subjectAsync.value != null)
          ? FloatingActionButton.extended(
              onPressed: () => ObservationFormSheet.show(
                context,
                groupId: subjectAsync.value!.groupId ?? '',
                initialSubjectId: subjectId,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Observation'),
            )
          : null,
      body: subjectAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
        ),
        data: (subject) {
          if (subject == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Student not found.',
            );
          }
          return _SubjectBody(subject: subject, viewer: viewer);
        },
      ),
    );
  }
}

class _SubjectBody extends ConsumerWidget {
  const _SubjectBody({required this.subject, required this.viewer});

  final Subject subject;
  final Viewer viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final caps = Capabilities.fromJson(subject.capabilities);
    final fullName = '${subject.firstName} ${subject.lastName}';
    final groupId = subject.groupId;
    final groupAsync = groupId == null
        ? const AsyncValue<Group?>.data(null)
        : ref.watch(_groupForDetailProvider(groupId));
    final ageLine = _ageLine(subject.dob);
    final entriesAsync = ref.watch(
      entriesForSubjectProvider(
        (subjectId: subject.id, kind: EntryKind.observation),
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        // Header (custom — bigger avatar than ContentHeader).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          child: Row(
            children: [
              PersonAvatar(
                name: fullName,
                photoUrl: subject.photoUrl,
                radius: 36,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: theme.textTheme.headlineSmall),
                    if (ageLine != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        ageLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (groupAsync.value != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        groupAsync.value!.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Today's status row
        if (groupId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TodayStatusCard(subjectId: subject.id, groupId: groupId),
          ),

        // Alerts (allergies / IEP / meds)
        AlertsSection(subject: subject, caps: caps),

        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Text('Observations', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                entriesAsync.value == null
                    ? ''
                    : '${entriesAsync.value!.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        entriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Could not load observations.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'No observations yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final e in entries.take(10))
                  SubjectObservationItem(entry: e),
              ],
            );
          },
        ),

        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Attendance — last 30 days',
            style: theme.textTheme.titleSmall,
          ),
        ),
        AttendanceStrip(subjectId: subject.id),

        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Family', style: theme.textTheme.titleSmall),
        ),
        GuardiansList(subjectId: subject.id),

        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Authorized for pickup',
            style: theme.textTheme.titleSmall,
          ),
        ),
        PickupList(subject: subject),

        if ((subject.notes ?? '').isNotEmpty) ...[
          const _SectionGap(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Notes', style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              subject.notes!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ],
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
    if (years <= 0) return '$months months';
    if (months == 0) return '$years years';
    return '$years yr $months mo';
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _groupForDetailProvider =
    StreamProvider.autoDispose.family<Group?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.groupsDao.watchById(id);
  },
);

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 24);
}

/// In-card photo strip for the per-child timeline. One photo →
/// single full-width image. Multiple → horizontal scroll with a
/// "+N" pill on the first; tap any to open the fullscreen viewer
/// at that photo's index.

/// One guardian row inside the family list, with a "Message" trailing
/// affordance and an unread badge if this guardian has sent messages
/// staff hasn't read yet. Tap the chat icon to open the thread.

/// "Authorized for pickup" — non-guardian adults approved to collect
/// this child. Editable by guardians of the subject OR staff with
/// canAuthorizePickup; read-only for everyone else.
