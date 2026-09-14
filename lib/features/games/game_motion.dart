import 'dart:async';

import 'package:differentworld/shared/prefs_bool_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Whether a stage moves.** One switch for the deal-in, the flips, the
/// glow, the celebration burst and the haptic taps — read by the shared
/// renderer and the wrap beat through [GameMotion.of].
///
/// Three things turn it off, and the renderer treats them as one:
/// - the OS "reduce motion" setting (`MediaQuery.disableAnimations`), which
///   is an accessibility contract and always wins;
/// - Settings → Preferences → Game motion, the per-device switch (the
///   "ship new looks as toggles" rule — the boards animate by default, and one
///   tap returns them to the still boards they were);
/// - a surface that asks for stillness — a golden plate, a printed sheet.
///
/// Haptics are a separate flag because they belong to the PHONE in the
/// host's hand, never to the room's screen: a wall-mounted tablet buzzing on
/// every tap is a fault, not a feature.
class GameMotion extends InheritedWidget {
  const GameMotion({
    required this.enabled,
    required super.child,
    this.haptics = true,
    this.sound = true,
    super.key,
  });

  /// Whether the boards animate at all.
  final bool enabled;

  /// Whether taps and endings buzz — the phone yes, the receiver no.
  final bool haptics;

  /// Whether the stage makes its sounds (Simon's notes, the win chime). On
  /// wherever the ROOM hears the stage — one device, or the receiver — and
  /// off on a controller phone paired to a presenter, so the room hears one
  /// Simon rather than two out of step. Follows [enabled]: the Preferences
  /// switch turns the sounds off with the motion.
  final bool sound;

  /// Motion on, unless this device or this surface said otherwise. Absent
  /// (no [GameMotion] above) means ON — the default look is the alive one.
  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GameMotion>();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    return scope?.enabled ?? true;
  }

  /// The same answer as [of], WITHOUT registering a dependency — for
  /// lifecycle hooks (`initState`, `didUpdateWidget`, a timer callback).
  /// `of` subscribes the caller to GameMotion AND MediaQuery, which is right
  /// in `build` and wrong in a hook: sixty-four board cells subscribing from
  /// `didUpdateWidget` meant sixty-four rebuilds every time the keyboard
  /// opened or the phone turned, for a value their `build` never reads.
  static bool read(BuildContext context) {
    final mq = context.getInheritedWidgetOfExactType<MediaQuery>();
    if (mq?.data.disableAnimations ?? false) return false;
    final scope = context.getInheritedWidgetOfExactType<GameMotion>();
    return scope?.enabled ?? true;
  }

  /// Haptics on — phone-side surfaces only.
  static bool hapticsOf(BuildContext context) {
    // Non-registering: read from tap handlers and the done edge, never build.
    final scope = context.getInheritedWidgetOfExactType<GameMotion>();
    return scope?.haptics ?? true;
  }

  /// Sound on — where the room hears the stage, and only while the
  /// Preferences switch is on.
  static bool soundOf(BuildContext context) {
    // Non-registering, like [read]: every caller is a lifecycle hook.
    final scope = context.getInheritedWidgetOfExactType<GameMotion>();
    if (scope == null) return true;
    return scope.enabled && scope.sound;
  }

  @override
  bool updateShouldNotify(GameMotion oldWidget) =>
      enabled != oldWidget.enabled ||
      haptics != oldWidget.haptics ||
      sound != oldWidget.sound;
}

/// The per-device switch — Settings → Preferences → Game motion. Default ON.
final gameMotionProvider = AsyncNotifierProvider<GameMotionNotifier, bool>(
  GameMotionNotifier.new,
);

class GameMotionNotifier extends PrefsBoolNotifier {
  @override
  String get prefsKey => 'settings.game_motion';

  @override
  bool get defaultValue => true;
}

/// The Preferences row.
class GameMotionTile extends ConsumerWidget {
  const GameMotionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(gameMotionProvider).value ?? true;
    return SwitchListTile(
      secondary: const Icon(Icons.animation_outlined),
      title: const Text('Game motion and sound'),
      subtitle: const Text(
        'Boards deal in, discs drop, Simon plays its notes, a round ends '
        'with a burst. Off keeps every board still and silent.',
      ),
      value: on,
      onChanged: (v) =>
          unawaited(ref.read(gameMotionProvider.notifier).set(value: v)),
    );
  }
}
