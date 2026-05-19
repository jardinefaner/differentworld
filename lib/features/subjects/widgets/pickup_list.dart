import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/pickup/pickup_providers.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PickupList extends ConsumerWidget {
  const PickupList({required this.subject, super.key});

  final Subject subject;

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref, {
    int? editIndex,
  }) async {
    final all = pickupPeopleFor(subject);
    final existing = editIndex == null ? null : all[editIndex];
    final result = await PickupPersonSheet.show(context, existing: existing);
    if (result == null) return;
    final next = [...all];
    if (editIndex == null) {
      next.add(result);
    } else {
      next[editIndex] = result;
    }
    await ref
        .read(pickupActionsProvider)
        .setPickupPeople(subjectId: subject.id, people: next);
  }

  Future<void> _remove(WidgetRef ref, int idx) async {
    final all = pickupPeopleFor(subject);
    final next = [...all]..removeAt(idx);
    await ref
        .read(pickupActionsProvider)
        .setPickupPeople(subjectId: subject.id, people: next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final canEdit = viewer.canEditPickupFor(subject.id);
    final people = pickupPeopleFor(subject);

    if (people.isEmpty && !canEdit) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          'No additional pickup people on file.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < people.length; i++)
          ListTile(
            leading: PersonAvatar(name: people[i].name),
            title: Text(people[i].name),
            subtitle: Text(
              [
                people[i].phone,
                people[i].notes,
              ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
            ),
            trailing: canEdit
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () =>
                            _addOrEdit(context, ref, editIndex: i),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => _remove(ref, i),
                      ),
                    ],
                  )
                : null,
            onTap: canEdit ? () => _addOrEdit(context, ref, editIndex: i) : null,
          ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addOrEdit(context, ref),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add pickup person'),
              ),
            ),
          ),
      ],
    );
  }
}

class PickupPersonSheet extends StatefulWidget {
  const PickupPersonSheet({super.key, this.existing});

  final PickupPerson? existing;

  static Future<PickupPerson?> show(
    BuildContext context, {
    PickupPerson? existing,
  }) {
    return showModalBottomSheet<PickupPerson>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PickupPersonSheet(existing: existing),
    );
  }

  @override
  State<PickupPersonSheet> createState() => PickupPersonSheetState();
}

class PickupPersonSheetState extends State<PickupPersonSheet> {
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
    Navigator.of(context).pop(
      PickupPerson(
        name: name,
        phone: phone.isEmpty ? null : phone,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                widget.existing == null ? 'Add pickup person' : 'Edit pickup person',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
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
