import 'package:differentworld/shared/widgets/glass_pill.dart';
import 'package:flutter/material.dart';

/// Top-left glass-pill that opens the [Scaffold.drawer]. Used as the
/// home-screen replacement for FloatingBack — when there's nothing to
/// pop, you get a menu instead.
///
/// Looks for the nearest `Scaffold` and asks it to open its drawer.
class FloatingHamburger extends StatelessWidget {
  const FloatingHamburger({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPill(
      padding: EdgeInsets.zero,
      child: IconButton(
        tooltip: 'Menu',
        icon: Icon(Icons.menu, color: scheme.onSurface),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    );
  }
}
