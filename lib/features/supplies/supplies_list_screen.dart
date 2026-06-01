import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
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
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/settings/supplies` — the program's inventory catalog (docs/SUPPLIES.md).
/// Three lenses on the same data: by **category**, by **location** (the
/// real Locations catalog — "what's in the Art Barn?"), and **running low**
/// (the restock list). Reached via the omnibox ("supplies" / "inventory").
enum _SuppliesView { category, location, runningLow }

class SuppliesListScreen extends ConsumerStatefulWidget {
  const SuppliesListScreen({super.key});

  @override
  ConsumerState<SuppliesListScreen> createState() => _SuppliesListScreenState();
}

class _SuppliesListScreenState extends ConsumerState<SuppliesListScreen> {
  _SuppliesView _view = _SuppliesView.category;

  @override
  Widget build(BuildContext context) {
    final suppliesAsync = ref.watch(suppliesProvider);
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];
    final names = {for (final l in locations) l.id: l.name};
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
          final rows = switch (_view) {
            _SuppliesView.category => groupSuppliesByCategory(supplies),
            _SuppliesView.location => groupSuppliesByLocation(supplies, names),
            _SuppliesView.runningLow => lowStockSupplies(
              supplies,
            ).cast<Object>(),
          };
          // "Running low" with nothing low → a positive note, not an empty
          // scroll.
          if (_view == _SuppliesView.runningLow && rows.isEmpty) {
            return ResponsivePage.builder(
              itemCount: 2,
              itemBuilder: (_, i) =>
                  i == 0 ? _header(context) : const _AllStockedNote(),
            );
          }
          return ResponsivePage.builder(
            itemCount: rows.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return _header(context);
              final row = rows[i - 1];
              if (row is String) return _GroupHeader(label: row);
              return _SupplyTile(
                supply: row as Supply,
                canEdit: canEdit,
                locationNames: names,
              );
            },
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ContentHeader(
            title: 'Supplies',
            subtitle: 'What your program keeps on hand',
            bottomGap: 8,
          ),
          SegmentedButton<_SuppliesView>(
            segments: const [
              ButtonSegment(
                value: _SuppliesView.category,
                label: Text('Category'),
              ),
              ButtonSegment(
                value: _SuppliesView.location,
                label: Text('Location'),
              ),
              ButtonSegment(
                value: _SuppliesView.runningLow,
                label: Text('Low'),
              ),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ],
      ),
    );
  }
}

class _AllStockedNote extends StatelessWidget {
  const _AllStockedNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            'Nothing is running low',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Set a "flag when below" amount on a supply and it will show up '
            'here when it runs down.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

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
  const _SupplyTile({
    required this.supply,
    required this.canEdit,
    required this.locationNames,
  });

  final Supply supply;
  final bool canEdit;
  final Map<String, String> locationNames;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final low = isLowStock(supply);
    final qty = supply.quantity;
    final qtyLabel = qty == null
        ? null
        : '${formatSupplyNumber(qty)}${supply.unit != null && supply.unit!.isNotEmpty ? ' ${supply.unit}' : ''}';
    final loc = supplyLocationLabel(supply, locationNames);
    final subtitle = [
      ?qtyLabel,
      if (loc != 'No location set') loc,
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: low
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest,
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

Future<String?> openSupplyEditSheet(BuildContext context, {Supply? existing}) {
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
    if (ok) navigator.pop<String>(savedId);
  }

  Future<void> _delete() async {
    final existingId = widget.existing?.id;
    if (existingId == null) return;
    final navigator = Navigator.of(context);
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
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets;
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];
    // Guard against a stale link to a since-deleted location (the dropdown
    // asserts if `value` isn't among its items).
    final validLocId = locations.any((l) => l.id == _locationId)
        ? _locationId
        : null;
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
            // Location lens: link to a real Location (so it shows in that
            // Location's inventory + the "by location" view), plus a
            // free-text sub-spot for the fine detail.
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
