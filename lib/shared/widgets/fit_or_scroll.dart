import 'package:flutter/material.dart';

/// Content that **centres when it fits and scrolls when it doesn't**.
///
/// The shape behind every landscape overflow in this app: a centred column
/// sized for a phone held upright, on a viewport 390dp tall. In portrait there
/// is slack, so a `Spacer` or a `Center` looks right; rotate the phone and the
/// same column is 110dp too tall with nowhere to put the excess — a `Spacer`
/// cannot shrink below zero and a `Center` cannot scroll.
///
/// The fix is not "make it smaller" — the breathing circle is that size for a
/// reason, and a room reads it from across the floor. It is to let the content
/// keep its size and let the VIEWPORT move.
///
/// Below the fold it scrolls; above it, `Center` does the centring, which is
/// why callers should drop their own `Spacer`s: a `Spacer` inside a scroll
/// view has unbounded flex and throws.
class FitOrScroll extends StatelessWidget {
  const FitOrScroll({
    required this.child,
    this.padding,
    this.alignment = Alignment.center,
    this.hasFlexChild = false,
    super.key,
  });

  final Widget child;

  /// Applied inside the scroll view, so it scrolls with the content rather
  /// than clipping it.
  final EdgeInsetsGeometry? padding;

  /// Where the content sits when there IS room. Centre by default; pass
  /// `Alignment.topCenter` for content that should hang from the top.
  final AlignmentGeometry alignment;

  /// Set when [child] is a `Column` containing an `Expanded` / `Flexible`.
  ///
  /// A flex child needs a bounded main axis and a scroll view gives it an
  /// unbounded one, so the two normally cannot be combined — the render tree
  /// throws `RenderBox was not laid out`. `IntrinsicHeight` bridges them: it
  /// measures the natural height first, so the flex child still fills a full
  /// viewport in portrait AND the whole thing scrolls when it cannot fit.
  ///
  /// It costs an extra layout pass over the subtree, so it is opt-in rather
  /// than the default — only reach for it when the column genuinely has
  /// something that must stretch.
  final bool hasFlexChild;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded parent (a Column with no Expanded, say) has no viewport
        // to fill, so there is nothing to centre against and nothing to
        // scroll — hand the child straight through rather than forcing a
        // zero-height box.
        if (!constraints.hasBoundedHeight) return child;
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            // At least the viewport, so short content still centres; more when
            // the content is taller, which is what makes it scroll.
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: alignment,
              child: hasFlexChild ? IntrinsicHeight(child: child) : child,
            ),
          ),
        );
      },
    );
  }
}
