import 'package:differentworld/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';

/// The canonical "I'm loading something" body.
///
/// Defaults to a list-shaped shimmer skeleton (matches the vast majority
/// of screens, which are lists of rows). Pass a different variant to
/// render a card-stack skeleton (Today / Family Today) or fall back to
/// the legacy centered spinner where layout shape isn't predictable.
///
/// Replaces the inline `Center(child: CircularProgressIndicator())`
/// closures screens used to hand to `AsyncValue.when`.
///
/// Named `LoadingSlot` rather than `AsyncLoading` because the latter
/// collides with Riverpod's sealed type marker on `AsyncValue`.
enum LoadingVariant { list, cards, spinner }

class LoadingSlot extends StatelessWidget {
  const LoadingSlot({this.variant = LoadingVariant.list, super.key});

  /// Backwards-compatible shorthand. The old usage `const LoadingSlot()`
  /// continues to compile.
  final LoadingVariant variant;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      LoadingVariant.list => const SkeletonList(),
      LoadingVariant.cards => const SkeletonCards(),
      LoadingVariant.spinner => const Center(child: CircularProgressIndicator()),
    };
  }
}
