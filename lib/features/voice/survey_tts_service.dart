import 'dart:async';
import 'dart:io' show Directory, File, HttpClient;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wave 120 — TTS playback for the survey-take screen.
///
/// Three-tier cache so we don't hit Deepgram more than once per
/// unique (voice, question) across the platform:
///
/// 1. **In-memory** (this run): a player URI / file path we already
///    resolved for the active session.
/// 2. **Local disk** (per device, NATIVE ONLY): `${appDocs}/tts/
///    {voice}/{q_id}.mp3`. Survives restarts; lets the kid replay
///    even fully offline once the audio's been downloaded once.
/// 3. **Supabase Storage** (shared across the program): the
///    `tts-cache` bucket. First kid in the program to pick Thalia
///    triggers a Deepgram call via the `tts-generate` Edge Function,
///    which writes to the bucket. Every subsequent kid (on any
///    device) reads the cached audio directly via the public URL.
///
/// The lookup is `disk → bucket → generate` on native, `bucket →
/// generate` on web (the browser's own HTTP cache + Supabase CDN
/// edge caching serve the role of the on-device disk cache).
///
/// **Wave 140 — web compat.** The original implementation used
/// `dart:io` exclusively (File / Directory / HttpClient /
/// getApplicationDocumentsDirectory) and crashed silently on web,
/// which manifested as "no audio plays at all on the web build."
/// `resolve()` now branches on `kIsWeb`: web returns the Supabase
/// public URL directly and `play()` routes through `setUrl` so
/// just_audio_web hands it to the browser's HTML5 Audio element.
/// Native keeps the disk-cache path for offline replay.
///
/// **Why a public bucket** (`tts-cache`): the audio is non-PII (the
/// underlying question text already ships in the app bundle); making
/// it public avoids a signed-URL round trip per playback. The audio
/// bytes are derived from text + voice — they leak no kid-specific
/// data. Future direction if we ever want per-program private audio
/// (custom voice clones, school-specific recordings): flip the bucket
/// private and route playback through a signed-URL provider.
class SurveyTtsService {
  SurveyTtsService();

  /// Single shared player instance — survey-take is a one-screen
  /// surface, so we don't need a pool. Stopping the previous play
  /// when a new one starts is the desired behavior anyway (don't
  /// stack voices).
  final AudioPlayer _player = AudioPlayer();

  /// Cache directory on disk (native only; null on web).
  Directory? _cacheDir;

  /// In-flight per-(voice, key) requests so two simultaneous calls
  /// for the same audio (e.g. the same question rendered twice for
  /// some reason) don't both hit the Edge Function.
  final Map<String, Future<TtsSource>> _inFlight = {};

  /// Resolve the source for a cached audio file. On native, returns
  /// a local file path (downloads + caches under appDocs). On web,
  /// returns the Supabase Storage URL directly (no disk caching).
  /// The caller passes the [TtsSource] back to [play] which dispatches
  /// to `setFilePath` or `setUrl` as appropriate.
  ///
  /// Throws if generation fails (no audio playable; caller should
  /// catch + degrade silently — surveys still work without voice).
  Future<TtsSource> resolve({
    required String voiceId,
    required String text,
    required String cacheKey,
  }) {
    final mapKey = '$voiceId|$cacheKey';
    final existing = _inFlight[mapKey];
    if (existing != null) return existing;

    final future = _resolveInner(
      voiceId: voiceId,
      text: text,
      cacheKey: cacheKey,
    );
    _inFlight[mapKey] = future;
    // Clean up the in-flight entry on completion so a future retry
    // (after error) doesn't permanently bind to a failed Future.
    unawaited(future.whenComplete(() => _inFlight.remove(mapKey)));
    return future;
  }

  Future<TtsSource> _resolveInner({
    required String voiceId,
    required String text,
    required String cacheKey,
  }) async {
    // 1. Local disk cache — native only. On web we skip straight to
    //    the Edge Function (the browser's HTTP cache handles repeat
    //    plays).
    if (!kIsWeb) {
      final dir = await _ensureCacheDir(voiceId);
      final localPath = p.join(dir.path, '$cacheKey.mp3');
      final localFile = File(localPath);
      if (localFile.existsSync() && localFile.lengthSync() > 0) {
        return TtsSource.file(localPath);
      }
    }

    // 2. Ask the Edge Function — it'll check the Supabase bucket,
    //    return the URL if cached, or generate fresh.
    final supabase = Supabase.instance.client;
    final invokeResult = await supabase.functions.invoke(
      'tts-generate',
      body: <String, dynamic>{
        'voice': voiceId,
        'text': text,
        'cache_key': cacheKey,
      },
    );

    if (invokeResult.status != 200) {
      throw StateError(
        'tts-generate failed (${invokeResult.status}): '
        '${invokeResult.data}',
      );
    }

    final data = invokeResult.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('tts-generate returned malformed payload');
    }
    final url = data['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('tts-generate returned no url');
    }

    if (kIsWeb) {
      // Web: hand the URL straight to just_audio_web. The browser's
      // own HTTP cache will serve repeat plays from memory.
      return TtsSource.url(url);
    }

