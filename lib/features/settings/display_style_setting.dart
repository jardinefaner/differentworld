import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// How the app's surfaces present themselves — the "Calm" direction
/// (docs/VISION.md, 2026-06-14: the felt clutter is boxiness + indentation).
///
/// - [boxed] — the original look: filled cards, each its own box.
/// - [calm] — flatter: neutral cards drop the heavy fill for a hairline so
///   the content reads as one continuous surface, not a stack of boxes.
///   SIGNAL cards (selected / danger / success) keep their tint — calming the
///   neutral chrome around them is exactly what makes a signal stand out.
///
/// Read via [displayStyleProvider]; `FeatureCard` watches it and restyles.
enum DisplayStyle { boxed, calm }

/// Persisted choice. **Defaults to [DisplayStyle.calm]** — the one-edge / flat
/// direction is the app's look now; an explicit toggle-off reverts to boxed.
final displayStyleProvider =
    AsyncNotifierProvider<DisplayStyleNotifier, DisplayStyle>(
  DisplayStyleNotifier.new,
);

class DisplayStyleNotifier extends AsyncNotifier<DisplayStyle> {
  static const _kKey = 'settings.display_style';

  @override
  Future<DisplayStyle> build() async {
    final prefs = await SharedPreferences.getInstance();
    // Calm is the DEFAULT now (the one-edge / flat direction the user chose);
    // only an explicit 'boxed' choice reverts to the old filled cards.
    return prefs.getString(_kKey) == 'boxed'
        ? DisplayStyle.boxed
        : DisplayStyle.calm;
  }

  Future<void> set(DisplayStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      style == DisplayStyle.calm ? 'calm' : 'boxed',
    );
    state = AsyncData(style);
  }
}
