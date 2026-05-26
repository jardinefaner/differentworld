import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Editor for a Subject's health profile — allergies + medications +
/// conditions + IEP/504 + physician + emergency instructions.
///
/// Promoted from `health_profile_sheet.dart` (Wave 12 → bottom-sheet)
/// to the `/subjects/:id/health` route in Wave 27. Subject passed
/// via go_router `extra` so we don't re-fetch by id.
///
/// **Storage shape.** Writes to the existing `SubjectCaps` keys on
/// `subjects.capabilities` JSONB. Allergies still rides its own
/// `subjects.allergies` text column for backward compat with the
/// roster and other call sites that touch the column directly.
///
/// **IEP behaviour.** When the user types IEP notes, `hasIep` is
/// auto-set to `true` so the AlertsSection picks it up. Clearing
/// the notes resets `hasIep` to `false`. One less switch staff
/// have to remember.
class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({required this.subject, super.key});

  final Subject subject;

  @override
  ConsumerState<HealthProfileScreen> createState() =>
      _HealthProfileScreenState();
}

class _HealthProfileScreenState extends ConsumerState<HealthProfileScreen> {
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
    final goRouter = GoRouter.of(context);
    final subjectActions = ref.read(subjectActionsProvider);
    final capActions = ref.read(subjectCapActionsProvider);
    try {
      // Allergies stays on its own column path.
      final allergiesText = _allergies.text.trim();
      await subjectActions.update(
        id: widget.subject.id,
        allergies: allergiesText.isEmpty ? null : allergiesText,
      );

      // Everything else: read-merge-write per key. Slower than a
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
      // exist.
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
      if (goRouter.canPop()) goRouter.pop();
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
    final s = widget.subject;
    return EdgeScaffold(
      body: FormBody(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ContentHeader(
            title: 'Health & medical',
            subtitle: '${s.firstName} ${s.lastName}',
          ),
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
                  // Wave 125: physician's name — parents often have
                  // it saved in contacts. Generic `name` hint.
                  autofillHints: const [AutofillHints.name],
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
                  autofillHints: const [AutofillHints.telephoneNumber],
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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
    );
  }
}
