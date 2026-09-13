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
  const LoadingSlot({
    this.variant = LoadingVariant.list,
    this.inline = false,
    super.key,
  });

  /// Set when this sits INSIDE a scroll view (a child of a `ListView` or a
  /// `Column`) rather than being the screen's body. The default is a body
  /// that owns its own scrolling, and using that default inside another list
  /// throws — see [SkeletonList.inline].
  final bool inline;

  /// Backwards-compatible shorthand. The old usage `const LoadingSlot()`
  /// continues to compile.
  final LoadingVariant variant;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      LoadingVariant.list => SkeletonList(inline: inline),
      LoadingVariant.cards => SkeletonCards(inline: inline),
      LoadingVariant.spinner => const Center(
        child: CircularProgressIndicator(),
      ),
    };
  }
}
