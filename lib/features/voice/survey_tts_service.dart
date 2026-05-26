import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// 2. **Local disk** (per device): `${appDocs}/tts/{voice}/{q_id}.mp3`.
///    Survives restarts; lets the kid replay even fully offline once
///    the audio's been downloaded once.
/// 3. **Supabase Storage** (shared across the program): the
///    `tts-cache` bucket. First kid in the program to pick Thalia
///    triggers a Deepgram call via the `tts-generate` Edge Function,
///    which writes to the bucket. Every subsequent kid (on any
///    device) reads the cached audio directly via the public URL.
///
/// The lookup is `disk → bucket → generate`. The Edge Function
/// internally does `bucket → deepgram` so we end up at one Deepgram
/// call per unique (voice, cache_key) ever.
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

  /// Cache directory on disk. Resolved lazily on first call.
  Directory? _cacheDir;

  /// In-flight per-(voice, key) requests so two simultaneous calls
  /// for the same audio (e.g. the same question rendered twice for
  /// some reason) don't both hit the Edge Function.
  final Map<String, Future<String>> _inFlight = {};

  /// Resolve the path for a cached audio file, fetching from the
  /// Supabase cache or generating fresh if needed. Returns a file
  /// PATH (local) — the caller passes it to `just_audio` via
  /// `setFilePath`.
  ///
  /// Throws if generation fails (no audio playable; caller should
  /// catch + degrade silently — surveys still work without voice).
  Future<String> resolve({
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

  Future<String> _resolveInner({
    required String voiceId,
    required String text,
    required String cacheKey,
  }) async {
    final dir = await _ensureCacheDir(voiceId);
    final localPath = p.join(dir.path, '$cacheKey.mp3');
    final localFile = File(localPath);

    // 1. Local disk cache. existsSync is fine here — this fires
    // once per question on display, not in a hot loop.
    if (localFile.existsSync() && localFile.lengthSync() > 0) {
      return localPath;
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

    // 3. Download to local disk for offline replay + so subsequent
    //    plays skip the network entirely. Use a plain HTTP GET via
    //    Supabase storage's public CDN.
    final response = await _httpGet(url);
    if (response == null || response.isEmpty) {
      throw StateError('TTS cache fetch returned empty body');
    }
    await localFile.writeAsBytes(response, flush: true);
    return localPath;
  }

  /// Play the audio for the given resolved file path. Stops any
  /// in-progress playback first; resolves when playback ends or
  /// the player is stopped.
  Future<void> play(String filePath) async {
    try {
      await _player.stop();
      await _player.setFilePath(filePath);
      await _player.play();
    } on Object catch (e, st) {
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

  /// Dispose the player. Call from the survey-take screen's
  /// dispose. The service itself is one-per-screen via a Riverpod
  /// `autoDispose` provider, so this fires automatically.
  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<Directory> _ensureCacheDir(String voiceId) async {
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

/// One instance per screen — autoDispose so the player is torn down
/// when the kid leaves the survey.
// ignore: specify_nonobvious_property_types
final surveyTtsServiceProvider = Provider.autoDispose<SurveyTtsService>(
  (ref) {
    final svc = SurveyTtsService();
    ref.onDispose(() => unawaited(svc.dispose()));
    return svc;
  },
);
