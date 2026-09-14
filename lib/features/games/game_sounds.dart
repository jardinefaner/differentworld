import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// The sounds a stage makes — six tiny bundled tones, and nothing else.
///
/// Simon is the reason this exists: a Simon that lights pads in silence asks
/// a room to remember colours it was never given a sound for, and the 1978
/// game was four notes before it was four colours. The notes are its
/// (E4 · C♯4 · A4 · E3), one per palette slot, so any pads-style board that
/// lights a pad sounds it — Four Corners' chosen corner chimes too.
///
/// Deliberately not a voice and not a model (docs/AI_BOUNDARY.md): an
/// object's sound, generated in-repo from a sine wave, played wherever the
/// stage is drawn. The room's TV plays it; the phone in the host's hand plays
/// it on one device; a controller phone paired to a presenter stays quiet
/// (GameMotion.sound) so the room hears one Simon, not two.
///
/// Every call is fire-and-forget and swallows failure: a missing plugin in a
/// test, a busy audio focus, a platform with no output — none of them may
/// cost a tap. After the first failure the pool disables itself for the
/// session rather than throwing sixty-four times.
enum GameSound { pad1, pad2, pad3, pad4, tap, win }

extension GameSoundAsset on GameSound {
  String get asset => 'assets/audio/$name.wav';

  /// The note for a palette slot (1..4); anything else is silent.
  static GameSound? forSlot(int slot) => switch (slot) {
    1 => GameSound.pad1,
    2 => GameSound.pad2,
    3 => GameSound.pad3,
    4 => GameSound.pad4,
    _ => null,
  };
}

abstract final class GameSounds {
  static final Map<GameSound, AudioPlayer> _players = {};
  static bool _disabled = false;

  /// Play one sound now. Never awaits, never throws.
  static void play(GameSound sound) {
    if (_disabled) return;
    // A guarded zone as well as a try/catch: the plugin's constructor starts
    // platform work it does not hand back, and an error in THAT future would
    // otherwise surface as an uncaught zone error (a test harness with no
    // channel is the case that found it). Everything the pool starts lives in
    // this zone, so a failure anywhere in it lands in [_quiet].
    runZonedGuarded(() => unawaited(_play(sound)), _quiet);
  }

  static Future<void> _play(GameSound sound) async {
    try {
      final player = _players[sound] ??= AudioPlayer();
      if (player.audioSource == null) {
        await player.setAsset(sound.asset);
      }
      await player.seek(Duration.zero);
      await player.play();
    } on Object catch (e, st) {
      _quiet(e, st);
    }
  }

  /// A test harness (no platform channel), a device with no audio output, a
  /// plugin that is not ready — one failure is enough to stay silent for the
  /// session rather than fail sixty-four times.
  static void _quiet(Object e, StackTrace st) {
    if (_disabled) return;
    _disabled = true;
    if (kDebugMode) debugPrint('game sounds off: $e');
  }

  /// For tests: forget the pool so a fresh harness starts clean.
  @visibleForTesting
  static Future<void> reset() async {
    _disabled = false;
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}