    // 3. Native: download to local disk for offline replay + so
    //    subsequent plays skip the network entirely. Use a plain
    //    HTTP GET via Supabase Storage's public CDN.
    final response = await _httpGet(url);
    if (response == null || response.isEmpty) {
      throw StateError('TTS cache fetch returned empty body');
    }
    final dir = await _ensureCacheDir(voiceId);
    final localPath = p.join(dir.path, '$cacheKey.mp3');
    await File(localPath).writeAsBytes(response, flush: true);
    return TtsSource.file(localPath);
  }

  /// Play the audio for the given resolved source. Stops any
  /// in-progress playback first; resolves when playback ends or
  /// the player is stopped.
  ///
  /// Wave 128: just_audio's `setFilePath` races with itself — if a
  /// previous load is still in flight when a new one starts, the
  /// previous one's Future completes with "Loading interrupted."
  /// That's expected when the kid taps multiple voice tiles quickly
  /// or auto-advances through questions. We track the latest play
  /// request with a token; if a newer request started while we were
  /// loading, swallow the interruption silently (the newer play is
  /// the one the user wants). Only real failures bubble to the log.
  int _playToken = 0;
  Future<void> play(TtsSource source) async {
    final myToken = ++_playToken;
    try {
      // Stop any in-progress playback BEFORE set{File,Url} so
      // just_audio doesn't queue up an interrupt internally.
      await _player.stop();
      if (myToken != _playToken) return; // superseded mid-stop
      switch (source.kind) {
        case TtsSourceKind.file:
          await _player.setFilePath(source.value);
        case TtsSourceKind.url:
          await _player.setUrl(source.value);
      }
      if (myToken != _playToken) return; // superseded mid-load
      await _player.play();
    } on PlayerInterruptedException catch (_) {
      // Expected: a newer play() call superseded this one. Silent.
    } on Object catch (e, st) {
      // Some real failures surface as a plain Exception with the
      // message "Loading interrupted." (Older just_audio versions
      // don't always throw PlayerInterruptedException.) Treat the
      // string-match as benign too.
      final msg = e.toString();
      if (msg.contains('interrupted') || myToken != _playToken) return;
      if (kDebugMode) {
        debugPrint('[survey-tts] play failed: $e\n$st');
      }
    }
  }

  /// Stop any in-progress playback. Idempotent.
  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object catch (_) {
      // best-effort
    }
  }

  /// Wave 149: set output volume in the [0.0, 1.0] range. The
  /// About-you page wires its slider here so a director can dial
  /// down for a loud cohort. just_audio accepts setVolume even
  /// before a source is loaded — safe to call at any time.
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } on Object catch (_) {
      // best-effort
    }
  }

  /// Dispose the player. Call from the survey-take screen's
  /// dispose. The service itself is one-per-screen via a Riverpod
  /// `autoDispose` provider, so this fires automatically.
  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<Directory> _ensureCacheDir(String voiceId) async {
    assert(!kIsWeb, '_ensureCacheDir is native-only — web has no disk');
    var root = _cacheDir;
    if (root == null) {
      final appDocs = await getApplicationDocumentsDirectory();
      root = Directory(p.join(appDocs.path, 'tts'));
      _cacheDir = root;
    }
    final voiceDir = Directory(p.join(root.path, voiceId));
    if (!voiceDir.existsSync()) {
      await voiceDir.create(recursive: true);
    }
    return voiceDir;
  }

  Future<List<int>?> _httpGet(String url) async {
    assert(!kIsWeb, '_httpGet uses dart:io HttpClient — native only');
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        client.close();
        return null;
      }
      final bytes = <int>[];
      await resp.forEach(bytes.addAll);
      client.close();
      return bytes;
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[survey-tts] download failed for $url: $e\n$st');
      }
      return null;
    }
  }
}

/// Tagged-union source for `SurveyTtsService.play`. On native the
/// service returns a local file path (post-download); on web it
/// returns the Supabase Storage URL directly. `play` dispatches
/// to just_audio's `setFilePath` / `setUrl` accordingly.
class TtsSource {
  const TtsSource._(this.kind, this.value);
  factory TtsSource.file(String path) => TtsSource._(TtsSourceKind.file, path);
  factory TtsSource.url(String url) => TtsSource._(TtsSourceKind.url, url);

  final TtsSourceKind kind;
  final String value;
}

enum TtsSourceKind { file, url }

// Wave 130: the `surveyTtsServiceProvider` used to live here as a
// `Provider.autoDispose<SurveyTtsService>`. That was wrong: survey-
// take only calls `ref.read(...)` (never `watch`), so the autoDispose
// provider had zero subscribers, was disposed between reads, and the
// underlying just_audio AudioPlayer was torn down mid-load every
// time the kid tapped a voice tile. The Android logs showed:
//   ExoPlayerImpl: Init  <hash>
//   ExoPlayerImpl: Release <hash>
// back-to-back with no audio. Kids picked a voice and heard nothing.
//
// Fix: the service is now held as a State field in survey_take_
// screen, instantiated once in initState and disposed in dispose.
// No provider needed — the service has no Riverpod-side deps and
// nothing else in the app uses it.
