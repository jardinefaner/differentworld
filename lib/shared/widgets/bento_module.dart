import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A themed **bento tile** — flat Material, rounded, tappable, with a
/// foreground colour every child text + icon inherits via [DefaultTextStyle] /
/// [IconTheme]. The standard surface for a `BentoTile`'s child (the bento cell
/// itself only sizes width + min-height; the child brings its own surface).
///
/// No hardcoded colours: callers pass [background] / [foreground] from the
/// ColorScheme or a content-driven accent run through `AppColors`. The child
/// must shrink-wrap vertically (no `Expanded` / `Spacer` in a Column — the cell
/// is min-height/unbounded-max; see docs/GRID.md).
///
/// Promoted to shared (Wave: bento sweep) so every bento surface — the Today
/// dashboard, the program hub, future hubs — renders one consistent tile.
class BentoModule extends StatelessWidget {
  const BentoModule({
    required this.background,
    required this.foreground,
    required this.onTap,
    required this.child,
    this.semanticLabel,
    super.key,
  });

  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small rounded chip holding a bento module's leading icon. Pairs with
/// [BentoModule]; [tint] is the chip fill (a step off the tile background).
class BentoModuleIcon extends StatelessWidget {
  const BentoModuleIcon({required this.icon, required this.tint, super.key});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18),
    );
  }
}
