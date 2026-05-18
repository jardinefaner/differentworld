import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Family-side home screen. Shown when the active viewer is a
/// [GuardianViewer]. Lists the guardian's children with today's
/// status; no staff surface, no admin chrome.
///
/// Minimum viable for this wave — per-child timeline, messaging,
/// billing surfaces are documented in the family-login skill as
/// follow-up work.
class FamilyTodayScreen extends ConsumerWidget {
  const FamilyTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (viewer is! GuardianViewer) {
      // Router is supposed to gate; defensive empty state.
      return const EdgeScaffold(body: SizedBox.shrink());
    }
    final space = viewer.space;
    final childrenAsync = ref.watch(myChildrenProvider);

    return EdgeScaffold(
      showBack: false,
      actions: const [SyncStatusIndicator()],
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
        ),
        data: (children) {
          if (children.isEmpty) {
            return const EmptyState(
              icon: Icons.child_care_outlined,
              title: 'No children linked yet',
              message:
                  'Your program director will link your children to your '
                  'account shortly. Check back in a few minutes.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final horiz = constraints.maxWidth > 840 ? 48.0 : 16.0;
              return ListView(
                padding: EdgeInsets.fromLTRB(horiz, 0, horiz, 96),
                children: [
                  ContentHeader(
                    title: space?.name ?? 'Today',
                    subtitle: _greeting(viewer.displayName),
                  ),
                  for (final child in children) ...[
                    _ChildCard(child: child),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _greeting(String guardianName) {
    final greeting = _greetingForTime(DateTime.now());
    final dayLabel = DateFormat.yMMMMEEEEd().format(DateTime.now());
    if (guardianName.isEmpty) return '$greeting · $dayLabel';
    return '$greeting, $guardianName · $dayLabel';
  }

  static String _greetingForTime(DateTime when) {
    final hour = when.hour;
    if (hour < 5) return 'Hi';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child});

  final Subject child;

  String get _todayIso {
    final n = DateTime.now();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupId = child.groupId;
    final recordsAsync = groupId == null
        ? const AsyncValue<List<AttendanceRecord>>.data([])
        : ref.watch(
            attendanceForDayProvider(
              (groupId: groupId, date: _todayIso),
            ),
          );
    AttendanceRecord? myRecord;
    final all = recordsAsync.value ?? const <AttendanceRecord>[];
    for (final r in all) {
      if (r.subjectId == child.id) {
        myRecord = r;
        break;
      }
    }
    final status = myRecord == null
        ? null
        : AttendanceStatus.fromDb(myRecord.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            PersonAvatar(
              name: '${child.firstName} ${child.lastName}',
              photoUrl: child.photoUrl,
              radius: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${child.firstName} ${child.lastName}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel(status),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status == null
                          ? theme.colorScheme.onSurfaceVariant
                          : status.color(theme.colorScheme),
                    ),
                  ),
                ],
              ),
            ),
            if (status != null)
              Icon(status.icon, color: status.color(theme.colorScheme)),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(AttendanceStatus? s) {
    if (s == null) return 'Not yet checked in today';
    return s.label;
  }
}
