import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether THIS device is the program's persistent **room screen** (the cast
/// receiver). Set once on the TV/tablet; the app auto-resumes into receiver
/// mode on launch so it's never set up again (docs/LIVE_SESSIONS.md — "set the
/// screen once, then just cast"). Per-device (SharedPreferences), not synced —
/// being the screen is a property of the physical device, not the account.
final roomScreenProvider =
    AsyncNotifierProvider<RoomScreenNotifier, bool>(RoomScreenNotifier.new);

class RoomScreenNotifier extends AsyncNotifier<bool> {
  static const _key = 'cast.roomScreen';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> set({required bool isScreen}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isScreen);
    state = AsyncData(isScreen);
  }
}
