import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/supplies/supplies_grouping.dart';
import 'package:differentworld/features/supplies/supplies_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/settings/supplies` — the program's inventory catalog
/// (docs/SUPPLIES.md). Maintain it once; slice 2 lets activities reference
/// items by id ("you'll need 12 markers"). Reached via the omnibox
/// (type "supplies" / "inventory"), matching the Locations / Activities
/// libraries.
class SuppliesListScreen extends ConsumerWidget {
  const SuppliesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliesAsync = ref.watch(suppliesProvider);
    final canEdit = ref.watch(viewerProvider).canManageSpace;
    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: [
        if (canEdit)
          PrimaryActionButton(
            tooltip: 'New supply',
            icon: Icons.add,
            onPressed: () => _openEditSheet(context),
          ),
      ],
      body: suppliesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load supplies',
          onRetry: () => ref.invalidate(suppliesProvider),
        ),
        data: (supplies) {
          if (supplies.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No supplies yet',
              message:
                  'Add what your program keeps on hand — markers, paper, '
                  'balls, craft kits. Maintain the list once; activities '
                  'can reference it so a plan shows what you need.',
              action: canEdit
                  ? FilledButton.icon(
                      onPressed: () => _openEditSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add supply'),
                    )
                  : null,
            );
          }
          // Flatten into header + tile rows (a header whenever the
          // category changes — the DAO orders by category then name).
          final rows = groupSuppliesByCategory(supplies);
          return ResponsivePage.builder(
            itemCount: rows.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Supplies',
                    subtitle: 'What your program keeps on hand',
                    bottomGap: 8,
                  ),
                );
              }
              final row = rows[i - 1];
              if (row is String) return _CategoryHeader(label: row);
              return _SupplyTile(supply: row as Supply, canEdit: canEdit);
            },
          );
        },
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SupplyTile extends StatelessWidget {
  const _SupplyTile({required this.supply, required this.canEdit});

  final Supply supply;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final low = isLowStock(supply);
    final qty = supply.quantity;
    final qtyLabel = qty == null
        ? null
        : '${formatSupplyNumber(qty)}${supply.unit != null && supply.unit!.isNotEmpty ? ' ${supply.unit}' : ''}';
    final subtitle = [
      ?qtyLabel,
      if (supply.location != null && supply.location!.isNotEmpty)
        supply.location!,
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: low ? scheme.errorContainer : scheme.surfaceContainerHighest,
        child: Icon(
          Icons.inventory_2_outlined,
          color: low ? scheme.onErrorContainer : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(supply.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: low
          ? Chip(
              label: const Text('Low'),
              visualDensity: VisualDensity.compact,
              backgroundColor: scheme.errorContainer,
              labelStyle: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide.none,
            )
          : (canEdit ? const Icon(Icons.chevron_right) : null),
      onTap: canEdit ? () => _openEditSheet(context, existing: supply) : null,
    );
  }
}

Future<String?> openSupplyEditSheet(
  BuildContext context, {
  Supply? existing,
}) {
  return showGlassSheet<String?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SupplyEditSheet(existing: existing),
  );
}

Future<void> _openEditSheet(BuildContext context, {Supply? existing}) async {
  await openSupplyEditSheet(context, existing: existing);
}

class _SupplyEditSheet extends ConsumerStatefulWidget {
  const _SupplyEditSheet({this.existing});

  final Supply? existing;

  @override
  ConsumerState<_SupplyEditSheet> createState() => _SupplyEditSheetState();
}

class _SupplyEditSheetState extends ConsumerState<_SupplyEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _location;
  late final TextEditingController _lowStock;
  late final TextEditingController _notes;
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
    final navigator = Navigator.of(context);
    final existingId = widget.existing?.id;
    String? trimOrNull(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final category = trimOrNull(_category);
    final unit = trimOrNull(_unit);
    final location = trimOrNull(_location);
    final notes = trimOrNull(_notes);
    final quantity = double.tryParse(_quantity.text.trim());
    final lowStock = double.tryParse(_lowStock.text.trim());
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
            lowStockThreshold: lowStock,
            notes: notes,
          );
        }
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop<String>(savedId);
  }

  Future<void> _delete() async {
    final existingId = widget.existing?.id;
    if (existingId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this supply?'),
        content: const Text(
          'It disappears from the inventory. Activities that referenced it '
          '(later) would lose the link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    await ref.read(supplyActionsProvider).delete_(existingId);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + insets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'New supply' : 'Edit supply',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
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
            TextField(
              controller: _location,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Where it lives (optional)',
                hintText: 'Cabinet B · Gym closet',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lowStock,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
