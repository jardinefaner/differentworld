import 'dart:convert';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/subjects/widgets/health_profile_sheet.dart';
import 'package:flutter/material.dart';

/// Read-only display of a Subject's structured health profile —
/// medications, medical conditions, IEP/504 summary, primary
/// physician, emergency instructions.
///
/// **Vertical scope.** The fields it reads live on
/// `subjects.capabilities` under the `ChildcareSubjectCaps`
/// namespace. Other verticals (construction "project", healthcare
/// "patient", etc.) get their own namespaces under the same JSONB
/// bag — no new tables. The CALLER is responsible for only
/// mounting this card on a childcare-vertical Space; nothing in
/// the storage layer is childcare-only.
///
/// Renders an empty placeholder + "Add details" button when every
/// field is empty, so a fresh subject has a discoverable entry
/// point rather than just blank space.
class HealthProfileCard extends StatelessWidget {
  const HealthProfileCard({required this.subject, super.key});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final caps = subject.caps;

    final allergies = subject.allergies?.trim();
    final medications = _decodeList(
      caps.getString(ChildcareSubjectCaps.medications),
    );
    final conditions = _decodeList(
      caps.getString(ChildcareSubjectCaps.medicalConditions),
    );
    final iep = caps.getString(ChildcareSubjectCaps.iepSummary)?.trim();
    final docName = caps
        .getString(ChildcareSubjectCaps.physicianName)
        ?.trim();
    final docPhone = caps
        .getString(ChildcareSubjectCaps.physicianPhone)
        ?.trim();
    final emergency = caps
        .getString(ChildcareSubjectCaps.emergencyInstructions)
        ?.trim();

    final empty = (allergies == null || allergies.isEmpty) &&
        medications.isEmpty &&
        conditions.isEmpty &&
        (iep == null || iep.isEmpty) &&
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
          onTap: () => HealthProfileSheet.show(context, subject: subject),
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
                    'allergies, medications, conditions, IEP/504 '
                    'summary, or physician contact.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  if (allergies != null && allergies.isNotEmpty)
                    _Field(
                      label: 'Allergies',
                      value: allergies,
                      emphasised: true,
                    ),
                  if (medications.isNotEmpty)
                    _Field(
                      label: 'Medications',
                      value: medications.join(', '),
                    ),
                  if (conditions.isNotEmpty)
                    _Field(
                      label: 'Conditions',
                      value: conditions.join(', '),
                    ),
                  if (iep != null && iep.isNotEmpty)
                    _Field(label: 'IEP / 504', value: iep),
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// JSON-decode a list-of-strings cap. Returns empty list on null,
  /// empty string, or any parse failure — the card UI must never
  /// throw because the JSONB blob is malformed.
  static List<String> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on FormatException {
      // Corrupt — treat as empty.
    }
    return const <String>[];
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

  /// Allergies + emergency rows get a warm tint to distinguish them
  /// from the merely-informational ones — staff scan for those
  /// first when someone hurts themselves.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelColor = emphasised
        ? scheme.error.withValues(alpha: 0.95)
        : scheme.onSurfaceVariant;
    final valueColor = emphasised ? scheme.onSurface : scheme.onSurface;
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
