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

  void enter() => state = true;
  void exit() => state = false;
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
    _immersive.exit();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }
}
