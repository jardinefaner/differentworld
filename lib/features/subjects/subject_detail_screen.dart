import 'package:cached_network_image/cached_network_image.dart';
import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/entries/widgets/observation_form_sheet.dart';
import 'package:differentworld/features/guardians/guardians_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/subjects/widgets/subject_form_sheet.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
            onPressed: () => SubjectFormSheet.show(
              context,
              groupId: subjectAsync.value!.groupId ?? '',
              subject: subjectAsync.value,
            ),
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
            child: _TodayStatusCard(subjectId: subject.id, groupId: groupId),
          ),

        // Alerts (allergies / IEP / meds)
        _AlertsSection(subject: subject, caps: caps),

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
                  _ObservationItem(entry: e),
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
        _AttendanceStrip(subjectId: subject.id),

        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Family', style: theme.textTheme.titleSmall),
        ),
        _GuardiansList(subjectId: subject.id),

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
    yield* db.watchGroup(id);
  },
);

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 24);
}

class _TodayStatusCard extends ConsumerWidget {
  const _TodayStatusCard({required this.subjectId, required this.groupId});

  final String subjectId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isoToday = _isoDate(DateTime.now());
    final recordsAsync = ref.watch(
      attendanceForDayProvider((groupId: groupId, date: isoToday)),
    );
    AttendanceRecord? mine;
    final all = recordsAsync.value ?? const <AttendanceRecord>[];
    for (final r in all) {
      if (r.subjectId == subjectId) {
        mine = r;
        break;
      }
    }
    final status = mine == null ? null : AttendanceStatus.fromDb(mine.status);
    final scheme = theme.colorScheme;
    final color = status?.color(scheme) ?? scheme.outline;
    final label = status?.label ?? 'Not yet checked in';
    final icon = status?.icon ?? Icons.help_outline;

    final shouldAlert =
        status == AttendanceStatus.late || status == AttendanceStatus.absent;

    return Card(
      color: shouldAlert
          ? color.withValues(alpha: 0.10)
          : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _isoDate(DateTime n) =>
      '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.subject, required this.caps});

  final Subject subject;
  final Capabilities caps;

  @override
  Widget build(BuildContext context) {
    final allergies = subject.allergies?.trim();
    final iepNotes = caps.getString(SubjectCaps.iepNotes);
    final medications = caps.getString(SubjectCaps.medications);
    final hasIep = caps.getBool(SubjectCaps.hasIep);
    final needsOneOnOne = caps.getBool(SubjectCaps.requiresOneOnOne);

    final alerts = <_Alert>[
      if (allergies != null && allergies.isNotEmpty)
        _Alert(label: 'Allergies', body: allergies, icon: Icons.warning_amber),
      if (medications != null && medications.isNotEmpty)
        _Alert(
          label: 'Medications',
          body: medications,
          icon: Icons.medical_information_outlined,
        ),
      if (hasIep)
        _Alert(
          label: 'IEP',
          body: iepNotes ?? 'On an Individualized Education Plan.',
          icon: Icons.assignment_outlined,
        ),
      if (needsOneOnOne)
        const _Alert(
          label: 'One-on-one',
          body: 'Requires a dedicated adult during the day.',
          icon: Icons.person_outline,
        ),
    ];
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in alerts) _AlertRow(alert: a),
        ],
      ),
    );
  }
}

class _Alert {
  const _Alert({required this.label, required this.body, required this.icon});
  final String label;
  final String body;
  final IconData icon;
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});

  final _Alert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(alert.icon, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onErrorContainer,
                  ),
                ),
                Text(
                  alert.body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservationItem extends StatelessWidget {
  const _ObservationItem({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = DateTime.tryParse(entry.recordedAt);
    final whenLabel =
        when == null ? '' : DateFormat.MMMd().add_jm().format(when);
    final photoUrl = entry.photoUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              whenLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(entry.body ?? ''),
            if (photoUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    height: 200,
                    color: theme.colorScheme.surfaceContainerHigh,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttendanceStrip extends ConsumerWidget {
  const _AttendanceStrip({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync =
        ref.watch(attendanceHistoryForSubjectProvider(subjectId));

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          'Could not load attendance.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      data: (records) {
        // Build 30-day window ending today.
        final days = <DateTime>[];
        final now = DateTime.now();
        for (var i = 29; i >= 0; i--) {
          days.add(DateTime(now.year, now.month, now.day - i));
        }
        final byDate = <String, AttendanceStatus?>{};
        for (final r in records) {
          byDate[r.date] = AttendanceStatus.fromDb(r.status);
        }
        return SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final d in days) ...[
                  _AttendanceDot(
                    date: d,
                    status: byDate[_isoDate(d)],
                  ),
                  if (d != days.last) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String _isoDate(DateTime n) =>
      '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

class _AttendanceDot extends StatelessWidget {
  const _AttendanceDot({required this.date, this.status});

  final DateTime date;
  final AttendanceStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = status == null
        ? scheme.surfaceContainerHighest
        : status!.color(scheme).withValues(alpha: 0.85);
    return Tooltip(
      message: '${DateFormat.MMMd().format(date)} '
          '· ${status?.label ?? "no record"}',
      child: Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardiansList extends ConsumerWidget {
  const _GuardiansList({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final guardiansAsync = ref.watch(guardiansForSubjectProvider(subjectId));
    return guardiansAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          'Could not load family.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      data: (guardians) {
        if (guardians.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'No guardians on file.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final g in guardians)
              ListTile(
                leading: PersonAvatar(name: g.name),
                title: Text(g.name),
                subtitle: Text(
                  [
                    g.relationship,
                    g.phone,
                    g.email,
                  ].whereType<String>().join(' · '),
                ),
              ),
          ],
        );
      },
    );
  }
}
