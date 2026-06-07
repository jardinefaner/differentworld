import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/spells/spell_overlay.dart';
import 'package:differentworld/features/spells/spells.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';

/// The spell launcher (the brief's SPELLS screen): five big buttons. Tap
/// one to cast a fullscreen countdown. Each spell is a word in another
/// language (it varies by day); the button previews today's word.
class SpellsScreen extends StatelessWidget {
  const SpellsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = todayKey();
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Spells',
            subtitle: 'Tap to cast — a word in another language, on a timer.',
          ),
          LayoutBuilder(
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
          ),
        ],
      ),
    );
  }
}

class _SpellTile extends StatelessWidget {
  const _SpellTile({required this.spell, required this.word});

  final Spell spell;
  final SpellWord word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.brightness == Brightness.dark
        ? const Color(0xFFE6C079)
        : const Color(0xFF9A7B2E);
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
