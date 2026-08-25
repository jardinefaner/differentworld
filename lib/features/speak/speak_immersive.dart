import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True only while the Speak PERFORMANCE is on screen — AppShell hides the
/// omnibox bar so the transport bar can own the bottom. The input composer is
/// NOT immersive (it keeps the omnibox so you can navigate away while typing).
class SpeakImmersive extends Notifier<bool> {
  @override
  bool build() => false;

  /// Reference-counted for the same reason as `CastImmersive`: `exit` is
  /// deferred out of the build phase by its callers, so two screens handing
  /// over can leave an outgoing exit and an incoming enter in flight at
  /// once. Counting depth makes the result order-independent.
  int _depth = 0;

  void enter() {
    _depth++;
    if (!ref.mounted) return;
    state = true;
  }

  void exit() {
    if (_depth > 0) _depth--;
    // Both calls are DEFERRED by their callers, so either can land after the
    // provider itself is gone — a container teardown, or the last listener
    // dropping. Writing `state` then throws UnmountedRefException. The depth
    // still decrements: it costs nothing and keeps the count honest if the
    // provider is somehow revived.
    if (!ref.mounted) return;
    state = _depth > 0;
  }
}

final speakImmersiveProvider = NotifierProvider<SpeakImmersive, bool>(
  SpeakImmersive.new,
);
