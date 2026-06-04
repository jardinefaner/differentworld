import 'dart:async';

import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Drives the Speak feature. Asks the `tts-subtitles` Edge Function
/// (ElevenLabs `with-timestamps`, key brokered server-side per
/// docs/SECRETS.md) to synthesize + time a prompt, then plays it via
/// just_audio. Audio + alignment are cached server-side, so a repeated prompt
/// replays instantly. Ephemeral: only the teacher's prompt text is sent — no
/// child PII — and nothing persists on the device.
class SpeakService {
  final AudioPlayer _player = AudioPlayer();
  bool _disposed = false;

  /// The audio position as a stream (~5/sec). Coarse — fine for a progress
  /// readout, too steppy for word-accurate highlighting; the stage reads
  /// [currentPosition] per frame instead.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Whether audio is currently playing (drives the play/pause affordance).
  Stream<bool> get playingStream => _player.playingStream;

  /// The instantaneous playback position — read every frame by the stage's
  /// ticker so word/line flips land on the voice, not up to 200ms late.
  Duration get currentPosition => _player.position;

  /// Whether audio is currently advancing (lets the stage idle its ticker).
  bool get isPlaying => _player.playing;

  /// Synthesize [text] (optionally a specific [voiceId]) into a timed script.
  /// Throws on failure — the screen catches and shows the not-set-up / error
  /// state (Speak is an enhancement; nothing else depends on it).
  Future<SpokenScript> synthesize({
    required String text,
    String? voiceId,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'tts-subtitles',
      body: <String, dynamic>{
        'text': text,
        'voice': ?voiceId,
      },
    );
    if (res.status != 200) {
      throw StateError('tts-subtitles failed (${res.status})');
    }
    final data = res.data;
    if (data is! Map) throw StateError('tts-subtitles returned malformed data');
    final map = data.cast<String, dynamic>();
    final url = map['url'];
    final align = map['alignment'];
    if (url is! String || url.isEmpty || align is! Map) {
      throw StateError('tts-subtitles returned no url / alignment');
    }
    final a = align.cast<String, dynamic>();
    List<double> seconds(Object? v) =>
        (v as List? ?? const []).map((e) => (e as num).toDouble()).toList();
    final words = wordsFromAlignment(
      characters: (a['characters'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      startSeconds: seconds(a['character_start_times_seconds']),
      endSeconds: seconds(a['character_end_times_seconds']),
    );
    return SpokenScript(audioUrl: url, words: words);
  }

  /// Load + play a script from the top. Stops any current playback first.
  /// Best-effort: a playback failure degrades to a still (un-highlighted)
  /// karaoke view rather than throwing — the screen has already left the
  /// input/error state by the time this runs, so there's nothing to surface.
  /// `just_audio`'s `play()` future completes only at end-of-audio, so callers
  /// fire this unawaited.
  Future<void> play(SpokenScript script) async {
    try {
      await _player.stop();
      await _player.setUrl(script.audioUrl);
      await _player.play();
    } on PlayerInterruptedException catch (_) {
      // A newer play() superseded this one — expected, silent.
    } on Object catch (e, st) {
      if (kDebugMode) debugPrint('[speak] play failed: $e\n$st');
    }
  }

  Future<void> replay() async {
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object catch (_) {
      // best-effort
    }
  }

  /// Idempotent — `State.dispose()` fires this unawaited, and a stray
  /// in-flight `play()` could also race it; calling `_player.dispose()` twice
  /// throws, so guard it.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _player.dispose();
  }
}
