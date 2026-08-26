import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether this person's navigation is trimmed to the first-week
/// essentials (docs/STARTING_SIMPLE.md).
///
/// The app is 64 feature folders and 157 screens. For a director who built
/// the program that is a toolbox; for a teacher on their first Monday it is
/// a wall, and the honest failure mode is not "they get lost" but "they
/// stop opening it". This trims the NAV — not the app — to the handful of
/// destinations that make sense before you have any history.
///
/// **What it must never do is take a capability away.** The omnibox still
/// reaches all 116 entries, every route is still deep-linkable, and nothing
/// is disabled. Search is the escape hatch that makes this a starting point
/// rather than a cage: type "photos" and you get photos, whether or not the
/// drawer is showing it. Hiding a destination is a statement about what is
/// worth putting in front of someone today, not about what they may do.
///
/// Defaults to OFF. Turning it on for everyone would shrink the app under
/// people who already know their way around it, which is a worse failure
/// than the one it fixes. Who gets OFFERED it, and when, is a separate
/// question from what it does — see the setting's row in Settings.
///
/// Device-local (SharedPreferences), consistent with every other display
/// preference here — text size, outdoor mode, the schedule grid. A teacher
/// picking up a second device gets the full app, which is the safe
/// direction to be wrong in.
final startingSimpleProvider =
    AsyncNotifierProvider<StartingSimpleNotifier, bool>(
      StartingSimpleNotifier.new,
    );

class StartingSimpleNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.starting_simple';

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

  /// Turn the trim on for someone who has just joined a program they did
  /// not create — the one moment the app can be sure it is looking at a
  /// newcomer, rather than inferring it from activity counts.
  ///
  /// A settings toggle is not onboarding: the person who most needs this
  /// will never go looking for it. This is what makes it reach them.
  ///
  /// **Never overrides a choice.** `containsKey` is doing the real work —
  /// once someone has turned this off, re-accepting an invite (a second
  /// program, a re-issued link) must not quietly shrink their app again.
  Future<void> adoptForNewcomer() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_kKey)) return;
    await prefs.setBool(_kKey, true);
    state = const AsyncData(true);
  }
}

/// Whether the "showing the basics" note on Today has been acknowledged.
///
/// Separate from the trim itself because dismissing the explanation and
/// leaving the trim on is the common case — you understood, you are happy,
/// stop telling me. A note that cannot be dismissed becomes a sign on a
/// wall (CLAUDE.md, the half-second rule).
final startingSimpleNoteSeenProvider =
    AsyncNotifierProvider<StartingSimpleNoteSeenNotifier, bool>(
      StartingSimpleNoteSeenNotifier.new,
    );

class StartingSimpleNoteSeenNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.starting_simple_note_seen';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, true);
    state = const AsyncData(true);
  }
}
