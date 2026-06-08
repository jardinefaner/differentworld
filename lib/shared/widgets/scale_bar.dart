import 'package:flutter/material.dart';

/// **SCALE** — the eleventh primitive (docs/PRIMITIVES.md): a position on a
/// bounded continuum. Mood 3/5, stillness 47s, Day 23/50, worlds 4/10. The
/// thing none of the other ten atoms name — "a reading on a dial." Its UI law:
/// show the position AND the change (the delta), because growth is the point,
/// not the absolute number.
@immutable
class Scale {
  const Scale({
    required this.value,
    this.min = 0,
    this.max = 1,
    this.previous,
  });

  final num value;
  final num min;
  final num max;

  /// The prior reading, if any — drives the delta arrow.
  final num? previous;

  /// 0..1 position on the continuum (clamped).
  double get fraction {
    if (max <= min) return 0;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  /// The change since [previous], or null if this is the first reading.
  num? get delta => previous == null ? null : value - previous!;
}

/// Renders a [Scale] as a labelled gauge: the label + a trailing value, a bar
/// at the scale's fraction, and — when there's a previous reading — the delta
/// ("▲ +13"). The shared visual for every bounded measure in the app.
class ScaleBar extends StatelessWidget {
  const ScaleBar({
    required this.scale,
    required this.label,
    this.trailing,
    this.accent,
    super.key,
  });

  final Scale scale;
  final String label;

  /// What to show on the right ("4 / 10", "Week 6"). Defaults to none.
  final String? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = accent ?? theme.colorScheme.primary;
    final delta = scale.delta;
    final up = delta != null && delta > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            if (delta != null && delta != 0) ...[
              Text(
                '${up ? '▲' : '▼'} ${up ? '+' : ''}'
                '${delta % 1 == 0 ? delta.toInt() : delta}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: up
                      ? const Color(0xFF51CF66)
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (trailing != null)
              Text(
                trailing!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: scale.fraction,
            minHeight: 6,
            color: tone,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
