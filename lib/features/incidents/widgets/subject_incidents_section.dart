import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/features/incidents/widgets/incident_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The per-child incident history on Subject detail — this child's logged
/// incidents, newest first, plus a "Log incident" action scoped to them.
/// The narrative is already child-scoped so the cards drop the name/avatar
/// header (`showSubjectName: false`).
///
/// The parent decides whether to render this at all (gated on
/// `featureIncidentReports` + view permission); this widget assumes it's
/// allowed to show, and only re-gates the *log* action on `canObserve`.
class SubjectIncidentsSection extends ConsumerWidget {
  const SubjectIncidentsSection({required this.subjectId, super.key});

  final String subjectId;

  static const _previewCount = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final async = ref.watch(incidentsForSubjectProvider(subjectId));
    final count = async.value?.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Text('Incidents', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (count != null && count > 0)
                Text(
                  '$count',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Could not load incidents.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          data: (incidents) {
            if (incidents.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'No incidents logged.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final inc in incidents.take(_previewCount))
                  IncidentCard(incident: inc, showSubjectName: false),
                if (incidents.length > _previewCount)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+ ${incidents.length - _previewCount} earlier',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (viewer.canObserve)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    context.push('/incidents/new?subjectId=$subjectId'),
                icon: const Icon(Icons.add_alert_outlined, size: 18),
                label: const Text('Log incident'),
              ),
            ),
          ),
      ],
    );
  }
}
