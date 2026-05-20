import 'dart:async';

import 'package:flutter/material.dart';

/// Shimmer skeleton building blocks for "first-load" UI.
///
/// Replaces opaque spinners with shaped placeholders that match the
/// eventual content. Reduces layout jump and reads as "the data is
/// arriving" instead of "the app is hung."
///
/// All three primitives share one repeated [AnimationController] driven
/// by an ambient [_ShimmerScope] so every skeleton on the page pulses in
/// sync — N independent controllers are wasteful and look noisy.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // `repeat()` returns a never-completing Future; awaiting it would
    // suspend forever, so explicitly discard it.
    unawaited(_ctl.repeat());
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(controller: _ctl, child: widget.child);
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.controller, required super.child});

  final AnimationController controller;

  static AnimationController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ShimmerScope>();
    return scope?.controller;
  }

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.controller != controller;
}

/// A rounded rectangle placeholder that shimmers.
///
/// Use as a stand-in for a card, an avatar block, a chip — anything
/// with a defined shape. Falls back to a static pulse if not inside a
/// [SkeletonShimmer] scope.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 16,
    this.radius = 6,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final hi = Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: 0.05),
      base,
    );
    final ctl = _ShimmerScope.maybeOf(context);
    if (ctl == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }
    return AnimatedBuilder(
      animation: ctl,
      builder: (context, _) {
        final t = ctl.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -0.4),
              end: Alignment(1 + 2 * t, 0.4),
              colors: [base, hi, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// A text-line skeleton sized to look like a real line of body text.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({this.widthFactor = 1.0, this.height = 12, super.key});

  /// 0..1, share of the available width to occupy.
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor.clamp(0.1, 1.0),
        child: SkeletonBox(height: height),
      ),
    );
  }
}

/// Convenience skeleton shaped like a typical list-tile row
/// (avatar + two stacked text lines + trailing chip).
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({this.hasTrailing = false, super.key});

  final bool hasTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const SkeletonBox(width: 40, height: 40, radius: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(widthFactor: 0.6, height: 14),
                SizedBox(height: 6),
                SkeletonLine(widthFactor: 0.35, height: 11),
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 8),
            const SkeletonBox(width: 56, height: 22, radius: 11),
          ],
        ],
      ),
    );
  }
}

/// Full-screen list skeleton — header + N rows. The replacement for
/// `LoadingSlot` whenever the eventual content is a list.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.rowCount = 6,
    this.showHeader = true,
    this.hasTrailing = false,
    super.key,
  });

  final int rowCount;
  final bool showHeader;
  final bool hasTrailing;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        padding: const EdgeInsets.only(top: 56, bottom: 96),
        children: [
          if (showHeader) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SkeletonLine(widthFactor: 0.4, height: 22),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SkeletonLine(widthFactor: 0.55),
            ),
          ],
          for (var i = 0; i < rowCount; i++)
            SkeletonListTile(hasTrailing: hasTrailing),
        ],
      ),
    );
  }
}

/// Full-screen card-grid skeleton — for screens with bigger cards
/// (Today, Family Today). Renders N tall cards stacked.
class SkeletonCards extends StatelessWidget {
  const SkeletonCards({this.cardCount = 3, super.key});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 96),
        children: [
          const SkeletonLine(widthFactor: 0.45, height: 24),
          const SizedBox(height: 6),
          const SkeletonLine(widthFactor: 0.6),
          const SizedBox(height: 24),
          for (var i = 0; i < cardCount; i++) ...[
            const SkeletonBox(height: 96, radius: 14),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
