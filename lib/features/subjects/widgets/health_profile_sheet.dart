import 'dart:async';
import 'dart:convert';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Editor for a Subject's health profile. One form, five sections,
/// auto-save on tap of "Done."
///
/// **Storage shape.** Everything except `allergies` lives under
/// `subjects.capabilities` JSONB keys in the `ChildcareSubjectCaps`
/// namespace — no new schema columns, no new tables. `allergies`
/// continues to use the existing dedicated text column (kept for
/// backwards compatibility with the existing edit screen + the
/// subject roster's quick allergy display).
///
/// **Vertical scope.** Only mounted on childcare-vertical Spaces;
/// the storage layer itself is agnostic — other verticals would
/// register their own intake editors (construction project specs,
/// healthcare patient history, etc.) reading their own caps
/// namespace.
///
/// **Lists.** Medications + conditions are stored as JSON-encoded
/// `List<String>`. The form lets the user type comma-separated
/// values for ergonomic input; the splitter trims + drops empties
/// before JSON-encoding.
class HealthProfileSheet extends ConsumerStatefulWidget {
  const HealthProfileSheet({required this.subject, super.key});

  final Subject subject;

  static Future<void> show(
    BuildContext context, {
    required Subject subject,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HealthProfileSheet(subject: subject),
    );
  }

  @override
  ConsumerState<HealthProfileSheet> createState() =>
      _HealthProfileSheetState();
}

class _HealthProfileSheetState extends ConsumerState<HealthProfileSheet> {
  late final TextEditingController _allergies;
  late final TextEditingController _medications;
  late final TextEditingController _conditions;
  late final TextEditingController _iep;
  late final TextEditingController _docName;
  late final TextEditingController _docPhone;
  late final TextEditingController _emergency;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final caps = widget.subject.caps;
    _allergies = TextEditingController(text: widget.subject.allergies ?? '');
    _medications = TextEditingController(
      text: _decodeList(caps.getString(ChildcareSubjectCaps.medications))
          .join(', '),
    );
    _conditions = TextEditingController(
      text:
          _decodeList(caps.getString(ChildcareSubjectCaps.medicalConditions))
              .join(', '),
    );
    _iep = TextEditingController(
      text: caps.getString(ChildcareSubjectCaps.iepSummary) ?? '',
    );
    _docName = TextEditingController(
      text: caps.getString(ChildcareSubjectCaps.physicianName) ?? '',
    );
    _docPhone = TextEditingController(
      text: caps.getString(ChildcareSubjectCaps.physicianPhone) ?? '',
    );
    _emergency = TextEditingController(
      text: caps.getString(ChildcareSubjectCaps.emergencyInstructions) ?? '',
    );
  }

  @override
  void dispose() {
    _allergies.dispose();
    _medications.dispose();
    _conditions.dispose();
    _iep.dispose();
    _docName.dispose();
    _docPhone.dispose();
    _emergency.dispose();
    super.dispose();
  }

  /// Parse a comma-separated input into a list of trimmed,
  /// non-empty values. Returns `''` (treated as clear) when the
  /// resulting list is empty so the cap key gets removed.
  String? _encodeList(String raw) {
    final parts = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return null;
    return jsonEncode(parts);
  }

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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final subjectActions = ref.read(subjectActionsProvider);
    final capActions = ref.read(subjectCapActionsProvider);
    try {
      // Allergies still lives on its own column. Update via the
      // existing SubjectActions path so the field renders identically
      // wherever else the column is read directly.
      final allergiesText = _allergies.text.trim();
      await subjectActions.update(
        id: widget.subject.id,
        allergies: allergiesText.isEmpty ? null : allergiesText,
      );

      // Everything else goes into the JSONB bag, one key at a time
      // (the action layer reads-merges-writes so concurrent edits to
      // other keys aren't clobbered).
      await capActions.setStringCap(
        widget.subject.id,
        ChildcareSubjectCaps.medications,
        _encodeList(_medications.text),
      );
      await capActions.setStringCap(
        widget.subject.id,
        ChildcareSubjectCaps.medicalConditions,
        _encodeList(_conditions.text),
      );
      await capActions.setStringCap(
        widget.subject.id,
        ChildcareSubjectCaps.iepSummary,
        _iep.text.trim(),
      );
      await capActions.setStringCap(
        widget.subject.id,
        ChildcareSubjectCaps.physicianName,
        _docName.text.trim(),
      );
      await capActions.setStringCap(
        widget.subject.id,
        ChildcareSubjectCaps.physicianPhone,
        _docPhone.text.trim(),
      );
      await capActions.setStringCap(
        widget.subject.id,
        ChildcareSubjectCaps.emergencyInstructions,
        _emergency.text.trim(),
      );

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Health profile saved.')),
      );
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'subjects'),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save the health profile. Try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health & medical',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.subject.firstName} ${widget.subject.lastName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _allergies,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Allergies',
                  hintText: 'e.g. Peanuts, dairy',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _medications,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Medications',
                  hintText: 'Comma-separated. e.g. Albuterol, EpiPen Jr',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _conditions,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Medical conditions',
                  hintText: 'Comma-separated. e.g. Asthma, type 1 diabetes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _iep,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'IEP / 504 summary',
                  hintText: 'What staff should know day-to-day.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _docName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Physician name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _docPhone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emergency,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Emergency instructions',
                  hintText:
                      'What to do if something happens — different from '
                      'general notes.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : () => unawaited(_save()),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
