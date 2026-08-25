import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether a person with no photo gets a **drawn portrait** instead of their
/// initials (`GeneratedPortrait`).
///
/// **Defaults to OFF, and that default is the honest one.** Initials claim
/// nothing; a drawn face claims something about a child that is not true.
/// That is a fine trade for a picker in front of a room — faces are far
/// easier to match against real children than two letters are — but it is a
/// taste call a director makes, not one the app makes for them.
///
/// Off is also the safe direction while loading: consumers read
/// `.value ?? false`, so a slow `SharedPreferences` read shows initials and
/// settles, rather than flashing a face and swapping it away.
final generatedPortraitsProvider =
    AsyncNotifierProvider<GeneratedPortraitsNotifier, bool>(
      GeneratedPortraitsNotifier.new,
    );

class GeneratedPortraitsNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.generated_portraits';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKey) ?? false;
  }

  Future<void> set({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);
    state = AsyncData(value);
  }
}
