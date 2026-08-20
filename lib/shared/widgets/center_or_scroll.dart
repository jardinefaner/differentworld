import 'package:flutter/material.dart';

/// Centers [child] when it fits the available height, and scrolls it when it
/// doesn't — so a tall centered block (an empty state, an error state, a
/// hero) never produces a `RenderFlex overflowed` on a short viewport at
/// large text (phone landscape at 200% dynamic type is the classic trigger).
///
/// Implementation note: this deliberately does NOT use a [LayoutBuilder].
/// Hosts like `SliverFillRemaining(hasScrollBody: false)` measure their
/// child's intrinsic height, and a LayoutBuilder cannot answer intrinsics —
/// debug builds threw the "LayoutBuilder does not support returning
/// intrinsic dimensions" assert the moment an empty state rendered inside
/// one (the photo wall's empty filter was the trigger). The [Center] +
/// shrink-wrapping [SingleChildScrollView] pair gives the same behavior at
/// every height, intrinsics included:
///
/// - Bounded height, short content → the scroll view shrink-wraps to the
///   content and [Center] centers it. No scrolling.
/// - Bounded height, tall content → the scroll view is capped at the
///   viewport height and scrolls.
/// - Unbounded height (inside another scrollable) → the scroll view sizes
///   to the content and never engages, matching the old plain-Center path.
class CenterOrScroll extends StatelessWidget {
  const CenterOrScroll({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: SingleChildScrollView(child: child));
  }
}
