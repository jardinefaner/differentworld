import 'dart:async';
import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/activity_runtime/roles.dart';
import 'package:differentworld/features/missions/do_board_providers.dart';
import 'package:differentworld/features/missions/missions_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mission ids completed *today* — drives the board's hide-on-done.
// ignore: specify_nonobvious_property_types
final _doneMissionIdsTodayProvider = Provider.autoDispose<Set<String>>((ref) {
  final completions =
      ref.watch(missionCompletionsProvider).value ?? const <Entry>[];
  final today = todayKey();
  final ids = <String>{};
  for (final e in completions) {
    final local = DateTime.tryParse(e.recordedAt)?.toLocal();
    if (local == null || dateKey(local) != today) continue;
    try {
      final d = jsonDecode(e.details);
      if (d is Map && d['missionId'] is String) {
        ids.add(d['missionId'] as String);
      }
    } on FormatException {
      // Tolerate a malformed row.
    }
  }
  return ids;
});

/// One thing to do on the board — a mission or a role, unified so the
/// board doesn't care which.
class _BoardItem {
  const _BoardItem({
    required this.key,
    required this.emoji,
    required this.label,
    required this.complete,
    this.onRemove,
  });

  final String key;
  final String emoji;
  final String label;
  final Future<void> Function() complete;
  final VoidCallback? onRemove;
}

/// The **Do board** (docs/ACTION_WORDS.md "doing clears to zero"): the
/// room's missions AND today's roles as big image-buttons, not a list. Tap
/// one → it shrinks away and the board drains toward **tasks zero**.
class MissionBoardScreen extends ConsumerStatefulWidget {
  const MissionBoardScreen({super.key});

  @override
  ConsumerState<MissionBoardScreen> createState() => _MissionBoardScreenState();
}

class _MissionBoardScreenState extends ConsumerState<MissionBoardScreen> {
  final Set<String> _completing = {};

  void _tap(_BoardItem item) {
    if (_completing.contains(item.key)) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _completing.add(item.key));
  }

  Future<void> _finish(_BoardItem item) async {
    await item.complete();
    if (mounted) setState(() => _completing.remove(item.key));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missionsAsync = ref.watch(missionsProvider);
    final doneIds = ref.watch(_doneMissionIdsTodayProvider);
    final roles = ref.watch(activeRolesTodayProvider).value ?? const <ActiveRole>[];

    return EdgeScaffold(
      actions: [
        IconButton(
          tooltip: 'Add a role',
          icon: const Icon(Icons.add),
          onPressed: _openRolePicker,
        ),
        const SyncStatusIndicator(),
      ],
      body: missionsAsync.when(
        loading: () => const LoadingSlot(variant: LoadingVariant.cards),
        error: (_, _) => ErrorState(
          title: 'Could not load the board',
          onRetry: () => ref.invalidate(missionsProvider),
        ),
        data: (missions) {
          final activeMissions = missions.where((m) => m.isActive == 1).toList()
            ..sort((a, b) => a.sort.compareTo(b.sort));
          final pendingMissions =
              activeMissions.where((m) => !doneIds.contains(m.id)).toList();
          final pendingRoles = roles.where((r) => !r.done).toList();

          if (activeMissions.isEmpty && roles.isEmpty) {
            return EmptyState(
              icon: Icons.dashboard_customize_outlined,
              title: 'Nothing on the board',
              message: 'Add missions (in Settings) or tap + to add a role — '
                  'they’ll show here as big buttons you clear to zero.',
              action: FilledButton.icon(
                onPressed: _openRolePicker,
                icon: const Icon(Icons.add),
                label: const Text('Add a role'),
              ),
            );
          }

          final items = <_BoardItem>[
            for (final m in pendingMissions)
              _BoardItem(
                key: 'm-${m.id}',
                emoji: m.icon ?? '✅',
                label: m.name,
                complete: () => ref
                    .read(missionActionsProvider)
                    .complete(m, stepsDone: 1, stepsTotal: 1),
              ),
            for (final r in pendingRoles)
              _BoardItem(
                key: 'r-${r.entryId}',
                emoji: r.emoji,
                label: r.name,
                complete: () =>
                    ref.read(roleBoardActionsProvider).setDone(r, done: true),
                onRemove: () =>
                    ref.read(roleBoardActionsProvider).remove(r),
              ),
          ];
          final doneCount = (activeMissions.length - pendingMissions.length) +
              (roles.length - pendingRoles.length);

          return ResponsivePage(
            children: [
              ContentHeader(
                title: 'Today’s board',
                subtitle:
                    items.isEmpty ? 'All done' : '${items.length} to go',
              ),
              if (items.isEmpty)
                _TasksZero(doneCount: doneCount)
              else
                _Board(
                  items: items,
                  completing: _completing,
                  onTap: _tap,
                  onShrunk: _finish,
                ),
              if (doneCount > 0) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '✓ $doneCount done today',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRolePicker() {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RolePickerSheet(),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.items,
    required this.completing,
    required this.onTap,
    required this.onShrunk,
  });

  final List<_BoardItem> items;
  final Set<String> completing;
  final ValueChanged<_BoardItem> onTap;
  final ValueChanged<_BoardItem> onShrunk;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720
            ? 4
            : c.maxWidth >= 480
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: [
            for (final item in items)
              _BoardButton(
                key: ValueKey(item.key),
                item: item,
                shrinking: completing.contains(item.key),
                onTap: () => onTap(item),
                onShrunk: () => onShrunk(item),
              ),
          ],
        );
      },
    );
  }
}

class _BoardButton extends StatelessWidget {
  const _BoardButton({
    required this.item,
    required this.shrinking,
    required this.onTap,
    required this.onShrunk,
    super.key,
  });

  final _BoardItem item;
  final bool shrinking;
  final VoidCallback onTap;
  final VoidCallback onShrunk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedScale(
      scale: shrinking ? 0 : 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInBack,
      onEnd: shrinking ? onShrunk : null,
      child: AnimatedOpacity(
        opacity: shrinking ? 0 : 1,
        duration: const Duration(milliseconds: 260),
        child: Material(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: shrinking ? null : onTap,
            onLongPress: item.onRemove,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 46)),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TasksZero extends StatelessWidget {
  const _TasksZero({required this.doneCount});
  final int doneCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Text('✨', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          Text(
            'Tasks zero',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            doneCount == 0
                ? 'Nothing on the board.'
                : 'Everything’s done — a finished room.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick role-cards to add to today's board. Tap to add (✓ when it's on);
/// stays open so you can add a few.
class _RolePickerSheet extends ConsumerWidget {
  const _RolePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onBoard = {
      for (final r in ref.watch(activeRolesTodayProvider).value ?? const <ActiveRole>[])
        if (!r.done) r.name,
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GlassDragHandle(),
            Text('Add a role to today’s board',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
                children: [
                  for (final role in roleCatalog)
                    _RolePick(
                      role: role,
                      added: onBoard.contains(role.name),
                      onTap: () => unawaited(
                        ref.read(roleBoardActionsProvider).addRole(role),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePick extends StatelessWidget {
  const _RolePick({
    required this.role,
    required this.added,
    required this.onTap,
  });

  final RoleCard role;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: added ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: added ? 0.5 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Text(role.emoji, style: const TextStyle(fontSize: 34)),
                if (added)
                  Icon(Icons.check_circle,
                      size: 16, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              role.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
