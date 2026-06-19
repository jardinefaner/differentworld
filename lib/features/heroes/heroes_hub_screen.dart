import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/heroes/heroes_providers.dart';
import 'package:differentworld/features/heroes/widgets/hero_card.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/heroes` — the **Heroes hub** (docs/VISION.md 2026-06-19): the room-level
/// bridge into the per-child creator. Each child the viewer can see shows their
/// Hero card (tap to evolve it) or a "make one" prompt (tap to start). Gated on
/// `heroesEnabledProvider` at the discovery layer, so reaching here means the
/// activity is switched on.
class HeroesHubScreen extends ConsumerWidget {
  const HeroesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsInSpaceProvider);
    return EdgeScaffold(
      body: SafeArea(
        child: subjectsAsync.when(
          loading: () => const LoadingSlot(),
          error: (e, _) => ErrorState(
            title: 'Could not load children',
            detail: '$e',
            onRetry: () => ref.invalidate(subjectsInSpaceProvider),
          ),
          data: (subjects) {
            if (subjects.isEmpty) {
              return const EmptyState(
                icon: Icons.auto_awesome_outlined,
                title: 'No children yet',
                message:
                    'Add children to your program, then each can build a hero.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                const ContentHeader(
                  title: 'Heroes',
                  subtitle: 'Each child’s make-believe self',
                ),
                for (final s in subjects) _HeroRow(subject: s),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One child's slot in the hub — their Hero card (tap to evolve) or a prompt to
/// make one. A tiny per-subject watch on `heroForSubjectProvider`.
class _HeroRow extends ConsumerWidget {
  const _HeroRow({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hero = ref.watch(heroForSubjectProvider(subject.id)).value;
    final fullName = '${subject.firstName} ${subject.lastName}'.trim();
    final first = subject.firstName;
    void edit() => context.push('/subjects/${subject.id}/hero', extra: first);

    if (hero == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FeatureCard(
          leading: PersonAvatar(name: fullName, photoUrl: subject.photoUrl),
          title: first,
          subtitle: 'No hero yet — tap to make one',
          trailing: const Icon(Icons.add),
          onTap: edit,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    first,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: edit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: edit,
            child: HeroCard(data: hero.data, entryId: hero.entryId),
          ),
        ],
      ),
    );
  }
}
