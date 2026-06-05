import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True only while the Speak PERFORMANCE is on screen — AppShell hides the
/// omnibox bar so the transport bar can own the bottom. The input composer is
/// NOT immersive (it keeps the omnibox so you can navigate away while typing).
class SpeakImmersive extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;
  void exit() => state = false;
}

final speakImmersiveProvider = NotifierProvider<SpeakImmersive, bool>(
  SpeakImmersive.new,
);
