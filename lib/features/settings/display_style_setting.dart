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
/// - [clean] — Calm's flat layout PLUS the clean typographic restraint from
///   the show_widget mockups (the Anthropic/Linear voice): medium weight +
///   tight tracking + sentence-case headers (no UPPERCASE hero), via
///   `AppType.cleanTextTheme`. Opt-in; the wordmark/splash keep the brand
///   hero. See docs/VISION.md.
///
/// Read via [displayStyleProvider]; `FeatureCard`, `ContentHeader`, and the
/// app theme watch it and restyle.
enum DisplayStyle { boxed, calm, clean }

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
    // Calm is the DEFAULT (the one-edge / flat direction the user chose);
    // 'boxed' reverts to filled cards, 'clean' opts into the tight-tracked
    // sentence-case typography.
    return switch (prefs.getString(_kKey)) {
      'boxed' => DisplayStyle.boxed,
      'clean' => DisplayStyle.clean,
      _ => DisplayStyle.calm,
    };
  }

  Future<void> set(DisplayStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, style.name);
    state = AsyncData(style);
  }
}

/// Human labels for the settings picker.
extension DisplayStyleLabel on DisplayStyle {
  String get label => switch (this) {
        DisplayStyle.boxed => 'Boxed',
        DisplayStyle.calm => 'Calm',
        DisplayStyle.clean => 'Clean',
      };

  String get description => switch (this) {
        DisplayStyle.boxed => 'Filled cards, each its own box',
        DisplayStyle.calm => 'Flat one-edge cards — the default',
        DisplayStyle.clean => 'Calm, plus tight sentence-case type',
      };
}
