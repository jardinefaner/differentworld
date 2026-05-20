import 'package:flutter/material.dart';

/// Traffic-light state for a "today" row (a classroom on Today, a kid
/// on Family Today). One dot per card: the at-a-glance answer to
/// "anything to do here?"
///
/// Semantic:
/// - [calm]: nothing requires action. Green-ish surface tint.
/// - [progress]: in progress (some marked, some not). Tertiary tint.
/// - [needsAttention]: untouched / overdue / red-flagged. Error tint.
/// - [neutral]: empty room / no data — soft neutral grey.
enum StatusDotKind { calm, progress, needsAttention, neutral }

class StatusDot extends StatelessWidget {
  const StatusDot({
    required this.kind,
    this.size = 12,
    this.glow = true,
    super.key,
  });

  final StatusDotKind kind;
  final double size;

  /// Adds a soft outer glow ring — used when the dot is "needs
  /// attention" so the eye finds it even in a long scroll.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (kind) {
      StatusDotKind.calm => scheme.primary,
      StatusDotKind.progress => scheme.tertiary,
      StatusDotKind.needsAttention => scheme.error,
      StatusDotKind.neutral => scheme.onSurfaceVariant,
    };
    final wantsGlow = glow && kind == StatusDotKind.needsAttention;
    return Container(
      width: size + (wantsGlow ? 6 : 0),
      height: size + (wantsGlow ? 6 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: wantsGlow ? color.withValues(alpha: 0.18) : Colors.transparent,
      ),
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}
