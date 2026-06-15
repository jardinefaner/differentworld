import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The context pill — makes the cockpit lead's INFERRED context visible and
/// correctable. It shows the room + block the lead is currently reading from;
/// tapping it opens a picker to pin a different room (or fall back to "across
/// your rooms"). Renders only for multi-room staff — with a single room there
/// is nothing to switch between, and the lead already reflects it.
///
/// Pairs with [contextRoomOverrideProvider]: picking a room pins the lead to
/// that room's live block for the session.
class ContextPill extends ConsumerWidget {
  const ContextPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (!viewer.isDailyLogger) return const SizedBox.shrink();
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    // The override only means something with more than one room.
    if (groups.length < 2) return const SizedBox.shrink();

    final override = ref.watch(contextRoomOverrideProvider);
    final live = override == null
        ? ref.watch(liveBlockProvider)
        : ref.watch(liveBlockForGroupProvider(override));

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Group? roomById(String id) {
      for (final g in groups) {
        if (g.id == id) return g;
      }
      return null;
    }

    // Resolve the label and whether we're in the amber "nothing to act on"
    // state (a pinned room with no block, or no live block program-wide).
    final String label;
    final bool empty;
    if (override != null) {
      final room = roomById(override);
      if (room == null) {
        label = 'Pick a room';
        empty = true;
      } else {
        label = live != null
            ? '${room.name} · ${live.title}'
            : '${room.name} · no block now';
        empty = live == null;
      }
    } else if (live != null) {
      final room = roomById(live.groupId);
      label = room == null ? 'Across your rooms' : '${room.name} · ${live.title}';
      empty = false;
    } else {
      label = 'No block now · pick a room';
      empty = true;
    }

    final fg = empty ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;
    final bg = empty
        ? scheme.tertiaryContainer.withValues(alpha: 0.55)
        : scheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: bg,
          shape: StadiumBorder(side: BorderSide(color: fg.withValues(alpha: 0.22))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(_showRoomPicker(context, ref, groups, override));
            },
            child: ConstrainedBox(
              // ≥48dp tap target (a11y floor), even though the pill reads small.
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      empty
                          ? Icons.wrong_location_outlined
                          : Icons.place_outlined,
                      size: 15,
                      color: fg,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, size: 16, color: fg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRoomPicker(
    BuildContext context,
    WidgetRef ref,
    List<Group> groups,
    String? current,
  ) {
    return showGlassSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GlassDragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Where are you right now?',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            _PickerRow(
              label: 'Across your rooms',
              subtitle: 'Auto — whatever’s live now',
              selected: current == null,
              onTap: () {
                ref.read(contextRoomOverrideProvider.notifier).pin(null);
                Navigator.of(ctx).pop();
              },
            ),
            for (final g in groups)
              _RoomPickerRow(
                group: g,
                selected: current == g.id,
                onTap: () {
                  ref.read(contextRoomOverrideProvider.notifier).pin(g.id);
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// One room row in the picker, showing what's live in that room as the
/// subtitle so the choice is informed.
class _RoomPickerRow extends ConsumerWidget {
  const _RoomPickerRow({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final Group group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveBlockForGroupProvider(group.id));
    return _PickerRow(
      label: group.name,
      subtitle: live != null ? 'Now: ${live.title}' : 'Nothing live right now',
      selected: selected,
      onTap: onTap,
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected ? scheme.primary : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
