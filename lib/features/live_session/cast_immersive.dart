import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while a cast PRESENTATION surface is on screen — the Receiver (the
/// big screen) or the Caster cockpit (the phone). AppShell hides its chrome
/// (the top pills + the bottom omnibox bar) so the presentation/cockpit owns
/// the whole surface — otherwise the floating chrome paints OVER a raw
/// Scaffold's content (the recurring "chrome hides the content" bug).
///
/// The cast LOBBY is NOT immersive — it keeps the chrome so you can navigate
/// away. Same shape as `speakImmersiveProvider`.
class CastImmersive extends Notifier<bool> {
  @override
  bool build() => false;

  /// Reference-counted, so the state cannot depend on the ORDER in which two
  /// screens' deferred lifecycle calls happen to drain.
  ///
  /// Both `enter` and `exit` are deferred out of the build phase by the
  /// mixin below. When one immersive screen replaces another, that leaves
  /// two microtasks in flight — an outgoing `exit` and an incoming `enter` —
  /// and a plain boolean gets the wrong answer whenever they drain in the
  /// order enter-then-exit: chrome reappears over a fullscreen surface.
  /// Counting depth makes the result the same either way.
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

final castImmersiveProvider = NotifierProvider<CastImmersive, bool>(
  CastImmersive.new,
);

/// The *single correct lifecycle* for a fullscreen present/cast surface,
/// as a mixin: enter cast-immersive (app chrome hidden) + OS
/// `immersiveSticky` on mount, restore both on dispose.
///
/// Cache the notifier in `initState` (never touch `ref` in `dispose`) — the
/// cast pattern. The provider write is deferred out of the build phase via a
/// `mounted`-guarded microtask (the chrome trap — see CLAUDE.md), and the
/// immersive OS call stays INSIDE the same microtask so the two stay in
/// lockstep: if the screen pops before the microtask drains, dispose's
/// `exit()` + `edgeToEdge` already ran and we must NOT re-enter.
mixin CastImmersiveScreenState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final CastImmersive _immersive;

  @override
  void initState() {
    super.initState();
    _immersive = ref.read(castImmersiveProvider.notifier);
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        _immersive.enter();
        unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
        );
      }),
    );
  }

  @override
  void dispose() {
    // DEFERRED, like `enter` — and for the same reason. A synchronous write
    // here throws "Tried to modify a provider while the widget tree was
    // building" whenever the screen is torn down during a build/finalize
    // pass, which is exactly what a route pop does. Seen on device
    // (block_present_screen, 2026-08-24).
    //
    // No `mounted` guard: the whole point is that this runs AFTER dispose.
    // Safety comes from the depth counter above, not from a guard.
    final immersive = _immersive;
    unawaited(
      Future.microtask(() {
        immersive.exit();
        unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
        );
      }),
    );
    super.dispose();
  }
}
