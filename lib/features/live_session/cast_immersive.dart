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
