import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/supplies/supplies_grouping.dart';
import 'package:differentworld/features/supplies/supplies_providers.dart';
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

/// `/settings/supplies/new` + `/settings/supplies/:id/edit` — create or edit
/// a supply in the program's inventory catalog (docs/SUPPLIES.md).
///
/// Promoted from the `_SupplyEditSheet` bottom sheet to a route (CLAUDE.md
/// "No modal is a task"): filling a form is a task, so it belongs on a
/// deep-linkable page, not a focus-trapping sheet. Saving pops the new/edited
/// supply id back to the caller for parity with the locations conversion (no
/// current caller consumes it, but the contract stays the same).
class SupplyEditScreen extends ConsumerWidget {
  const SupplyEditScreen({this.supplyId, super.key});

  /// Null → create. Non-null → edit; the row is resolved live from
  /// [suppliesProvider] so a cold deep-link to `:id/edit` still works.
  final String? supplyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (supplyId == null) {
      return const _SupplyEditForm(existing: null);
    }
    return ref
        .watch(suppliesProvider)
        .when(
          loading: () => const EdgeScaffold(
            backFallbackRoute: '/settings/supplies',
            body: LoadingSlot(),
          ),
          error: (_, _) => EdgeScaffold(
            backFallbackRoute: '/settings/supplies',
            body: ErrorState(
              title: 'Could not load supply',
              onRetry: () => ref.invalidate(suppliesProvider),
            ),
          ),
          data: (supplies) {
            Supply? existing;
            for (final s in supplies) {
              if (s.id == supplyId) {
                existing = s;
                break;
              }
            }
            if (existing == null) {
              return const EdgeScaffold(
                backFallbackRoute: '/settings/supplies',
                body: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Supply not found',
                  message: 'It may have been removed.',
                ),
              );
            }
            return _SupplyEditForm(existing: existing);
          },
        );
  }
}

class _SupplyEditForm extends ConsumerStatefulWidget {
  const _SupplyEditForm({required this.existing});

  final Supply? existing;

  @override
  ConsumerState<_SupplyEditForm> createState() => _SupplyEditFormState();
}

class _SupplyEditFormState extends ConsumerState<_SupplyEditForm> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _location;
  late final TextEditingController _lowStock;
  late final TextEditingController _notes;
  String? _locationId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _quantity = TextEditingController(
      text: e?.quantity == null ? '' : formatSupplyNumber(e!.quantity!),
    );
    _unit = TextEditingController(text: e?.unit ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _lowStock = TextEditingController(
      text: e?.lowStockThreshold == null
          ? ''
          : formatSupplyNumber(e!.lowStockThreshold!),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _locationId = e?.locationId;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _quantity.dispose();
    _unit.dispose();
    _location.dispose();
    _lowStock.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    setState(() => _saving = true);
    final actions = ref.read(supplyActionsProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final goRouter = GoRouter.of(context);
    final existingId = widget.existing?.id;
    String? trimOrNull(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final category = trimOrNull(_category);
    final unit = trimOrNull(_unit);
    final location = trimOrNull(_location);
    final notes = trimOrNull(_notes);
    final quantity = parseSupplyAmount(_quantity.text);
    final lowStock = parseSupplyAmount(_lowStock.text);
    final pickedLoc = _locationId;
    String? savedId;
    final ok = await runReported(
      library: 'supplies',
      messenger: messenger,
      onError: 'Could not save the supply.',
      action: () async {
        if (existingId == null) {
          savedId = await actions.create(
            name: n,
            category: category,
            quantity: quantity,
            unit: unit,
            location: location,
            locationId: pickedLoc,
            lowStockThreshold: lowStock,
            notes: notes,
          );
        } else {
          savedId = existingId;
          await actions.update_(
            id: existingId,
            name: n,
            category: category,
            quantity: quantity,
            unit: unit,
            location: location,
            locationId: pickedLoc,
            clearLocationId: pickedLoc == null,
            lowStockThreshold: lowStock,
            notes: notes,
          );
        }
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    // Pop the new/edited id back for parity with the locations conversion. A
    // cold deep-link to this page has no back stack — fall back to the list so
    // a successful save is never a silent no-op.
    if (goRouter.canPop()) {
      goRouter.pop(savedId);
    } else {
      goRouter.go('/settings/supplies');
    }
  }

  Future<void> _delete() async {
    final existingId = widget.existing?.id;
    if (existingId == null) return;
    final goRouter = GoRouter.of(context);
    // A supply delete is a CASCADE — it removes the supply AND its
    // activity_supplies links, so a single re-insert can't restore the tree.
    // Keep the confirm wall (CLAUDE.md: confirmDestructive is correct for
    // cascading deletes; deleteWithUndo is not).
    final confirm = await confirmDestructive(
      context,
      title: 'Remove this supply?',
      message:
          'It disappears from the inventory, and any activities that '
          'reference it lose the link.',
      confirmLabel: 'Remove',
    );
    if (!confirm || !mounted) return;
    await ref.read(supplyActionsProvider).delete_(existingId);
    if (!mounted) return;
    if (goRouter.canPop()) {
      goRouter.pop();
    } else {
      goRouter.go('/settings/supplies');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];
    // Guard against a stale link to a since-deleted location (the dropdown
    // asserts if `value` isn't among its items).
    final validLocId = locations.any((l) => l.id == _locationId)
        ? _locationId
        : null;
    return EdgeScaffold(
      backFallbackRoute: '/settings/supplies',
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
          ContentHeader(title: isEdit ? 'Edit supply' : 'New supply'),
          TextField(
            controller: _name,
            autofocus: !isEdit,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Washable markers · Construction paper',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _category,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Category (optional)',
              hintText: 'Art · Sports · Snack',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'e.g. 12',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'boxes · reams',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Location lens: link to a real Location (so it shows in that
          // Location's inventory + the "by location" view), plus a free-text
          // sub-spot for the fine detail.
          DropdownButtonFormField<String?>(
            initialValue: validLocId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: locations.isEmpty
                  ? 'Location (add Locations first)'
                  : 'Location (optional)',
              border: const OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(child: Text('— None —')),
              for (final l in locations)
                DropdownMenuItem<String?>(value: l.id, child: Text(l.name)),
            ],
            onChanged: (v) => setState(() => _locationId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Spot (optional)',
              hintText: 'Cabinet B · shelf 2',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lowStock,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Flag as low when below (optional)',
              hintText: 'e.g. 3',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
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
                label: Text(isEdit ? 'Save' : 'Add supply'),
              );
            },
          ),
        ],
      ),
    );
  }
}
