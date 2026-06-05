import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// In-app text-scale override. Layered on TOP of the OS-level
/// dynamic-type setting — when the user picks anything but
/// [TextScaleMode.systemDefault], the `AppTextScaleApplier` shim
/// (see `lib/app/app.dart`) clamps the effective `TextScaler` to AT
/// LEAST the chosen floor. Smaller OS settings still get rescaled
/// up; larger ones pass through unchanged.
///
/// Lives in Settings → Display. Persona note: Helen's eyes don't
/// agree with the iOS default; she'd like an in-app booster on top
/// of the system slider so she can keep system small for her other
/// apps but get a more readable Different World.
enum TextScaleMode {
  /// Don't touch what the OS provides. Default for new accounts.
  systemDefault,

  /// "Large" — clamps the effective scale to at least 1.3x.
  large,

  /// "Extra large" — clamps to at least 1.5x. Matches the persona
  /// audit's 200% target for the bulk of the UI; some chrome (chips,
  /// tags) may still overflow at this size, by design.
  extraLarge,
}

extension TextScaleModeX on TextScaleMode {
  /// Human label for Settings UI.
  String get label => switch (this) {
        TextScaleMode.systemDefault => 'System default',
        TextScaleMode.large => 'Large',
        TextScaleMode.extraLarge => 'Extra large',
      };

  /// Storage scalar floor applied by `AppTextScaleApplier`.
  double get floor => switch (this) {
        TextScaleMode.systemDefault => 1.0,
        TextScaleMode.large => 1.3,
        TextScaleMode.extraLarge => 1.5,
      };
}

/// Persisted user choice. Watch this provider to render the current
/// state; write through [TextScaleSettingNotifier.set] to change it
/// and persist.
final textScaleSettingProvider =
    AsyncNotifierProvider<TextScaleSettingNotifier, TextScaleMode>(
  TextScaleSettingNotifier.new,
);

class TextScaleSettingNotifier extends AsyncNotifier<TextScaleMode> {
  static const _kKey = 'settings.text_scale_mode';

  @override
  Future<TextScaleMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    return _decode(raw);
  }

  Future<void> set(TextScaleMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, _encode(mode));
    state = AsyncData(mode);
  }

  static TextScaleMode _decode(String? raw) {
    switch (raw) {
      case 'large':
        return TextScaleMode.large;
      case 'extra_large':
        return TextScaleMode.extraLarge;
      case 'system_default':
      case null:
      case '':
      default:
        return TextScaleMode.systemDefault;
    }
  }

  static String _encode(TextScaleMode mode) => switch (mode) {
        TextScaleMode.systemDefault => 'system_default',
        TextScaleMode.large => 'large',
        TextScaleMode.extraLarge => 'extra_large',
      };
}

/// MediaQuery shim — wrap the MaterialApp's builder result in this to
/// apply the user's text-scale override on top of the OS setting.
/// Designed to be idempotent: when the mode is `systemDefault` (or
/// the user's setting hasn't loaded yet), we return the child
/// untouched so there's no boot-time scale flicker.
class AppTextScaleApplier extends ConsumerWidget {
  const AppTextScaleApplier({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeAsync = ref.watch(textScaleSettingProvider);
    final mode = modeAsync.value ?? TextScaleMode.systemDefault;
    if (mode == TextScaleMode.systemDefault) return child;

    final baseScaler = MediaQuery.textScalerOf(context);
    // Apply a floor: the effective scaler is max(OS-provided,
    // chosen-floor). Users who already have a larger system slider
    // don't get downscaled.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: _ClampedFloorTextScaler(
          base: baseScaler,
          floor: mode.floor,
        ),
      ),
      child: child,
    );
  }
}

/// Wraps a base [TextScaler] but never returns a scale below a
/// configured floor. Implemented as a real TextScaler subclass so
/// every path that asks for the active scaler (including platform
/// glyphs + accessibility tooling) sees the same value.
class _ClampedFloorTextScaler extends TextScaler {
  const _ClampedFloorTextScaler({required this.base, required this.floor});

  final TextScaler base;
  final double floor;

  @override
  double scale(double fontSize) {
    final raw = base.scale(fontSize);
    final minimum = fontSize * floor;
    return raw >= minimum ? raw : minimum;
  }

  // textScaleFactor is deprecated in Flutter (post-3.12 nonlinear
  // scaling) but still abstract on TextScaler, so we have to
  // override it. Implementation mirrors `scale()`: never return less
  // than the configured floor. The `ignore` directive is required
  // because reading `base.textScaleFactor` triggers the deprecation
  // even though our override is forced on us by the API surface.
  @override
  double get textScaleFactor {
    // Reading `base.textScaleFactor` trips the same deprecation our
    // override is responding to; the base class still has this
    // abstract getter so we have no choice. Suppressed below.
    // ignore: deprecated_member_use
    final raw = base.textScaleFactor;
    return raw >= floor ? raw : floor;
  }

  @override
  bool operator ==(Object other) =>
      other is _ClampedFloorTextScaler &&
      other.base == base &&
      other.floor == floor;

  @override
  int get hashCode => Object.hash(base, floor);
}
