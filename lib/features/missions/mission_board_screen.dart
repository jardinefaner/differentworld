import 'dart:async';
import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/missions/missions_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Mission ids completed *today* — derived from the mission-completion
/// entries. Drives the board's hide-on-done.
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

/// The **Do board** (docs/ACTION_WORDS.md "doing clears to zero"): the
/// room's missions as big image-buttons, not a list. Tap one → it shrinks
/// away and the board drains toward **tasks zero** — a clean, finished
/// room. Doing is ephemeral; it disappears when done.
class MissionBoardScreen extends ConsumerStatefulWidget {
  const MissionBoardScreen({super.key});

  @override
  ConsumerState<MissionBoardScreen> createState() => _MissionBoardScreenState();
}

class _MissionBoardScreenState extends ConsumerState<MissionBoardScreen> {
  /// Mission ids mid-shrink — kept locally so the button animates out
  /// before the completion write removes it from the data.
  final Set<String> _completing = {};

  void _tap(Mission mission) {
    if (_completing.contains(mission.id)) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _completing.add(mission.id));
  }

  Future<void> _finish(Mission mission) async {
    await ref.read(missionActionsProvider).complete(
          mission,
          stepsDone: 1,
          stepsTotal: 1,
        );
    if (mounted) setState(() => _completing.remove(mission.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missionsAsync = ref.watch(missionsProvider);
    final doneIds = ref.watch(_doneMissionIdsTodayProvider);

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: missionsAsync.when(
        loading: () => const LoadingSlot(variant: LoadingVariant.cards),
        error: (_, _) => ErrorState(
          title: 'Could not load the board',
          onRetry: () => ref.invalidate(missionsProvider),
        ),
        data: (missions) {
          final active = missions.where((m) => m.isActive == 1).toList()
            ..sort((a, b) => a.sort.compareTo(b.sort));
          if (active.isEmpty) {
            return EmptyState(
              icon: Icons.dashboard_customize_outlined,
              title: 'No missions yet',
              message: 'Add missions (or the starter set) and they’ll show '
                  'here as today’s board — big buttons you clear to zero.',
              action: FilledButton.icon(
                onPressed: () => context.push('/settings/missions'),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Set up missions'),
              ),
            );
          }
          final pending =
              active.where((m) => !doneIds.contains(m.id)).toList();
          final doneCount = active.length - pending.length;

          return ResponsivePage(
            children: [
              ContentHeader(
                title: 'Today’s board',
                subtitle: pending.isEmpty
                    ? 'All done'
                    : '${pending.length} to go',
              ),
              if (pending.isEmpty)
                _TasksZero(doneCount: doneCount)
              else
                _Board(
                  pending: pending,
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
}

class _Board extends StatelessWidget {
  const _Board({
    required this.pending,
    required this.completing,
    required this.onTap,
    required this.onShrunk,
  });

  final List<Mission> pending;
  final Set<String> completing;
  final ValueChanged<Mission> onTap;
  final ValueChanged<Mission> onShrunk;

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
            for (final m in pending)
              _MissionButton(
                key: ValueKey(m.id),
                mission: m,
                shrinking: completing.contains(m.id),
                onTap: () => onTap(m),
                onShrunk: () => onShrunk(m),
              ),
          ],
        );
      },
    );
  }
}

class _MissionButton extends StatelessWidget {
  const _MissionButton({
    required this.mission,
    required this.shrinking,
    required this.onTap,
    required this.onShrunk,
    super.key,
  });

  final Mission mission;
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
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mission.icon ?? '✅',
                    style: const TextStyle(fontSize: 46),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mission.name,
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
