import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modal bottom sheet for creating or editing a Subject ("Student" in
/// v1 UI). Pass an existing `subject` to edit, or null with a
/// `groupId` to create.
class SubjectFormSheet extends ConsumerStatefulWidget {
  const SubjectFormSheet({
    required this.groupId,
    this.subject,
    super.key,
  });

  final String groupId;
  final Subject? subject;

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    Subject? subject,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          SubjectFormSheet(groupId: groupId, subject: subject),
    );
  }

  @override
  ConsumerState<SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends ConsumerState<SubjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _allergies;
  late final TextEditingController _notes;
  DateTime? _dob;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.subject != null;

  bool _isDirty() {
    final s = widget.subject;
    final dobIso = _dob == null
        ? null
        : '${_dob!.year.toString().padLeft(4, '0')}-'
            '${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}';
    if (s == null) {
      // New: dirty if anything has been typed.
      return _firstName.text.trim().isNotEmpty ||
          _lastName.text.trim().isNotEmpty ||
          _allergies.text.trim().isNotEmpty ||
          _notes.text.trim().isNotEmpty ||
          _dob != null;
    }
    return _firstName.text.trim() != s.firstName ||
        _lastName.text.trim() != s.lastName ||
        _allergies.text.trim() != (s.allergies ?? '') ||
        _notes.text.trim() != (s.notes ?? '') ||
        dobIso != s.dob;
  }

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.subject?.firstName ?? '');
    _lastName = TextEditingController(text: widget.subject?.lastName ?? '');
    _allergies = TextEditingController(text: widget.subject?.allergies ?? '');
    _notes = TextEditingController(text: widget.subject?.notes ?? '');
    final dobIso = widget.subject?.dob;
    _dob = dobIso == null ? null : DateTime.tryParse(dobIso);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _allergies.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 3, now.month, now.day),
      firstDate: DateTime(now.year - 12),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final actions = ref.read(subjectActionsProvider);
      final dob = _dob?.toIso8601String().substring(0, 10);
      final allergiesText = _allergies.text.trim();
      final notesText = _notes.text.trim();
      final allergies = allergiesText.isEmpty ? null : allergiesText;
      final notes = notesText.isEmpty ? null : notesText;

      if (_isEdit) {
        await actions.update(
          id: widget.subject!.id,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          dob: dob,
          allergies: allergies,
          notes: notes,
        );
      } else {
        await actions.create(
          groupId: widget.groupId,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          dob: dob,
          allergies: allergies,
          notes: notes,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'subjects'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final subject = widget.subject;
    if (subject == null) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove this student?',
      message:
          'Removing ${subject.firstName} ${subject.lastName} hides them '
          'from attendance and the classroom roster. Their history stays '
          'in your records.',
      confirmLabel: 'Remove student',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(subjectActionsProvider).delete(subject.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'subjects'),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not remove. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DismissGuard(
      isDirty: _isDirty,
      child: Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    _isEdit ? 'Edit student' : 'New student',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstName,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'First name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastName,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Last name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDob,
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of birth (optional)',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        _dob == null ? 'Tap to choose' : _formatDob(_dob!),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _allergies,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Allergies (optional)',
                      hintText: 'e.g. Peanuts, dairy',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (_isEdit)
                        DestructiveButton(
                          label: 'Remove',
                          onPressed: _saving ? null : _delete,
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isEdit ? 'Save' : 'Add student'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  static String _formatDob(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
