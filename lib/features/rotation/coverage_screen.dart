import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/rotation/rotation_coverage.dart';
import 'package:differentworld/features/rotation/rotation_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who has still never worked with whom (docs/ROTATION.md).
///
/// The report nothing else can produce, and the reason keeping the history
/// is worth it. It also answers a question the feature would otherwise
/// hide: at some group sizes covering a room is reachable within a term,
/// and at others it simply is not — and saying so is more honest than
/// promising rotation the arithmetic cannot deliver.
class CoverageScreen extends ConsumerWidget {
  const CoverageScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = (ref.watch(groupsProvider).value ?? const <Group>[])
        .where((g) => g.id == groupId)
        .firstOrNull;
    final roster =
        ref.watch(subjectsInGroupProvider(groupId)).value ?? const <Subject>[];
    final names = {for (final s in roster) s.id: s.firstName};
    final coverage = ref.watch(coverageForGroupProvider(groupId));
    final rounds = ref.watch(roundsForGroupProvider(groupId)).value ?? const [];

    // The commonest group size used so far — the honest basis for "how many
    // more sessions", rather than a number picked out of the air.
    final size = rounds.isEmpty ? 3 : rounds.first.n;
    final remaining = coverage.sessionsToFinish(roster.length, size);
    final wholeRoom = RotationCoverage.sessionsToCoverAll(roster.length, size);

    return EdgeScaffold(
      backFallbackRoute: '/groups/$groupId',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                ContentHeader(
                  title: 'Who hasn’t worked together yet',
                  subtitle: group?.name,
                ),
                if (roster.length < 2)
                  const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Not enough children',
                    message:
                        'Coverage needs at least two children in the room.',
                  )
                else ...[
                  Text(
                    '${coverage.metPairs} of ${coverage.totalPairs} pairs '
                    'have met',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    coverage.neverMet.isEmpty
                        ? 'Everyone in this room has worked with everyone else.'
                        : remaining == null
                        ? 'Groups of one can never cover a room.'
                        : 'At groups of $size, about $remaining more '
                              '${remaining == 1 ? 'session' : 'sessions'} '
                              'covers the room'
                              '${wholeRoom == null ? '' : ' ($wholeRoom from scratch)'}.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (coverage.neverMet.isEmpty)
                    const EmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'Fully covered',
                      message:
                          'Every child here has worked with every other. '
                          'Keep going and the engine spreads the repeats '
                          'evenly instead.',
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (a, b) in coverage.neverMet.take(40))
                          Chip(
                            label: Text(
                              '${names[a] ?? '?'} + ${names[b] ?? '?'}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        if (coverage.neverMet.length > 40)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Text(
                              '+${coverage.neverMet.length - 40} more',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
