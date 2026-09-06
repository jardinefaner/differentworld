import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/heroes/heroes_providers.dart';
import 'package:differentworld/features/heroes/widgets/hero_card.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/catalog_card.dart';
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
    // ONE stream for all heroes, looked up per child — not a
    // heroForSubjectProvider watch per row (N live streams at N children).
    final heroes = ref.watch(heroesInSpaceProvider).value ?? const <DeckCard>[];
    final heroBySubject = {for (final c in heroes) c.subjectId: c};
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the same per-child cells re-lay as a
    // 2-up bento grid over the SAME subjects + heroesInSpaceProvider map; off
    // keeps the existing CatalogGrid. Same _HeroRow cell, same taps.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      actions: [
        IconButton(
          tooltip: 'The deck',
          icon: const Icon(Icons.style_outlined),
          onPressed: () => context.push('/deck'),
        ),
      ],
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
            // A responsive grid of hero cells — 1 column on phone, 2–3 at
            // tablet / desktop width. _HeroRow takes its hero as a value from
            // the one heroesInSpaceProvider map (no per-row stream).
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                const ContentHeader(
                  title: 'Heroes',
                    ),
                const SizedBox(height: 4),
                if (bento)
                  // Each child is a uniform tile that packs 2-up on a phone
                  // (phone: 1 of 2 columns), 2–3-up at width — the same
                  // equal-weight-hub read as the present hub. _HeroRow
                  // shrink-wraps (FeatureCard or a name-row + HeroCard, no
                  // Expanded/Spacer), so it's safe in a min-height bento cell.
                  BentoGrid(
                    tiles: [
                      for (final s in subjects)
                        BentoTile(
                          id: 'hero-${s.id}',
                          // phone: 1 of 2 → 2-up on a phone; tablet/desktop keep
                          // the default 2-of-N (so 2-up at tablet, 3-up at
                          // desktop), matching the present hub's uniform read.
                          span: const BentoSpan(phone: 1),
                          child: _HeroRow(
                            subject: s,
                            hero: heroBySubject[s.id],
                          ),
                        ),
                    ],
                  )
                else
                  CatalogGrid(
                    minTileWidth: 240,
                    children: [
                      for (final s in subjects)
                        _HeroRow(subject: s, hero: heroBySubject[s.id]),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One child's slot in the hub — their Hero card (tap to evolve) or a prompt to
/// make one. The hero is passed IN (from one heroesInSpaceProvider stream), not
/// watched per row.
class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.subject, required this.hero});

  final Subject subject;
  final DeckCard? hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = '${subject.firstName} ${subject.lastName}'.trim();
    final first = subject.firstName;
    void edit() => context.push('/subjects/${subject.id}/hero', extra: first);

    final h = hero;
    if (h == null) {
      return FeatureCard(
        leading: PersonAvatar(name: fullName, photoUrl: subject.photoUrl),
        title: EntityLink(
          entity: EntityRef(
            kind: EntityKind.subject,
            id: subject.id,
            label: first,
          ),
          padded: false,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: 'No hero yet — tap to make one',
        trailing: const Icon(Icons.add),
        onTap: edit,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: EntityLink(
                  entity: EntityRef(
                    kind: EntityKind.subject,
                    id: subject.id,
                    label: first,
                  ),
                  padded: false,
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
          child: HeroCard(data: h.data, entryId: h.entryId),
        ),
      ],
    );
  }
}
