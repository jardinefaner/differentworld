import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/senses.dart';
import 'package:differentworld/features/action_words/themed_worlds.dart';
import 'package:differentworld/features/action_words/widgets/world_badge.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **This week's world** — the bigger themed world the room is living in
/// (Wildlife, Travel, Water World…). Where the daily Action Words pick is
/// *everyday*, this is the *weekly* immersion the daily world nests inside:
/// a sensory invitation into the world, and a jump straight to the
/// activities that fit it. Teacher picks which world is current; the
/// catalog is a starter set programs extend (docs/ACTION_WORDS.md).
class ThemedWorldScreen extends ConsumerWidget {
  const ThemedWorldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gold = WorldBadge.goldFor(theme);
    final world = ref.watch(currentThemedWorldProvider);
    final spaceId = ref.watch(viewerProvider).spaceId;

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: world == null
          ? _NoWorld(
              onChoose: spaceId == null
                  ? null
                  : () => _pickWorld(context, ref, spaceId),
            )
          : ResponsivePage(
              children: [
                const ContentHeader(
                  title: 'This week’s world',
                  subtitle: 'The world the whole room is living in',
                ),
                _WorldHero(world: world, gold: gold),
                const SizedBox(height: 20),
                Text(
                  'Become it',
                  style: theme.textTheme.labelLarge?.copyWith(color: gold),
                ),
                const SizedBox(height: 8),
                for (final beat in world.senses)
                  _SenseRow(beat: beat),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/action-words/activities'),
                  icon: const Icon(Icons.local_activity_outlined),
                  label: const Text('Activities for this world'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: spaceId == null
                      ? null
                      : () => _pickWorld(context, ref, spaceId),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change this week’s world'),
                ),
              ],
            ),
    );
  }

  Future<void> _pickWorld(
    BuildContext context,
    WidgetRef ref,
    String spaceId,
  ) async {
    final current = ref.read(currentThemedWorldProvider);
    final picked = await showGlassSheet<ThemedWorld>(
      context: context,
      builder: (_) => _WorldPickerSheet(currentId: current?.id),
    );
    if (picked == null) return;
    await ref
        .read(spaceCapActionsProvider)
        .setStringCap(spaceId, SpaceCaps.currentWorld, picked.id);
  }
}

class _WorldHero extends StatelessWidget {
  const _WorldHero({required this.world, required this.gold});
  final ThemedWorld world;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(world.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text(
            world.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            world.room,
            style: theme.textTheme.labelMedium?.copyWith(color: gold),
          ),
          const SizedBox(height: 10),
          Text(
            world.blurb,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SenseRow extends StatelessWidget {
  const _SenseRow({required this.beat});
  final SenseBeat beat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(beat.sense.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beat.sense.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(beat.prompt, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoWorld extends StatelessWidget {
  const _NoWorld({required this.onChoose});
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.public_outlined,
      title: 'No world set yet',
      message: 'Pick the themed world your room is living in this week. '
          'The daily Action Words still work without one — this is the '
          'bigger world they nest inside.',
      action: onChoose == null
          ? null
          : FilledButton.icon(
              onPressed: onChoose,
              icon: const Icon(Icons.public),
              label: const Text('Choose this week’s world'),
            ),
    );
  }
}

class _WorldPickerSheet extends StatelessWidget {
  const _WorldPickerSheet({this.currentId});
  final String? currentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  'This week’s world',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final w in kThemedWorlds)
                ListTile(
                  leading: Text(w.emoji, style: const TextStyle(fontSize: 30)),
                  title: Text(w.name),
                  subtitle: Text(w.room),
                  trailing: w.id == currentId
                      ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(w),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
