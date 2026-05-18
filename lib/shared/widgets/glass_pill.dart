import 'dart:ui';

import 'package:flutter/material.dart';

/// A translucent rounded container with a backdrop blur — the
/// "frosted glass" pattern used for floating chrome. Sits over content
/// without taking it over.
///
/// Use as the visual container for floating action buttons / pills.
class GlassPill extends StatelessWidget {
  const GlassPill({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    this.radius = 24,
    this.tintOpacity = 0.55,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// 0..1. Higher = more solid, lower = more transparent. Default tuned
  /// for either theme.
  final double tintOpacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = scheme.surface.withValues(alpha: tintOpacity);
    final border = scheme.outlineVariant.withValues(alpha: 0.45);

    // RepaintBoundary so the blur is rasterized once and cached
    // across parent rebuilds — the floating chrome rebuilds on every
    // route change and BackdropFilter is one of the priciest ops in
    // the Impeller pipeline.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: 0.5),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
