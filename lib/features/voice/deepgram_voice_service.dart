import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;

import 'package:differentworld/core/env/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
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
/// Config: requires `DEEPGRAM_API_KEY` in env. Without it `start()`
/// immediately emits an error update and stays in idle.
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

    if (!Env.hasDeepgram) {
      _emitError(
        'Voice dictation is not configured. '
        'Set DEEPGRAM_API_KEY in your env to enable it.',
      );
      return;
    }

    _setState(VoiceState.requestingPermission);
    final granted = await Permission.microphone.request();
    if (!granted.isGranted) {
      _emitError('Microphone permission was declined.');
      return;
    }

    _setState(VoiceState.starting);
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
      // Pass the API key via Authorization header rather than the
      // WebSocket subprotocol. Subprotocols ride the WS upgrade in
      // `Sec-WebSocket-Protocol`, which is plaintext in network
      // proxies / OS diagnostic logs — credential-exposure risk.
      // `IOWebSocketChannel.connect` accepts headers on native
      // platforms; on web (where dart:io isn't available) Deepgram's
      // subprotocol fallback is the only option.
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: <String, dynamic>{
          'Authorization': 'Token ${Env.deepgramApiKey}',
        },
      );
      _channel = IOWebSocketChannel(socket);
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
}
