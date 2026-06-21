import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/conductor` — the **Layer-3 "deep" surface** (docs/COCKPIT.md): the
/// planning desk, designed for a laptop, not the phone. Where the cockpit (`/now`)
/// is one beat at a time for the live room, the conductor is the zoomed-OUT
/// view: where the season is, every child's keepsake book one tap away, and the
/// week's two anchor moves (plan, send home). It COMPOSES surfaces that already
/// exist — the season hub, each child's Book, the send composer — it doesn't
/// rebuild them.
class ConductorScreen extends ConsumerWidget {
  const ConductorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(seasonPositionProvider);
    final subjectsAsync = ref.watch(subjectsInSpaceProvider);

    return EdgeScaffold(
      body: subjectsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the roster',
          onRetry: () => ref.invalidate(subjectsInSpaceProvider),
        ),
        data: (subjects) => ResponsivePage(
          children: [
            const ContentHeader(
              title: 'Conductor',
              subtitle: 'Your planning desk — the week at a glance',
            ),
            _SeasonOverview(position: position),
            const SizedBox(height: 8),
            const _SectionLabel(text: 'This week'),
            const _WeekActions(),
            const SizedBox(height: 16),
            const _SectionLabel(text: 'Every child’s book'),
            if (subjects.isEmpty)
              const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No children yet',
                message: 'Add children and their books fill in week by week.',
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final s in subjects)
                    SizedBox(
                      width: 320,
                      child: FeatureCard(
                        leading: PersonAvatar(
                          name: '${s.firstName} ${s.lastName}'.trim(),
                          photoUrl: s.photoUrl,
                          radius: 20,
                        ),
                        title: EntityLink(
                          entity: EntityRef(
                            kind: EntityKind.subject,
                            id: s.id,
                            label: '${s.firstName} ${s.lastName}'.trim(),
                          ),
                          padded: false,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: 'Open the 10-week book',
                        trailing: const Icon(Icons.menu_book_outlined),
                        onTap: () => context.push('/book/${s.id}'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SeasonOverview extends StatelessWidget {
  const _SeasonOverview({required this.position});

  final SeasonPosition? position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final world = position?.world;
    if (position == null || world == null) {
      // Journey not set up — point at where the start date lives.
      return FeatureCard(
        leading: const Icon(Icons.flag_outlined),
        title: 'Set up the journey',
        subtitle: 'Pick a start date and the 10-week season begins',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/this-week'),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(world.emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week ${position!.week} of 10 · Day ${position!.day}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  world.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekActions extends StatelessWidget {
  const _WeekActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FeatureCard(
          leading: const Icon(Icons.map_outlined),
          title: 'The week’s plan',
          subtitle: 'The season hub — worlds, days, the whole journey',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/program'),
        ),
        FeatureCard(
          leading: const Icon(Icons.outgoing_mail),
          title: 'Send home',
          subtitle: 'Each child’s note, ready to copy',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/action-words/send'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
