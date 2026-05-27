import 'dart:async';
import 'dart:convert';
// Importing dart:io COMPILES on web (stubbed) but any call into
// `WebSocket.connect` throws at runtime. We only reach it from the
// `!kIsWeb` branch in `start()`, so the throw never fires on web.
import 'dart:io' show WebSocket;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// What's currently happening with the user's voice session. Pumped
/// out of [DeepgramVoiceController] as a stream so the omnibox bar
/// can show / hide a "listening" indicator + accumulate the live
/// transcript into the composer text field.
enum VoiceState {
  idle,
  requestingPermission,
  starting,
  listening,
  finalizing,
  error,
}

/// Single emitted update from a live voice session. Combines the
/// running transcript text with the lifecycle state — one Stream so
/// the UI doesn't have to coordinate two separate signals.
class VoiceUpdate {
  const VoiceUpdate({
    required this.state,
    required this.transcript,
    this.errorMessage,
  });

  final VoiceState state;

  /// The cumulative transcript so far. Final segments are appended;
  /// while listening, the most recent interim result is shown at the
  /// end so the user sees their words in real time.
  final String transcript;

  /// Set when [state] is [VoiceState.error]. UI surfaces this in a
  /// snackbar; the controller transitions back to idle on the next
  /// `start()`.
  final String? errorMessage;
}

/// Provider exposing a singleton controller — voice is a global
/// resource (one mic at a time) so we share state across screens.
final Provider<DeepgramVoiceController> deepgramVoiceProvider =
    Provider<DeepgramVoiceController>((ref) {
  final ctrl = DeepgramVoiceController();
  ref.onDispose(ctrl.dispose);
  return ctrl;
});

