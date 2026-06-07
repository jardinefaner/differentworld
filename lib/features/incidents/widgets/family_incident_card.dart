import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:flutter/material.dart';

/// A family-facing incident card. **Leak-proof by construction**: it
/// renders ONLY the incident type, when it happened, the staff-written
/// family note, and whether the family was notified. It deliberately does
/// NOT touch [Incident.narrative] or [Incident.actionTaken] — those are
/// staff-only because they can name other children (a conflict). The
/// family lens shows only incidents staff have surfaced (see
/// `familyIncidentsForSubjectProvider`).
class FamilyIncidentCard extends StatelessWidget {
  const FamilyIncidentCard({required this.incident, super.key});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                Icon(
                  incident.type.icon,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  incident.type.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (when != null)
                  Text(
                    relativeTimeAgo(when),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (incident.familyNote != null) ...[
              const SizedBox(height: 8),
              Text(incident.familyNote!),
            ],
            if (incident.parentNotified) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Staff notified your family',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
