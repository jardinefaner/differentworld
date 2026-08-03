import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The controller code THIS device follows as a room screen (the cast
/// receiver), or null if it isn't a screen. Set once on the TV/tablet; the app
/// auto-resumes into receiver mode on the same controller on launch
/// (docs/LIVE_SESSIONS.md — "set the screen once, then just cast").
///
/// ACCOUNT-scoped per device (2026-08-02): the pref key carries the member id,
/// so switching accounts on a shared phone never resurrects another account's
/// screen pairing ("the program's key" bug). A dedicated TV tablet signed into
/// one stable account behaves exactly as before. Legacy device-level pairings
/// are dropped — a TV needs its one-time "be a screen" tap again.
final roomScreenFollowsProvider =
    AsyncNotifierProvider<RoomScreenFollowsNotifier, String?>(
      RoomScreenFollowsNotifier.new,
    );

class RoomScreenFollowsNotifier extends AsyncNotifier<String?> {
  static const _keyPrefix = 'cast.roomScreenFollows';

  String? get _key {
    final memberId = ref.read(viewerProvider).memberId;
    return memberId == null ? null : '$_keyPrefix.$memberId';
  }

  @override
  Future<String?> build() async {
    // Rebuild when the signed-in member changes so the pairing follows
    // the account, not the device.
    ref.watch(viewerProvider.select((v) => v.memberId));
    final key = _key;
    if (key == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Follow [controllerCode] as a room screen (persisted across launches).
  Future<void> follow(String controllerCode) async {
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, controllerCode);
    state = AsyncData(controllerCode);
  }

  /// Stop being a room screen.
  Future<void> stop() async {
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    state = const AsyncData(null);
  }
}
