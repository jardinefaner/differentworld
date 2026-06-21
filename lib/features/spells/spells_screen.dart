import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/spells/spell_overlay.dart';
import 'package:differentworld/features/spells/spells.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The spell launcher (the brief's SPELLS screen): five big buttons. Tap
/// one to cast a fullscreen countdown. Each spell is a word in another
/// language (it varies by day); the button previews today's word.
///
/// Two layouts over the SAME spell list: the existing column grid (default)
/// and a BENTO grid (opt-in via the global "Bento everywhere" switch) that
/// packs the short spell tiles denser — 2-up on a phone — over the same data.
class SpellsScreen extends ConsumerWidget {
  const SpellsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = todayKey();
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the short spell tiles re-lay as a dense
    // max-extent grid (2-up on a phone) over the SAME spell list; off keeps
    // the existing 2/3-column `GridView.count`.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Spells',
            subtitle: 'Tap to cast — a word in another language, on a timer.',
          ),
          if (bento) _bentoGrid(today) else _columnGrid(today),
        ],
      ),
    );
  }

  /// The default layout — a 2/3-column `GridView.count`.
  Widget _columnGrid(String today) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 600 ? 3 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: [
            for (final spell in kSpells)
              _SpellTile(
                spell: spell,
                word: spellWordForDay(spell, today),
              ),
          ],
        );
      },
    );
  }

  /// The bento variant — SAME five spells, re-laid as a dense max-extent grid
  /// that's 2-up on a phone (≈170dp cells), 3-up across wider screens. The set
  /// is fixed + tiny, so a shrink-wrapping grid (the present-hub pattern) is
  /// fine; `mainAxisExtent` gives each cell a bounded height so the tile's
  /// centered emoji/word Column can't throw against an unbounded box.
  Widget _bentoGrid(String today) {
    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Bounded cell height so the centered Column is safe; tall enough for
        // the emoji + word + english + timer without clipping.
        mainAxisExtent: 168,
      ),
      itemCount: kSpells.length,
      itemBuilder: (context, i) {
        final spell = kSpells[i];
        return _SpellTile(
          key: ValueKey('spell-${spell.id}'),
          spell: spell,
          word: spellWordForDay(spell, today),
        );
      },
    );
  }
}

class _SpellTile extends StatelessWidget {
  const _SpellTile({required this.spell, required this.word, super.key});

  final Spell spell;
  final SpellWord word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.goldOf(theme);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => SpellOverlay.cast(context, spell),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(spell.emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                word.word,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                spell.english,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                spellTimeLabel(spell.durationSeconds),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
