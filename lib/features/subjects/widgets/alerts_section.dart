
import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:flutter/material.dart';

class AlertsSection extends StatelessWidget {
  const AlertsSection({required this.subject, required this.caps, super.key});

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
