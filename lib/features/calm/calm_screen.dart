import 'package:differentworld/features/calm/calm_catalog.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/calm` — **What to do instead** (docs/VISION.md 2026-06-19): the room's
/// calm, co-held reference. Pick a feeling, see a few small things to try; the
/// agreements sit underneath as common ground. Read-only — *"not noise, just a
/// list."* Host-presented or printed; nothing here needs a phone.
///
/// Gated on `calmEnabledProvider` at the discovery layer.
///
/// Two layouts over the SAME catalog: the default single-column list and a
/// BENTO grid (opt-in via the global "Bento everywhere" switch) that lays the
/// short "things to try" out as a 2-up grid on phone — every action is a small,
/// glanceable card, so the wall reads as a board of options rather than a
/// stack. The feeling picker + the agreements stay full-width.
class CalmScreen extends ConsumerStatefulWidget {
  const CalmScreen({super.key});

  @override
  ConsumerState<CalmScreen> createState() => _CalmScreenState();
}

class _CalmScreenState extends ConsumerState<CalmScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final feeling = calmFeelings[_selected];
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). Re-layout only: same catalog, same picker
    // behaviour, same read-only content.
    final bento = bentoEnabled(ref, perScreen: null);

    return EdgeScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const ContentHeader(
              title: 'What to do instead',
              subtitle: 'Our calm common ground',
            ),
            _FeelingPicker(
              selected: _selected,
              onSelected: (i) => setState(() => _selected = i),
            ),
            const SizedBox(height: 18),
            if (bento)
              _ActionsBento(feeling: feeling)
            else
              _ActionsList(feeling: feeling),
            const SizedBox(height: 22),
            const _AgreementsSection(),
          ],
        ),
      ),
    );
  }
}

/// The feeling chooser — a wrap of choice chips. Identical in both layouts.
class _FeelingPicker extends StatelessWidget {
  const _FeelingPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < calmFeelings.length; i++)
          ChoiceChip(
            label: Text(
              '${calmFeelings[i].emoji}  ${calmFeelings[i].label}',
            ),
            selected: i == selected,
            onSelected: (_) => onSelected(i),
          ),
      ],
    );
  }
}

/// The default layout — the small things to try, one per row.
class _ActionsList extends StatelessWidget {
  const _ActionsList({required this.feeling});

  final CalmFeeling feeling;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in feeling.actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CalmActionCard(action: action),
          ),
      ],
    );
  }
}

/// The bento variant — the SAME "things to try" laid out as a 2-up grid on a
/// phone (`phone: 1`), 4-up on tablet, 6-up on desktop. Each action is short
/// (a few words), so a half-width card reads cleanly without truncation; the
/// grid turns the list into a board of small, glanceable options.
class _ActionsBento extends StatelessWidget {
  const _ActionsBento({required this.feeling});

  final CalmFeeling feeling;

  @override
  Widget build(BuildContext context) {
    return BentoGrid(
      // A grid keyed on the feeling so switching feelings re-matches cells by
      // identity (the Wrap-children-need-keys rule) instead of mutating a
      // previous action's tile in place.
      tiles: [
        for (var i = 0; i < feeling.actions.length; i++)
          BentoTile(
            id: '${feeling.id}-$i',
            span: const BentoSpan(phone: 1),
            child: _CalmActionCard(action: feeling.actions[i]),
          ),
      ],
    );
  }
}

/// One "small thing to try" card. Shared by both layouts so the card reads the
/// same whichever way the screen is laid out. Bounded for a bento cell: the
/// `Row` shrink-wraps vertically (no `Expanded`/`Spacer` in a column), and the
/// `Expanded` is on the horizontal axis (always bounded by the cell width).
class _CalmActionCard extends StatelessWidget {
  const _CalmActionCard({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.self_improvement_outlined,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(action, style: theme.textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

/// The room's agreements — a heading + a chip cloud of common ground. Spans
/// full-width in both layouts (a wrap of pills, not a tile to halve).
class _AgreementsSection extends StatelessWidget {
  const _AgreementsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We agree to…',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final agreement in roomAgreements)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  agreement,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
