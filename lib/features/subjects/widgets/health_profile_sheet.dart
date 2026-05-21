import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Editor for a Subject's health profile.
///
/// **Storage shape.** Writes to the existing `SubjectCaps` keys on
/// `subjects.capabilities` JSONB — same keys the `AlertsSection`
/// above the card reads from. Allergies still rides its own
/// `subjects.allergies` text column for backward compat with the
/// roster and other call sites that touch the column directly. No
/// new schema; no new tables.
///
/// **Vertical scope.** Only mounted on childcare-vertical Spaces;
/// the storage layer itself is agnostic — other verticals would
/// register their own intake editors reading their own caps
/// namespace.
///
/// **IEP behaviour.** When the user types IEP notes, `hasIep` is
/// auto-set to `true` so the AlertsSection picks it up. Clearing
/// the notes resets `hasIep` to `false`. The "On an IEP" toggle is
/// thus an emergent property of "did you write notes?" — one less
/// switch for staff to remember.
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
      text: caps.getString(SubjectCaps.medications) ?? '',
    );
    _conditions = TextEditingController(
      text: caps.getString(SubjectCaps.medicalConditions) ?? '',
    );
    _iep = TextEditingController(
      text: caps.getString(SubjectCaps.iepNotes) ?? '',
    );
    _docName = TextEditingController(
      text: caps.getString(SubjectCaps.physicianName) ?? '',
    );
    _docPhone = TextEditingController(
      text: caps.getString(SubjectCaps.physicianPhone) ?? '',
    );
    _emergency = TextEditingController(
      text: caps.getString(SubjectCaps.emergencyInstructions) ?? '',
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final subjectActions = ref.read(subjectActionsProvider);
    final capActions = ref.read(subjectCapActionsProvider);
    try {
      // Allergies stays on its own column path.
      final allergiesText = _allergies.text.trim();
      await subjectActions.update(
        id: widget.subject.id,
        allergies: allergiesText.isEmpty ? null : allergiesText,
      );

      // Everything else: one read-merge-write per key. Slower than a
      // single blob write but keeps concurrent edits to other keys
      // safe.
      await capActions.setStringCap(
        widget.subject.id,
        SubjectCaps.medications,
        _medications.text.trim(),
      );
      await capActions.setStringCap(
        widget.subject.id,
        SubjectCaps.medicalConditions,
        _conditions.text.trim(),
      );

      // IEP notes: auto-link the boolean toggle to whether notes
      // exist. Avoids a second switch the user has to remember.
      final iepText = _iep.text.trim();
      await capActions.setStringCap(
        widget.subject.id,
        SubjectCaps.iepNotes,
        iepText,
      );
      await capActions.setBoolCap(
        subjectId: widget.subject.id,
        key: SubjectCaps.hasIep,
        value: iepText.isNotEmpty,
      );

      await capActions.setStringCap(
        widget.subject.id,
        SubjectCaps.physicianName,
        _docName.text.trim(),
      );
      await capActions.setStringCap(
        widget.subject.id,
        SubjectCaps.physicianPhone,
        _docPhone.text.trim(),
      );
      await capActions.setStringCap(
        widget.subject.id,
        SubjectCaps.emergencyInstructions,
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
                  hintText: 'e.g. Albuterol (as needed), EpiPen Jr',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _conditions,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Medical conditions',
                  hintText: 'e.g. Asthma, type 1 diabetes',
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
                  labelText: 'IEP / 504 notes',
                  hintText: 'What staff should know day-to-day. Adds an '
                      'alert badge automatically.',
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
                      'What to do if something happens. Different from '
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
