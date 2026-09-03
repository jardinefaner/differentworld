import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The 12-verb selectable grid. Tap to toggle; once [max] are selected,
/// the unselected cards dim and don't respond (so you can't pick a 4th).
/// Big emoji + label — readable by a teacher at arm's length.
class VerbGrid extends StatelessWidget {
  const VerbGrid({
    required this.selected,
    required this.onToggle,
    this.max = kPicksPerDay,
    super.key,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final int max;

  @override
  Widget build(BuildContext context) {
    final atMax = selected.length >= max;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 3 columns on phones, 4 on wider sheets.
        final cols = constraints.maxWidth >= 520 ? 4 : 3;
        // Cells must GROW with the user's text scale. A fixed
        // childAspectRatio pins the cell to the WIDTH, so at 200% the emoji
        // and label double while the box does not — the documented trap
        // (CLAUDE.md), and 48 of the overflow reports in the 200% stress pass
        // came from this one grid. 60 + 62·scale reproduces today's ~122dp
        // cell at 100% and gives the doubled content somewhere to go.
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 60 + 62 * scale,
          ),
          itemCount: kVerbs.length,
          itemBuilder: (context, i) {
            final v = kVerbs[i];
            return _VerbCard(
              verb: v,
              selected: selected.contains(v.id),
              // Dim only the *unselected* cards once at the cap.
              dimmed: atMax && !selected.contains(v.id),
              onTap: () => onToggle(v.id),
            );
          },
        );
      },
    );
  }
}

class _VerbCard extends StatelessWidget {
  const _VerbCard({
    required this.verb,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final Verb verb;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = AppColors.goldOf(theme);
    return Semantics(
      button: true,
      selected: selected,
      label: '${verb.label}${selected ? ', selected' : ''}',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dimmed ? 0.35 : 1,
        child: Material(
          color: selected
              ? gold.withValues(alpha: 0.18)
              : scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? gold : Colors.transparent,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: dimmed
                ? null
                : () {
                    unawaited(HapticFeedback.selectionClick());
                    onTap();
                  },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Flexible so a cell that is a few pixels short degrades
                  // instead of throwing a RenderFlex. The extent above is
                  // sized for the common case; this survives the rest.
                  Flexible(
                    child: Text(
                      verb.emoji,
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      verb.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : null,
                        color: selected ? gold : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
