import 'package:differentworld/shared/widgets/glass_pill.dart';
import 'package:flutter/material.dart';

/// A pill containing 1-3 icon buttons — sits in the top-right of a
/// screen for screen-level actions (search, settings, edit, sync
/// indicator, etc.).
///
/// Skip the AppBar; spawn this instead. Empty `children` returns a
/// `SizedBox.shrink` so callers don't have to guard.
class FloatingActions extends StatelessWidget {
  const FloatingActions({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return GlassPill(
      // Zero outer padding so the pill's outer dimensions equal the
      // action buttons' dimensions (48dp tall, since
      // PrimaryActionButton + SecondaryActionButton are now 48×48).
      // Matches the hamburger/back pills on the left chrome
      // (which also use GlassPill(padding: EdgeInsets.zero)).
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}
