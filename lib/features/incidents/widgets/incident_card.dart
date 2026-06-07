import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';

/// One incident rendered as a card — type, narrative, action taken, and a
/// family-notified badge. Shared by the incident log (`/incidents`) and
/// the per-child incident section on Subject detail.
///
/// [showSubjectName] leads with the child's avatar + name (the log, where
/// identity matters). When false (a per-child section, where the child is
/// already obvious), it leads with the type + time instead.
class IncidentCard extends StatelessWidget {
  const IncidentCard({
    required this.incident,
    this.subject,
    this.showSubjectName = true,
    super.key,
  });

  final Incident incident;
  final Subject? subject;
  final bool showSubjectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = DateTime.tryParse(incident.recordedAt)?.toLocal();
    final whenLabel = when == null ? '' : relativeTimeAgo(when);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSubjectName)
              _IdentityHeader(
                subject: subject,
                whenLabel: whenLabel,
                type: incident.type,
              )
            else
              Row(
                children: [
                  _TypeChip(type: incident.type),
                  const Spacer(),
                  if (whenLabel.isNotEmpty)
                    Text(
                      whenLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.subject,
    required this.whenLabel,
    required this.type,
  });

  final Subject? subject;
  final String whenLabel;
  final IncidentType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = subject == null
        ? 'A child'
        : '${subject!.firstName} ${subject!.lastName}'.trim();
    return Row(
      children: [
        PersonAvatar(name: name, photoUrl: subject?.photoUrl),
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
              if (whenLabel.isNotEmpty)
                Text(
                  whenLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        _TypeChip(type: type),
      ],
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
