import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/supplies/supplies_grouping.dart';
import 'package:differentworld/features/supplies/supplies_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/catalog_card.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, each group's supplies re-lay as a dense
    // responsive grid (2-up on a phone) under their full-width section header,
    // over the SAME grouped rows; off keeps the existing ListTile list.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: [
        if (canEdit)
          PrimaryActionButton(
            tooltip: 'New supply',
            icon: Icons.add,
            onPressed: () => unawaited(context.push('/settings/supplies/new')),
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
                      onPressed: () =>
                          unawaited(context.push('/settings/supplies/new')),
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
          if (bento) {
            return ResponsivePage(
              children: [
                _header(context),
                ..._bentoChildren(context, rows, canEdit, names),
              ],
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

  /// Walk the flat grouped [rows] (a `String` header then its `Supply` rows)
  /// into the bento children: each header is a full-width [_GroupHeader]; each
  /// contiguous run of supplies under it becomes one shrink-wrapped
  /// `GridView.builder` so a supply (a short name + qty/location + an optional
  /// "Low" chip) packs 2-up on a phone. Same data, same grouping, same taps —
  /// only the layout changes.
  ///
  /// One program's inventory is a small bounded set, so a shrink-wrapped grid
  /// per group (the wall-screen pattern) is fine — the outer `ResponsivePage`
  /// ListView still scrolls; the inner grids don't (`NeverScrollablePhysics`),
  /// and the builder still constructs cells on demand.
  List<Widget> _bentoChildren(
    BuildContext context,
    List<Object> rows,
    bool canEdit,
    Map<String, String> names,
  ) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 180,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      // Icon chip + name (2 lines) + a short detail line, growing with text
      // scale so the 2-up phone cell never clips.
      mainAxisExtent: 132 + 40 * scale,
    );
    final children = <Widget>[];
    var i = 0;
    while (i < rows.length) {
      final row = rows[i];
      if (row is String) {
        children.add(_GroupHeader(label: row));
        i++;
        continue;
      }
      // Gather the contiguous run of supplies under the current header.
      final run = <Supply>[];
      while (i < rows.length && rows[i] is Supply) {
        run.add(rows[i] as Supply);
        i++;
      }
      children.add(
        GridView.builder(
          shrinkWrap: true,
          primary: false,
          // The header rows carry their own +16 horizontal inset on top of
          // ResponsivePage's; match it so cards align under the header text.
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: gridDelegate,
          itemCount: run.length,
          itemBuilder: (context, j) {
            final s = run[j];
            return _SupplyGridCard(
              key: ValueKey('supply-${s.id}'),
              supply: s,
              canEdit: canEdit,
              locationNames: names,
            );
          },
        ),
      );
    }
    return children;
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
      onTap: canEdit
          ? () => unawaited(
              context.push('/settings/supplies/${supply.id}/edit'),
            )
          : null,
    );
  }
}

/// The grid-cell form of a supply — the same identity, quantity/location
/// detail, and "Low" signal as [_SupplyTile], packed into a compact tappable
/// card so it fits a fixed grid cell (a `ListTile` does not). Same edit-sheet
/// tap, gated on [canEdit].
class _SupplyGridCard extends StatelessWidget {
  const _SupplyGridCard({
    required this.supply,
    required this.canEdit,
    required this.locationNames,
    super.key,
  });

  final Supply supply;
  final bool canEdit;
  final Map<String, String> locationNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
    return CatalogCard(
      leading: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: low
                ? scheme.errorContainer
                : scheme.surfaceContainerLow,
            child: Icon(
              Icons.inventory_2_outlined,
              color: low ? scheme.onErrorContainer : scheme.onSurfaceVariant,
            ),
          ),
          // The "Low" signal stays a chip (color + label, never color
          // alone — the no-color-only rule).
          if (low) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Low',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      title: supply.name,
      subtitle: subtitle,
      onTap: canEdit
          ? () => unawaited(
              context.push('/settings/supplies/${supply.id}/edit'),
            )
          : null,
    );
  }
}
