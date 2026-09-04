import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's explicit language choice, or null to follow the device.
///
/// **Null is the default on purpose.** A Spanish-speaking parent should not
/// have to find a setting in a language they can't read in order to be
/// understood — if their phone is set to Spanish, the app should already be.
/// The picker exists for the case the device is wrong (a shared tablet, a
/// second-language household), not as the way in.
final AsyncNotifierProvider<LocaleOverride, Locale?> localeOverrideProvider =
    AsyncNotifierProvider<LocaleOverride, Locale?>(LocaleOverride.new);

class LocaleOverride extends AsyncNotifier<Locale?> {
  static const _kKey = 'settings.locale';

  @override
  Future<Locale?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kKey);
    return (code == null || code.isEmpty) ? null : Locale(code);
  }

  /// Pass null to hand control back to the device.
  Future<void> set(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kKey);
    } else {
      await prefs.setString(_kKey, locale.languageCode);
    }
    state = AsyncData(locale);
  }
}
