import 'dart:async';
import 'dart:math';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/heroes/heroes_providers.dart';
import 'package:differentworld/features/heroes/widgets/collectible_role_card.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/deck/play` — the **role battle** (docs/VISION.md 2026-06-19 — "card games
/// using these roles"). Host-present, no kid phone: two role cards from the
/// deck face off, and the room debates who'd win and why — an imaginative,
/// host-judged game (no scoring; the talk IS the play). "Next" draws a new pair.
/// Gated on `heroesEnabledProvider` at the discovery layer.
class RoleGameScreen extends ConsumerStatefulWidget {
  const RoleGameScreen({super.key});

  @override
  ConsumerState<RoleGameScreen> createState() => _RoleGameScreenState();
}

class _RoleGameScreenState extends ConsumerState<RoleGameScreen> {
  // Re-shuffle salt — a new pair each tap, deterministic per salt so a rebuild
  // (e.g. a card syncing in) doesn't reshuffle under the room mid-battle.
  int _salt = 1;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(heroesInSpaceProvider).value ?? const <DeckCard>[];
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    final nameById = {for (final s in subjects) s.id: s.firstName};

    if (cards.length < 2) {
      return const EdgeScaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.style_outlined,
            title: 'Not enough cards yet',
            message:
                'Make at least two role cards, then the deck can battle — two '
                'roles face off and the room decides who’d win.',
          ),
        ),
      );
    }

    final pair = [...cards]..shuffle(Random(_salt));
    final a = pair[0];
    final b = pair[1];

    return EdgeScaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ContentHeader(
                title: 'Role battle',
                subtitle: 'Who would win? Talk it out together.',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    _Contender(card: a, childName: nameById[a.subjectId]),
                    const _VersusChip(),
                    _Contender(card: b, childName: nameById[b.subjectId]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () {
                    unawaited(HapticFeedback.mediumImpact());
                    setState(() => _salt++);
                  },
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Next battle'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One side of the battle — the card, centred + width-capped so two stack
/// cleanly on a phone held up to the room.
class _Contender extends StatelessWidget {
  const _Contender({required this.card, this.childName});

  final DeckCard card;
  final String? childName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: CollectibleRoleCard(
          data: card.data,
          entryId: card.entryId,
          childName: childName,
        ),
      ),
    );
  }
}

class _VersusChip extends StatelessWidget {
  const _VersusChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'vs',
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
