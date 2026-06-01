import 'dart:async';
import 'dart:math' as math;

import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:flutter/material.dart';

/// A slim strip that sits directly above the omnibox bar while a
/// schedule block is live. Collapses to zero height when nothing is
/// live — absence is the signal, no "nothing live" copy.
///
/// Shows: 🟢 LIVE · {block title}
/// The green dot has a slow breathing animation so it reads as "active
/// now" without competing with the content. A `RepaintBoundary` wraps
/// the dot so only it repaints on each animation tick.
class LiveBlockStrip extends StatefulWidget {
  const LiveBlockStrip({required this.liveBlock, super.key});

  final LiveBlock? liveBlock;

  @override
  State<LiveBlockStrip> createState() => _LiveBlockStripState();
}

class _LiveBlockStripState extends State<LiveBlockStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _alpha;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    unawaited(_pulse.repeat(reverse: true));
    _alpha = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.liveBlock;

    // Collapses to zero height when nothing is live.
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: block == null
          ? const SizedBox.shrink()
          : _Strip(block: block, alpha: _alpha),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.block, required this.alpha});

  final LiveBlock block;
  final Animation<double> alpha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        // Same translucent glass surface as the omnibox bar.
        color: scheme.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: scheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Breathing green dot — RepaintBoundary so only the dot
          // repaints on each animation tick.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: alpha,
              builder: (_, _) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: alpha.value),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'LIVE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          // Separator dot.
          Text(
            '·',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              block.title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Time remaining — shows how long until the block ends.
          _TimeRemaining(endAt: block.endAt),
        ],
      ),
    );
  }
}

/// "ends in Xm" label — redraws only when the minute changes.
class _TimeRemaining extends StatelessWidget {
  const _TimeRemaining({required this.endAt});

  final DateTime endAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = endAt.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final mins = math.max(1, remaining.inMinutes);
    return Text(
      '${mins}m',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
