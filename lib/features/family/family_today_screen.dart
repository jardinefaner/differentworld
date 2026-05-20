import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        loading: () => const LoadingSlot(variant: LoadingVariant.cards),
        error: (_, _) => ErrorState(
          title: 'Could not load',
          onRetry: () => ref.invalidate(myChildrenProvider),
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
          return _FamilyTodayList(
            space: space,
            children: children,
            guardianName: viewer.displayName,
          );
        },
      ),
    );
  }
}

class _FamilyTodayList extends ConsumerWidget {
  const _FamilyTodayList({
    required this.space,
    required this.children,
    required this.guardianName,
  });

  final Space? space;
  final List<Subject> children;
  final String guardianName;

  String get _todayIso {
    final n = DateTime.now();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Flag-first subtitle: warmer voice when everyone's accounted for,
    // an actionable line when at least one of "your kids" is flagged.
    final flagged = <Subject>[];
    for (final c in children) {
      final groupId = c.groupId;
      if (groupId == null) continue;
      final records = ref
              .watch(attendanceForDayProvider(
                (groupId: groupId, date: _todayIso),
              ))
              .value ??
          const <AttendanceRecord>[];
      for (final r in records) {
        if (r.subjectId != c.id) continue;
        final s = AttendanceStatus.fromDb(r.status);
        if (s == AttendanceStatus.late || s == AttendanceStatus.absent) {
          flagged.add(c);
        }
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horiz = constraints.maxWidth > 840 ? 48.0 : 16.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(horiz, 0, horiz, 96),
          children: [
            ContentHeader(
              title: space?.name ?? 'Today',
              subtitle: _subtitle(guardianName: guardianName, flagged: flagged),
              subtitleColor: flagged.isEmpty
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
            for (final child in children) ...[
              _ChildCard(child: child),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  static String _subtitle({
    required String guardianName,
    required List<Subject> flagged,
  }) {
    if (flagged.isNotEmpty) {
      final names = flagged.map((c) => c.firstName).join(' & ');
      return '$names — check the card below';
    }
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

    final flagged = status == AttendanceStatus.late ||
        status == AttendanceStatus.absent;
    final scheme = theme.colorScheme;

    final dotKind = flagged
        ? StatusDotKind.needsAttention
        : (status == AttendanceStatus.present
            ? StatusDotKind.calm
            : StatusDotKind.neutral);

    return Card(
      clipBehavior: Clip.antiAlias,
      // Late / absent → tinted card with a colored top edge so the
      // flag is unmissable when a parent glances at the family Today.
      color: flagged
          ? status!.color(scheme).withValues(alpha: 0.08)
          : null,
      shape: flagged
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: status!.color(scheme).withValues(alpha: 0.45),
              ),
            )
          : null,
      child: InkWell(
        onTap: () => context.push('/children/${child.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Traffic-light scan affordance — same vocabulary as
              // staff Today so the family lens reads consistently.
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: StatusDot(kind: dotKind),
              ),
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
                            ? scheme.onSurfaceVariant
                            : status.color(scheme),
                        fontWeight: flagged ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
              // Message-staff shortcut: one tap from the family lens
              // to the per-child thread. The kid detail screen also
              // exposes Messages, but for "quick ping" the friction-
              // free path is the card itself.
              IconButton.filledTonal(
                tooltip: 'Message staff',
                icon: const Icon(Icons.forum_outlined),
                onPressed: () => context.push(
                  '/messages?subjectId=${child.id}',
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 4),
                Icon(status.icon, color: status.color(scheme)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Reassuring copy on the calm path — guardians often check this
  /// screen in the morning anxious before drop-off lands; lead with the
  /// usual time, not an accusatory "not yet."
  static String _statusLabel(AttendanceStatus? s) {
    if (s == null) return 'Check-in pending — usually before 9 AM';
    return s.label;
  }
}
