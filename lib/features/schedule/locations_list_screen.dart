import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
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

/// `/settings/locations` — registry of physical places activities
/// happen. Authoritative for both the activity edit screen (where each
/// activity picks a default location) and the schedule block sheet
/// (which can override the location per block).
class LocationsListScreen extends ConsumerWidget {
  const LocationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsProvider);
    final canEdit = ref.watch(viewerProvider).canManageSpace;
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the locations re-lay as a dense
    // responsive card grid (2-up on a phone) over the SAME provider data; off
    // keeps the existing ListTile list.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: [
        if (canEdit)
          PrimaryActionButton(
            tooltip: 'New location',
            icon: Icons.add,
            onPressed: () => _openEditSheet(context),
          ),
      ],
      body: locationsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load locations',
          onRetry: () => ref.invalidate(locationsProvider),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return EmptyState(
              icon: Icons.place_outlined,
              title: 'No locations yet',
              message:
                  'Add the places activities happen — pool, art barn, '
                  'archery range. Activities reuse them; the scheduler '
                  'warns when a cohort is booked into a too-small room.',
              action: canEdit
                  ? FilledButton.icon(
                      onPressed: () => _openEditSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add location'),
                    )
                  : null,
            );
          }
          if (bento) {
            return ResponsivePage(
              children: [
                const ContentHeader(
                  title: 'Locations',
                  subtitle: 'Where activities happen on camp grounds',
                  bottomGap: 8,
                ),
                _LocationsBentoGrid(locations: locations, canEdit: canEdit),
              ],
            );
          }
          return ResponsivePage.builder(
            itemCount: locations.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Locations',
                    subtitle: 'Where activities happen on camp grounds',
                    bottomGap: 8,
                  ),
                );
              }
              return _LocationTile(
                location: locations[i - 1],
                canEdit: canEdit,
              );
            },
          );
        },
      ),
    );
  }
}

/// The bento variant — SAME locations, re-laid as a dense responsive
/// `GridView.builder`. A location is short (a name + a "cap. 24 · outdoor"
/// line), so a 180dp max-extent packs them 2-up on a phone. A `ListTile` is
/// list-shaped and overflows a fixed grid cell (the GRID.md gotcha), so each
/// cell uses a compact card (icon + name + subtitle) instead — same data,
/// same tap.
class _LocationsBentoGrid extends StatelessWidget {
  const _LocationsBentoGrid({required this.locations, required this.canEdit});

  final List<Location> locations;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Icon chip + name (2 lines) + a short subtitle, growing with text
        // scale so the 2-up phone cell never clips.
        mainAxisExtent: 132 + 40 * scale,
      ),
      itemCount: locations.length,
      itemBuilder: (context, i) {
        final l = locations[i];
        return _LocationGridCard(
          key: ValueKey('location-${l.id}'),
          location: l,
          canEdit: canEdit,
        );
      },
    );
  }
}

/// The grid-cell form of a location — the same identity + subtitle as
/// [_LocationTile], packed into a compact tappable card so it fits a fixed
/// grid cell (a `ListTile` does not). Same edit-sheet tap, gated on [canEdit].
class _LocationGridCard extends StatelessWidget {
  const _LocationGridCard({
    required this.location,
    required this.canEdit,
    super.key,
  });

  final Location location;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isOutdoor = location.isOutdoor == 1;
    final cap = location.capacity;
    final subtitle = [
      if (cap != null) 'cap. $cap',
      if (isOutdoor) 'outdoor',
      if (location.notes != null && location.notes!.isNotEmpty) location.notes!,
    ].join(' · ');
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isOutdoor
                ? scheme.tertiaryContainer
                : scheme.surfaceContainerLow,
            child: Icon(
              isOutdoor ? Icons.park_outlined : Icons.home_work_outlined,
              color: isOutdoor
                  ? scheme.onTertiaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            location.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: canEdit
          ? InkWell(
              onTap: () => _openEditSheet(context, existing: location),
              child: content,
            )
          : content,
    );
  }
}

class _LocationTile extends ConsumerWidget {
  const _LocationTile({required this.location, required this.canEdit});

  final Location location;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isOutdoor = location.isOutdoor == 1;
    final cap = location.capacity;
    final subtitle = [
      if (cap != null) 'cap. $cap',
      if (isOutdoor) 'outdoor',
      if (location.notes != null && location.notes!.isNotEmpty) location.notes!,
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isOutdoor
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        child: Icon(
          isOutdoor ? Icons.park_outlined : Icons.home_work_outlined,
          color: isOutdoor
              ? scheme.onTertiaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(location.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: canEdit ? const Icon(Icons.chevron_right) : null,
      onTap: canEdit ? () => _openEditSheet(context, existing: location) : null,
    );
  }
}

/// Opens the location edit sheet. Returns the location id on save —
/// callers that opened the sheet from an inline "+ New location"
/// dropdown sentinel use the return to auto-select the newly created
/// row. Returns null when the user dismisses without saving.
Future<String?> openLocationEditSheet(
  BuildContext context, {
  Location? existing,
}) {
  return showGlassSheet<String?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LocationEditSheet(existing: existing),
  );
}

Future<void> _openEditSheet(
  BuildContext context, {
  Location? existing,
}) async {
  await openLocationEditSheet(context, existing: existing);
}

class _LocationEditSheet extends ConsumerStatefulWidget {
  const _LocationEditSheet({this.existing});

  final Location? existing;

  @override
  ConsumerState<_LocationEditSheet> createState() => _LocationEditSheetState();
}

class _LocationEditSheetState extends ConsumerState<_LocationEditSheet> {
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
    final navigator = Navigator.of(context);
    final existingId = widget.existing?.id;
    String? savedId;
    final ok = await runReported(
      library: 'locations',
      messenger: messenger,
      onError: 'Could not save the location.',
      action: () async {
        if (existingId == null) {
          // Capture the new id so inline-create callers (block edit
          // sheet's "+ New location" sentinel) can auto-select.
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
    if (ok) navigator.pop<String>(savedId);
  }

  Future<void> _delete() async {
    final existingId = widget.existing?.id;
    if (existingId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this location?'),
        content: const Text(
          'Activities that pointed to it stay; their default location '
          'becomes unset.',
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
    await ref.read(locationActionsProvider).delete_(existingId);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'New location' : 'Edit location',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: widget.existing == null,
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
    );
  }
}
