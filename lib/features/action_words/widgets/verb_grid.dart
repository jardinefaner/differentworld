import 'dart:async';

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
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
          children: [
            for (final v in kVerbs)
              _VerbCard(
                verb: v,
                selected: selected.contains(v.id),
                // Dim only the *unselected* cards once at the cap.
                dimmed: atMax && !selected.contains(v.id),
                onTap: () => onToggle(v.id),
              ),
          ],
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
    final gold = theme.brightness == Brightness.dark
        ? const Color(0xFFE6C079)
        : const Color(0xFF9A7B2E);
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
                  Text(verb.emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(height: 6),
                  Text(
                    verb.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : null,
                      color: selected ? gold : scheme.onSurfaceVariant,
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