/// Streams audio from the device mic to Deepgram's live-transcription
/// WebSocket endpoint and surfaces interim + final transcripts back
/// to listeners. Stop the session by calling `stop()` — emits a
/// final `VoiceUpdate(state: idle)` once the WS connection drains.
///
/// Lifecycle: only one session at a time. Calling `start()` while a
/// previous session is live silently no-ops (the UI's mic affordance
/// should already be in "stop" state).
///
/// Config: requires the `voice-token` Supabase Edge Function deployed
/// + its `DEEPGRAM_API_KEY` secret set. The master key NEVER ships in
/// the app — the controller calls the broker, receives a 30-second
/// token, and uses that to open the streaming WebSocket. See
/// `docs/SECRETS.md` and `supabase/functions/voice-token/`.
///
/// Auth: the broker call uses the user's Supabase session JWT. An
/// unauthenticated caller receives "Voice dictation requires
/// sign-in." and stays in idle.
class DeepgramVoiceController {
  DeepgramVoiceController({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  WebSocketChannel? _channel;
  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<dynamic>? _wsSub;

  final StreamController<VoiceUpdate> _updates =
      StreamController<VoiceUpdate>.broadcast();

  String _finalTranscript = '';
  String _interimTranscript = '';
  VoiceState _state = VoiceState.idle;

  Stream<VoiceUpdate> get updates => _updates.stream;
  bool get isActive =>
      _state != VoiceState.idle && _state != VoiceState.error;

  /// Begin recording + streaming. Audio is sent to Deepgram as
  /// 16-bit signed little-endian PCM at 16 kHz mono — the format
  /// Deepgram's `linear16` encoding parameter expects.
  Future<void> start() async {
    if (isActive) return;
    _finalTranscript = '';
    _interimTranscript = '';

    // Wave 150: permission_handler is a no-op stub on web — the
    // browser's getUserMedia prompt fires inside _recorder.startStream
    // below, which is the real gate. On native this is the actual
    // mic-permission request. Either way it's safe to call.
    _setState(VoiceState.requestingPermission);
    if (!kIsWeb) {
      final granted = await Permission.microphone.request();
      if (!granted.isGranted) {
        _emitError('Microphone permission was declined.');
        return;
      }
    }

    _setState(VoiceState.starting);

    // Ask our Edge Function for a short-lived Deepgram token. The
    // master key lives on the function (Supabase secret); the client
    // only ever sees a ≤30-second token scoped to a single
    // connection. Leak surface is bounded to that 30s window.
    final String tempToken;
    try {
      tempToken = await _fetchShortLivedToken();
    } on _VoiceTokenException catch (e) {
      _emitError(e.message);
      return;
    }

    try {
      // Open the Deepgram live-transcription WebSocket. The URL
      // params tell Deepgram what audio format we're sending and
      // what we want back. `interim_results=true` gives us partial
      // transcripts as the user is still talking; `endpointing` is
      // the silence-detection window before Deepgram finalizes a
      // segment.
      final uri = Uri.parse(
        'wss://api.deepgram.com/v1/listen'
        '?encoding=linear16'
        '&sample_rate=16000'
        '&channels=1'
        '&model=nova-2'
        '&interim_results=true'
        '&smart_format=true'
        '&endpointing=600',
      );
      // Wave 151: Deepgram's `/v1/auth/grant` returns a JWT-shaped
      // access_token that authenticates via `Authorization: Bearer
      // <token>`. The original code used `Token` (the project-key
      // scheme), and Wave 150 tried the WebSocket subprotocol path
      // which Deepgram only documents for project keys. Use Bearer
      // on native (proven shape), keep subprotocol on web because
      // browsers can't set arbitrary headers; the short-lived
      // ≤30 s single-connection token bounds the credential
      // exposure either way.
      final WebSocketChannel channel;
      if (kIsWeb) {
        channel = WebSocketChannel.connect(
          uri,
          protocols: <String>['bearer', tempToken],
        );
        try {
          await channel.ready;
        } on Object catch (e, st) {
          if (kDebugMode) {
            debugPrint('[deepgram] web WS ready failed: $e\n$st');
          }
          rethrow;
        }
      } else {
        final socket = await WebSocket.connect(
          uri.toString(),
          headers: <String, dynamic>{
            'Authorization': 'Bearer $tempToken',
          },
        );
        channel = IOWebSocketChannel(socket);
      }
      // If `cancel()` (or another `stop()`) fired while the connect
      // was in flight — possible on fast nav or low-memory eviction
      // — `_teardown()` already nulled out `_channel`. Without this
      // guard we'd happily install a fresh channel that nobody owns
      // any more; the mic + WS would leak.
      if (_state == VoiceState.idle) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      if (kDebugMode) {
        debugPrint('[deepgram] WS open — listening for transcripts');
      }
      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: (Object e, StackTrace st) {
          if (kDebugMode) {
            debugPrint('[deepgram] ws error: $e');
          }
          _emitError('Voice connection dropped.');
          unawaited(_teardown());
        },
        onDone: () {
          // Stream closed. Emit a final idle update so the UI clears
          // the indicator — whether the user explicitly stopped
          // (state was already `finalizing`) or the server dropped
          // mid-session (state was `listening`, network blip /
          // Deepgram timeout). Without the unconditional return-to-
          // idle, a mid-session drop leaves the mic icon stuck red.
          if (isActive) {
            _setState(VoiceState.idle);
          }
        },
      );

      // Start the mic. PCM 16kHz mono → matches the WS encoding.
      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _setState(VoiceState.listening);

      _audioSub = audioStream.listen(
        (bytes) {
          // Forward raw PCM chunks straight to Deepgram. Each chunk
          // is a few hundred bytes from the platform mic; WS frames
          // them per-message which is fine for Deepgram's parser.
          final ch = _channel;
          if (ch == null) return;
          ch.sink.add(bytes);
        },
        onError: (Object e, StackTrace st) {
          if (kDebugMode) {
            debugPrint('[deepgram] audio error: $e');
          }
          _emitError('Microphone error.');
          unawaited(_teardown());
        },
      );
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[deepgram] start failed: $e\n$st');
      }
      _emitError('Could not start voice — try again.');
      await _teardown();
    }
  }

  /// End the session. Stops the mic, tells Deepgram to flush its
  /// buffer (via the `CloseStream` control message), then closes
  /// the WebSocket. The final transcript update lands when
  /// Deepgram sends its last `is_final` segment.
  Future<void> stop() async {
    if (!isActive) return;
    _setState(VoiceState.finalizing);
    // Tell Deepgram we're done so it flushes whatever it has
    // buffered. We DON'T close the WS yet — wait for Deepgram to
    // emit its final segments first.
    final ch = _channel;
    if (ch != null) {
      ch.sink.add(jsonEncode({'type': 'CloseStream'}));
    }
    await _recorder.stop();
    await _audioSub?.cancel();
    _audioSub = null;
    // Give Deepgram a beat to flush, then drop the connection.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _teardown();
  }

