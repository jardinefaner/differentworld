import 'dart:async';

import 'package:differentworld/features/live_session/live_session.dart'
    show LiveStatus;
import 'package:supabase_flutter/supabase_flutter.dart';

/// The anonymous brainstorm / agenda board (docs/VISION.md #5,
/// LIVE_SESSIONS.md): phones post ideas to a shared wall over Supabase
/// Realtime broadcast — with **no sender identity on the wire**, so the room
/// can "look at things together" without ego. Ephemeral coordination, not
/// PowerSync (same documented exception as the games' LiveSession).
///
/// Append-only (no authoritative reducer): every device accumulates `idea`
/// broadcasts locally. `self: true` so a poster sees their own idea land.
/// Anonymity is by construction — the payload is just `{text}`.
enum BoardRole { present, contribute }

class BoardSession {
  BoardSession._(this._channel, this.role, this.code);

  factory BoardSession.open({
    required SupabaseClient client,
    required BoardRole role,
    required String code,
  }) {
    final channel = client.channel(
      topicFor(code),
      opts: const RealtimeChannelConfig(self: true),
    );
    return BoardSession._(channel, role, code).._wire();
  }

  final RealtimeChannel _channel;
  final BoardRole role;
  final String code;

  final List<String> _ideas = [];

  final _ideas$ = StreamController<List<String>>.broadcast();
  Stream<List<String>> get ideas => _ideas$.stream;

  final _peers = StreamController<int>.broadcast();
  Stream<int> get peers => _peers.stream;

  final _status = StreamController<LiveStatus>.broadcast();
  Stream<LiveStatus> get status => _status.stream;

  static String topicFor(String code) => 'dw-board-${code.toUpperCase()}';

  void _wire() {
    _channel
        .onBroadcast(
          event: 'idea',
          callback: (payload) {
            final text = (payload['text'] as String?)?.trim();
            if (text != null && text.isNotEmpty) {
              _ideas.insert(0, text); // newest first
              if (!_ideas$.isClosed) _ideas$.add(List.unmodifiable(_ideas));
            }
          },
        )
        .onPresenceSync((_) => _peers.add(_channel.presenceState().length))
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _status.add(LiveStatus.live);
            unawaited(_channel.track({'role': role.name}));
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            _status.add(LiveStatus.error);
          }
        });
    _status.add(LiveStatus.connecting);
  }

  /// Post an idea to the wall — anonymously (no sender id on the wire).
  void post(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    unawaited(_send(t));
  }

  Future<void> _send(String text) async {
    try {
      await _channel.sendBroadcastMessage(
        event: 'idea',
        payload: {'text': text},
      );
    } on Object catch (_) {
      // Best-effort; an unsent idea just doesn't appear (no persistence).
    }
  }

  Future<void> dispose() async {
    await _channel.unsubscribe();
    await _ideas$.close();
    await _peers.close();
    await _status.close();
  }
}
