import 'package:differentworld/features/pickup/pickup_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:differentworld/shared/widgets/form_save_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `/subjects/:id/pickup-person` — add or edit one of a child's additional
/// pickup people (name, phone, notes).
///
/// Promoted from `PickupPersonSheet` to a page (CLAUDE.md "No modal is a
/// task"): three text fields in a focus-trapping sheet is exactly the
/// IME-on-a-sheet friction the law removes — and pickup people are
/// child-safety data, so the calm one-thing-at-a-time page is the right home.
///
/// Pure form: it builds a [PickupPerson] and pops it back to the caller (the
/// child's `PickupList`, which inserts it into the JSON list on the subject and
/// saves). `existing` arrives via go_router `extra` for the edit case.
class PickupPersonEditScreen extends StatefulWidget {
  const PickupPersonEditScreen({
    required this.subjectId,
    this.existing,
    super.key,
  });

  final String subjectId;
  final PickupPerson? existing;

  @override
  State<PickupPersonEditScreen> createState() => _PickupPersonEditScreenState();
}

class _PickupPersonEditScreenState extends State<PickupPersonEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final phone = _phone.text.trim();
    final notes = _notes.text.trim();
    final person = PickupPerson(
      name: name,
      phone: phone.isEmpty ? null : phone,
      notes: notes.isEmpty ? null : notes,
    );
    final goRouter = GoRouter.of(context);
    // Pop the built person back to the caller (PickupList saves it). A cold
    // deep-link has no caller to receive it — return to the child rather than
    // dead-end on the form.
    if (goRouter.canPop()) {
      goRouter.pop(person);
    } else {
      goRouter.go('/subjects/${widget.subjectId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return EdgeScaffold(
      backFallbackRoute: '/subjects/${widget.subjectId}',
      body: FormBody(
        children: [
          ContentHeader(
            title: isEdit ? 'Edit pickup person' : 'Add pickup person',
          ),
          TextField(
            controller: _name,
            autofocus: !isEdit,
            textCapitalization: TextCapitalization.words,
            // Pickup people often come from a parent's address book — autofill
            // cuts a lot of typing when grandma / a babysitter is added.
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (e.g. "Picks up Wednesdays")',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          // Disabled until there's a name — no silent no-op tap.
          FormSaveButton(
            requiredField: _name,
            onSave: _save,
            label: isEdit ? 'Save' : 'Add',
          ),
        ],
      ),
    );
  }
}
