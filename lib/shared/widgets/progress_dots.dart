import 'package:flutter/material.dart';

/// Row of small dots representing progress through a finite sequence
/// (a survey, a wizard, a review). The current dot widens into a pill
/// so the eye can find "where am I" at a glance.
///
/// Reusable across surfaces — keep the visual identical so users learn
/// the affordance once.
class ProgressDots extends StatelessWidget {
  const ProgressDots({
    required this.count,
    required this.current,
    super.key,
  });

  final int count;

  /// 0-based index of the current step. Clamped to `0..count - 1`.
  final int current;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final i0 = current.clamp(0, count - 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: i == i0 ? 24 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i <= i0 ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}
