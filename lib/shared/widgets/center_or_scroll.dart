import 'package:flutter/material.dart';

/// Centers [child] when it fits the available height, and scrolls it when it
/// doesn't — so a tall centered block (an empty state, an error state, a
/// hero) never produces a `RenderFlex overflowed` on a short viewport at
/// large text (phone landscape at 200% dynamic type is the classic trigger).
///
/// Falls back to a plain [Center] when the incoming height is unbounded
/// (e.g. placed inside another scrollable), where wrapping in a nested
/// scroll view would assert.
///
/// The canonical "center-or-scroll" recipe: a [SingleChildScrollView] whose
/// child is forced to at least the viewport height, so [Center] fills and
/// centers when content is short, and the scroll view engages when it's tall.
class CenterOrScroll extends StatelessWidget {
  const CenterOrScroll({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxHeight.isFinite) {
          return Center(child: child);
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
