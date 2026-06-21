import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/pickup/pickup_providers.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A child's additional pickup people. Add / edit each one on the
/// `/subjects/:id/pickup-person` PAGE (`PickupPersonEditScreen`) — not a
/// sheet (CLAUDE.md "No modal is a task"). The page pops a [PickupPerson] back
/// here; this widget owns the list math (insert / replace / remove) and the
/// save through [pickupActionsProvider].
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
    final result = await context.push<PickupPerson>(
      '/subjects/${subject.id}/pickup-person',
      extra: existing,
    );
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
                        onPressed: () => _addOrEdit(context, ref, editIndex: i),
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
            onTap: canEdit
                ? () => _addOrEdit(context, ref, editIndex: i)
                : null,
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
