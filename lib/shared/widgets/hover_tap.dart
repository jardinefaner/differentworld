import 'package:flutter/material.dart';

/// A `GestureDetector(onTap:)` that ALSO shows the click cursor on hover —
/// the desktop/web "this is clickable" signal that a raw `GestureDetector`
/// omits (unlike `InkWell`, which provides it for free).
///
/// Reach for this for tappable surfaces that are buttons-in-spirit but aren't
/// `InkWell`-based — a clickable photo thumbnail, a custom chip, a tap-to-zoom
/// image. Do NOT use it for *gesture surfaces* (a tap-to-pause stage, a drawing
/// canvas) where a hand cursor would lie about what the surface does — those
/// stay a plain `GestureDetector`.
///
/// (Most buttons already use `InkWell` / a Material button and get the cursor;
/// this closes the gap for the handful that legitimately can't.)
class HoverTap extends StatelessWidget {
  const HoverTap({
    required this.onTap,
    required this.child,
    this.behavior = HitTestBehavior.opaque,
    super.key,
  });

  final VoidCallback? onTap;
  final Widget child;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // Defer to the surrounding region when there's nothing to tap, so a
      // disabled state doesn't falsely advertise a click.
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: behavior,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
