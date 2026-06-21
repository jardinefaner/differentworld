import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/settings/locations/new` + `/settings/locations/:id/edit` — create or
/// edit a physical place activities happen (pool, art barn, north trail).
///
/// Promoted from the `_LocationEditSheet` bottom sheet to a route (CLAUDE.md
/// "No modal is a task"): filling a form is a task, so it belongs on a
/// deep-linkable page, not a focus-trapping sheet. Saving pops the new/edited
/// location id back to the caller, so the schedule-block + activity edit
/// screens' inline "+ New location" pickers still auto-select what you just
/// made.
class LocationEditScreen extends ConsumerWidget {
  const LocationEditScreen({this.locationId, super.key});

  /// Null → create. Non-null → edit; the row is resolved live from
  /// [locationsProvider] so a cold deep-link to `:id/edit` still works.
  final String? locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (locationId == null) {
      return const _LocationEditForm(existing: null);
    }
    return ref
        .watch(locationsProvider)
        .when(
          loading: () => const EdgeScaffold(
            backFallbackRoute: '/settings/locations',
            body: LoadingSlot(),
          ),
          error: (_, _) => EdgeScaffold(
            backFallbackRoute: '/settings/locations',
            body: ErrorState(
              title: 'Could not load location',
              onRetry: () => ref.invalidate(locationsProvider),
            ),
          ),
          data: (locations) {
            Location? existing;
            for (final l in locations) {
              if (l.id == locationId) {
                existing = l;
                break;
              }
            }
            if (existing == null) {
              return const EdgeScaffold(
                backFallbackRoute: '/settings/locations',
                body: EmptyState(
                  icon: Icons.place_outlined,
                  title: 'Location not found',
                  message: 'It may have been removed.',
                ),
              );
            }
            return _LocationEditForm(existing: existing);
          },
        );
  }
}

class _LocationEditForm extends ConsumerStatefulWidget {
  const _LocationEditForm({required this.existing});

  final Location? existing;

  @override
  ConsumerState<_LocationEditForm> createState() => _LocationEditFormState();
}

class _LocationEditFormState extends ConsumerState<_LocationEditForm> {
  late final TextEditingController _name;
  late final TextEditingController _capacity;
  late final TextEditingController _notes;
  late bool _isOutdoor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _capacity = TextEditingController(
      text: e?.capacity == null ? '' : e!.capacity!.toString(),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _isOutdoor = e?.isOutdoor == 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    setState(() => _saving = true);
    final actions = ref.read(locationActionsProvider);
    final capacity = int.tryParse(_capacity.text.trim());
    final notes = _notes.text.trim();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final goRouter = GoRouter.of(context);
    final existingId = widget.existing?.id;
    String? savedId;
    final ok = await runReported(
      library: 'locations',
      messenger: messenger,
      onError: 'Could not save the location.',
      action: () async {
        if (existingId == null) {
          savedId = await actions.create(
            name: n,
            capacity: capacity,
            notes: notes.isEmpty ? null : notes,
            isOutdoor: _isOutdoor,
          );
        } else {
          savedId = existingId;
          await actions.update_(
            id: existingId,
            name: n,
            capacity: capacity,
            notes: notes.isEmpty ? null : notes,
            isOutdoor: _isOutdoor,
          );
        }
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    // Pop the new/edited id back so an inline "+ New location" picker (block
    // or activity edit) can auto-select what was just created. A cold
    // deep-link to this page has no back stack — fall back to the list so a
    // successful save is never a silent no-op.
    if (goRouter.canPop()) {
      goRouter.pop(savedId);
    } else {
      goRouter.go('/settings/locations');
    }
  }

  Future<void> _delete() async {
    final row = widget.existing;
    if (row == null) return;
    final goRouter = GoRouter.of(context);
    // Reversible — activities that pointed here just lose their default
    // location (no cascade) — so delete now and offer Undo (re-inserts the
    // row; stable UUID re-syncs everywhere). No confirm wall.
    await deleteWithUndo(
      context,
      label: row.name,
      message: 'Removed ${row.name}',
      onDelete: () => ref.read(locationActionsProvider).delete_(row.id),
      onUndo: () => ref.read(locationActionsProvider).restore(row),
    );
    if (!mounted) return;
    if (goRouter.canPop()) {
      goRouter.pop();
    } else {
      goRouter.go('/settings/locations');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return EdgeScaffold(
      backFallbackRoute: '/settings/locations',
      actions: [
        if (isEdit)
          IconButton(
            tooltip: 'Remove',
            icon: Icon(Icons.delete_outline, color: scheme.error),
            onPressed: _saving ? null : _delete,
          ),
      ],
      body: FormBody(
        children: [
          ContentHeader(title: isEdit ? 'Edit location' : 'New location'),
          TextField(
            controller: _name,
            autofocus: !isEdit,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Pool · Art barn · North trail',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity',
                    hintText: 'e.g. 24',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Outdoor'),
                  value: _isOutdoor,
                  onChanged: (v) => setState(() => _isOutdoor = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. near parking lot · ring the bell',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          // Disabled until there's a name — no silent no-op tap.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _name,
            builder: (context, value, _) {
              final canSave = !_saving && value.text.trim().isNotEmpty;
              return FilledButton.icon(
                onPressed: canSave ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(isEdit ? 'Save' : 'Add location'),
              );
            },
          ),
        ],
      ),
    );
  }
}