  /// Cancel without finalizing — used when the user navigates away
  /// or the screen disposes mid-session. Drops everything fast.
  Future<void> cancel() async {
    await _teardown();
    _finalTranscript = '';
    _interimTranscript = '';
    _setState(VoiceState.idle);
  }

  Future<void> dispose() async {
    // Flip state to idle BEFORE the async teardown so an in-flight
    // `start()` aborts at its existing `if (_state == VoiceState.idle)`
    // guard (line ~160) instead of installing a fresh `_channel` over
    // a disposed controller — that path would leak the WS socket and
    // the audio recorder. The closed `_updates` controller is already
    // guarded by `isClosed` checks in `_emit` / `_emitError`, so no
    // events would land in user-visible state; this prevents the
    // underlying resource leak.
    _state = VoiceState.idle;
    await _teardown();
    await _updates.close();
    await _recorder.dispose();
  }

  // ----- internals -----

  void _onWsMessage(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return;
    }
    final type = json['type'];
    if (type != 'Results') return;
    final isFinal = json['is_final'] == true;
    final channel = json['channel'] as Map<String, dynamic>?;
    final alts = channel?['alternatives'] as List<dynamic>?;
    if (alts == null || alts.isEmpty) return;
    final first = alts.first as Map<String, dynamic>;
    final text = (first['transcript'] as String?) ?? '';
    if (text.isEmpty) return;
    if (isFinal) {
      // Append finalized segment with a trailing space so
      // subsequent segments don't collide on word boundaries.
      _finalTranscript = '${_finalTranscript.trimRight()} $text'.trim();
      _interimTranscript = '';
    } else {
      _interimTranscript = text;
    }
    _emit();
  }

  void _emit() {
    if (_updates.isClosed) return;
    final combined = [
      _finalTranscript,
      _interimTranscript,
    ].where((s) => s.isNotEmpty).join(' ');
    _updates.add(VoiceUpdate(state: _state, transcript: combined));
  }

  void _emitError(String message) {
    _state = VoiceState.error;
    if (_updates.isClosed) return;
    _updates.add(
      VoiceUpdate(
        state: VoiceState.error,
        transcript: _finalTranscript,
        errorMessage: message,
      ),
    );
  }

  void _setState(VoiceState s) {
    _state = s;
    _emit();
  }

  Future<void> _teardown() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _channel?.sink.close();
    } on Object {
      // Already closed — fine.
    }
    _channel = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  /// Round-trip to our Supabase Edge Function `/voice-token` to mint
  /// a short-lived Deepgram token. The master key lives on the
  /// function (Supabase secret); the client never sees it.
  ///
  /// Throws [_VoiceTokenException] with a user-friendly message when
  /// the user isn't signed in, the function isn't deployed, or
  /// Deepgram rejects the grant. The caller surfaces the message via
  /// `_emitError` so the omnibox shows a snackbar.
  Future<String> _fetchShortLivedToken() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw const _VoiceTokenException(
        'Voice dictation requires sign-in.',
      );
    }

    final FunctionResponse response;
    try {
      response = await supabase.functions.invoke(
        'voice-token',
        body: <String, dynamic>{},
      );
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint('[deepgram] broker error: ${e.status} ${e.details}');
      }
      throw _VoiceTokenException(
        e.status == 401
            ? 'Voice dictation requires sign-in.'
            : 'Voice dictation is temporarily unavailable.',
      );
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[deepgram] broker network error: $e\n$st');
      }
      throw const _VoiceTokenException(
        'Could not reach voice service. Check your connection.',
      );
    }

    final data = response.data;
    final token = data is Map<String, dynamic>
        ? data['access_token'] as String? ?? ''
        : '';
    if (token.isEmpty) {
      throw const _VoiceTokenException(
        'Voice dictation is temporarily unavailable.',
      );
    }
    return token;
  }
}

/// Internal exception type — carries a user-facing message that the
/// controller forwards verbatim to `_emitError`. Not exported because
/// callers don't need to distinguish broker failures from other
/// voice errors; they all surface the same way.
class _VoiceTokenException implements Exception {
  const _VoiceTokenException(this.message);
  final String message;
}
