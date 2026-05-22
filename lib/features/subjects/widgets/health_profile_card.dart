import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Read-only display of a Subject's structured health profile —
/// medications, medical conditions, IEP/504 summary, primary
/// physician, emergency instructions.
///
/// **Storage shape.** Reads from the existing `SubjectCaps` keys on
/// `subjects.capabilities` JSONB. No schema columns of its own; same
/// bag the AlertsSection above reads from. Other verticals (a
/// construction project's intake, a healthcare patient's history)
/// register their own card here reading their own namespace — no
/// new tables.
///
/// Renders an empty-state placeholder + "Add details" button when
/// every field is empty, so a fresh subject has a discoverable
/// entry point rather than just blank space.
class HealthProfileCard extends StatelessWidget {
  const HealthProfileCard({required this.subject, super.key});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final caps = subject.caps;

    final allergies = subject.allergies?.trim();
    final medications = caps.getString(SubjectCaps.medications)?.trim();
    final conditions =
        caps.getString(SubjectCaps.medicalConditions)?.trim();
    final hasIep = caps.getBool(SubjectCaps.hasIep);
    final iepNotes = caps.getString(SubjectCaps.iepNotes)?.trim();
    final needsOneOnOne = caps.getBool(SubjectCaps.requiresOneOnOne);
    final docName = caps.getString(SubjectCaps.physicianName)?.trim();
    final docPhone = caps.getString(SubjectCaps.physicianPhone)?.trim();
    final emergency =
        caps.getString(SubjectCaps.emergencyInstructions)?.trim();

    final empty = (allergies == null || allergies.isEmpty) &&
        (medications == null || medications.isEmpty) &&
        (conditions == null || conditions.isEmpty) &&
        !hasIep &&
        (iepNotes == null || iepNotes.isEmpty) &&
        !needsOneOnOne &&
        (docName == null || docName.isEmpty) &&
        (docPhone == null || docPhone.isEmpty) &&
        (emergency == null || emergency.isEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            '/subjects/${subject.id}/health',
            extra: subject,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medical_information_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Health & medical',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      empty ? Icons.add : Icons.edit_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (empty)
                  Text(
                    'No health details on file yet. Tap to add '
                    'medications, conditions, IEP/504 plan, physician '
                    'contact, or emergency instructions.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  // The AlertsSection above already shows allergies +
                  // medications + IEP toggle as warm pills, so we
                  // don't duplicate them here. This card focuses on
                  // the EXTRA structured fields the sheet captures.
                  if (conditions != null && conditions.isNotEmpty)
                    _Field(label: 'Conditions', value: conditions),
                  if (iepNotes != null && iepNotes.isNotEmpty && !hasIep)
                    // IEP notes typed but the toggle's off — surface
                    // the notes anyway so the user sees them; the
                    // alert at the top won't render them in this
                    // case.
                    _Field(label: 'IEP / 504', value: iepNotes),
                  if ((docName != null && docName.isNotEmpty) ||
                      (docPhone != null && docPhone.isNotEmpty))
                    _Field(
                      label: 'Physician',
                      value: [
                        if (docName != null && docName.isNotEmpty) docName,
                        if (docPhone != null && docPhone.isNotEmpty) docPhone,
                      ].join(' · '),
                    ),
                  if (emergency != null && emergency.isNotEmpty)
                    _Field(
                      label: 'Emergency',
                      value: emergency,
                      emphasised: true,
                    ),
                  // If only allergies / medications / IEP are set
                  // (everything that AlertsSection already shows),
                  // tell the user the card itself has nothing extra
                  // rather than rendering empty.
                  if ((conditions == null || conditions.isEmpty) &&
                      ((iepNotes == null || iepNotes.isEmpty) || hasIep) &&
                      (docName == null || docName.isEmpty) &&
                      (docPhone == null || docPhone.isEmpty) &&
                      (emergency == null || emergency.isEmpty))
                    Text(
                      'Tap to add conditions, physician, or '
                      'emergency instructions.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;

  /// Emergency rows get a warm tint to distinguish them from the
  /// merely-informational ones — staff scan for those first.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelColor = emphasised
        ? scheme.error.withValues(alpha: 0.95)
        : scheme.onSurfaceVariant;
    final valueColor = scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(color: valueColor),
          children: [
            TextSpan(
              text: '$label  ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
