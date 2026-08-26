import 'dart:async';

import 'package:differentworld/features/settings/starting_simple_setting.dart';
import 'package:differentworld/shared/widgets/accent_edge_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tells a newcomer that their short menu is deliberate.
///
/// Without this the trim is indistinguishable from a broken install, or
/// worse, from an app that simply does not do very much — and someone who
/// concludes the second one never opens it again. Naming the state is what
/// turns a small menu from a limitation into a starting point.
///
/// It is NEWS, not instruction: it appears once for a person who just
/// joined, and both buttons end it. "Everything else is in search" is said
/// here, at the moment it is true and useful, rather than living forever as
/// a subtitle nobody reads (CLAUDE.md — an instruction that is always on
/// screen is a sign on a wall).
///
/// Renders nothing at all unless the trim is on and the note is unseen, so
/// it costs an existing user nothing.
class StartingSimpleNote extends ConsumerWidget {
  const StartingSimpleNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simple = ref.watch(startingSimpleProvider).value ?? false;
    final seen = ref.watch(startingSimpleNoteSeenProvider).value ?? true;
    if (!simple || seen) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return AccentEdgeRow(
      margin: const EdgeInsets.only(bottom: 12),
      accent: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Showing the basics while you settle in',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 2),
          Text(
            'Nothing is switched off — search finds every page, every child '
            'and every tool.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => unawaited(_showEverything(ref)),
                child: const Text('Show the full menu'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => unawaited(
                  ref.read(startingSimpleNoteSeenProvider.notifier).markSeen(),
                ),
                child: const Text('Got it'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Turning the menu back on also retires the note — leaving it up after
  /// someone has acted on it is the exact nagging this is trying to avoid.
  Future<void> _showEverything(WidgetRef ref) async {
    await ref.read(startingSimpleProvider.notifier).set(value: false);
    await ref.read(startingSimpleNoteSeenProvider.notifier).markSeen();
  }
}
