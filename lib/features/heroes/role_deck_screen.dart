import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/heroes/heroes_providers.dart';
import 'package:differentworld/features/heroes/role_deck_pdf.dart';
import 'package:differentworld/features/heroes/widgets/collectible_role_card.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/person_photo_url.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// `/deck` — the **role deck** (docs/VISION.md 2026-06-19): every child's role
/// (their Hero) as a collectible card, the program's deck in one place. The
/// keepsake-deck model — one card per child, collected over the term. Tap a card
/// to evolve it; empty slots invite the next card. Gated on `heroesEnabledProvider`
/// at the discovery layer.
class RoleDeckScreen extends ConsumerWidget {
  const RoleDeckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsInSpaceProvider);
    // ONE stream for all heroes, then look each child's up — instead of a
    // heroForSubjectProvider watch PER child (N live streams; at a 100-child
    // program that's 100 subscriptions). This scales flat.
    final heroes = ref.watch(heroesInSpaceProvider).value ?? const <DeckCard>[];
    final heroBySubject = {for (final c in heroes) c.subjectId: c};
    return EdgeScaffold(
      actions: [
        IconButton(
          tooltip: 'Print the deck',
          icon: const Icon(Icons.print_outlined),
          onPressed: () => unawaited(_printDeck(context, ref)),
        ),
        IconButton(
          tooltip: 'Play a battle',
          icon: const Icon(Icons.casino_outlined),
          onPressed: () => context.push('/deck/play'),
        ),
      ],
      body: SafeArea(
        child: subjectsAsync.when(
          loading: () => const LoadingSlot(),
          error: (e, _) => ErrorState(
            title: 'Could not load the deck',
            detail: '$e',
            onRetry: () => ref.invalidate(subjectsInSpaceProvider),
          ),
          data: (subjects) {
            if (subjects.isEmpty) {
              return const EmptyState(
                icon: Icons.style_outlined,
                title: 'No cards yet',
                message:
                    'Add children to your program, then each builds their role '
                    '— their cards collect into the deck here.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                const ContentHeader(
                  title: 'The deck',
                  subtitle: 'Every child’s role, collected',
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final s in subjects)
                          SizedBox(
                            width: width,
                            child: _DeckCard(
                              subject: s,
                              hero: heroBySubject[s.id],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Build the room's role cards into a print-and-color PDF and open the system
/// print / share sheet. Offline-first (Helvetica); reads the deck once.
Future<void> _printDeck(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final cards = ref.read(heroesInSpaceProvider).value ?? const <DeckCard>[];
  if (cards.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No cards to print yet — make a few first.'),
      ),
    );
    return;
  }
  final subjects =
      ref.read(subjectsInSpaceProvider).value ?? const <Subject>[];
  final nameById = {for (final s in subjects) s.id: s.firstName};
  final prints = <RoleCardPrint>[];
  for (final c in cards) {
    // The child's own drawing, dropped into the card when we can fetch it
    // (an online print). Offline / no drawing → the draw-here box; the print
    // still works (per-card, so one failed fetch doesn't sink the sheet).
    pw.ImageProvider? portrait;
    try {
      final atts = await ref.read(
        attachmentsForEntityProvider((kind: 'entry', id: c.entryId)).future,
      );
      final path = atts.urls.lastOrNull;
      if (path != null) {
        final signed =
            await ref.read(signedPersonPhotoUrlProvider(path).future);
        if (signed != null && signed.isNotEmpty) {
          portrait = await networkImage(signed);
        }
      }
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[deck] portrait fetch failed: $e');
    }
    prints.add(
      RoleCardPrint(
        title: c.data.title,
        species: c.data.speciesLabel,
        animalLabel: c.data.animal?.label ?? '',
        powers: [for (final p in c.data.powers) p.label],
        childName: nameById[c.subjectId],
        portrait: portrait,
      ),
    );
  }
  try {
    final pdf = await buildRoleDeckPdf(cards: prints);
    await Printing.layoutPdf(onLayout: (_) => pdf, name: 'Role deck');
  } on Object catch (e) {
    if (kDebugMode) debugPrint('[deck] print failed: $e');
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't print — try again.")),
    );
  }
}

/// One slot in the deck — the child's collectible card, or an invite to make it.
/// The hero is passed IN (resolved once from heroesInSpaceProvider), not watched
/// per card, so the deck is one stream, not N.
class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.subject, required this.hero});

  final Subject subject;
  final DeckCard? hero;

  @override
  Widget build(BuildContext context) {
    final first = subject.firstName;
    void edit() => context.push('/subjects/${subject.id}/hero', extra: first);

    final h = hero;
    if (h == null) {
      return GestureDetector(
        onTap: edit,
        child: DottedSlot(label: first),
      );
    }
    return GestureDetector(
      onTap: edit,
      child: CollectibleRoleCard(
        data: h.data,
        entryId: h.entryId,
        childName: first,
      ),
    );
  }
}

/// An empty deck slot — a dashed placeholder inviting the child's first card.
class DottedSlot extends StatelessWidget {
  const DottedSlot({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: 232,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            '$label’s card',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            'tap to make',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
