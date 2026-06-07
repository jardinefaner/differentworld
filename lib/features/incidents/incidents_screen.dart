import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The incident log — every logged incident in the program, newest first
/// (docs/WORKFLOWS.md gap #3). A compliance surface: typed, child-scoped,
/// family-notification tracked. Scoped to what the viewer can see (their
/// cohorts; directors see all).
class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (!viewer.canObserve && !viewer.canManageSpace) {
      return const EdgeScaffold(body: NoAccess());
    }

    final incidentsAsync = ref.watch(incidentsInSpaceProvider);
    final subjectsById = <String, Subject>{
      for (final s
          in ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[])
        s.id: s,
    };

    return EdgeScaffold(
      actions: [
        if (viewer.canObserve)
          PrimaryActionButton(
            tooltip: 'Log an incident',
            icon: Icons.add,
            onPressed: () => context.push('/incidents/new'),
          ),
        const SyncStatusIndicator(),
      ],
      body: incidentsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load incidents',
          onRetry: () => ref.invalidate(incidentsInSpaceProvider),
        ),
        data: (incidents) {
          if (incidents.isEmpty) {
            return EmptyState(
              icon: Icons.report_gmailerrorred_outlined,
              title: 'No incidents logged',
              message: viewer.canObserve
                  ? 'When something happens — a bump, a conflict, an '
                      'illness — log it here so there’s a record.'
                  : 'Incidents logged by staff will appear here.',
              action: viewer.canObserve
                  ? FilledButton.icon(
                      onPressed: () => context.push('/incidents/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Log an incident'),
                    )
                  : null,
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.splitMaxWidth,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: incidents.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: ContentHeader(title: 'Incidents'),
                    );
                  }
                  final incident = incidents[i - 1];
                  return _IncidentRow(
                    incident: incident,
                    subject: subjectsById[incident.subjectId],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident, this.subject});

  final Incident incident;
  final Subject? subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = subject == null
        ? 'A child'
        : '${subject!.firstName} ${subject!.lastName}'.trim();
    final when = DateTime.tryParse(incident.recordedAt)?.toLocal();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PersonAvatar(
                  name: name,
                  photoUrl: subject?.photoUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (when != null)
                        Text(
                          relativeTimeAgo(when),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                _TypeChip(type: incident.type),
              ],
            ),
            if (incident.narrative.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(incident.narrative),
            ],
            if (incident.actionTaken != null &&
                incident.actionTaken!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.healing_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      incident.actionTaken!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            _NotifyBadge(notified: incident.parentNotified),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final IncidentType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type.icon,
            size: 14,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 5),
          Text(
            type.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifyBadge extends StatelessWidget {
  const _NotifyBadge({required this.notified});

  final bool notified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notified
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          notified ? Icons.mark_email_read_outlined : Icons.email_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          notified ? 'Family notified' : 'Family not notified yet',
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
