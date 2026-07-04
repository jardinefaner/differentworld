import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The controller code THIS device follows as a room screen (the cast
/// receiver), or null if it isn't a screen. Set once on the TV/tablet; the app
/// auto-resumes into receiver mode on the same controller on launch
/// (docs/LIVE_SESSIONS.md — "set the screen once, then just cast"). Per-device
/// (SharedPreferences), not synced — being a screen is a property of the
/// physical device, not the account.
final roomScreenFollowsProvider =
    AsyncNotifierProvider<RoomScreenFollowsNotifier, String?>(
      RoomScreenFollowsNotifier.new,
    );

class RoomScreenFollowsNotifier extends AsyncNotifier<String?> {
  static const _key = 'cast.roomScreenFollows';

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// Follow [controllerCode] as a room screen (persisted across launches).
  Future<void> follow(String controllerCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, controllerCode);
    state = AsyncData(controllerCode);
  }

  /// Stop being a room screen.
  Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData(null);
  }
}
