import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The program-wide live LOBBY (docs/LIVE_SESSIONS.md "One place to join").
///
/// A second Realtime presence channel, separate from any one session
/// (`dw-session-<CODE>`): every presenter ANNOUNCES its session here so any
/// device in the program can DISCOVER what's live and join — without first
/// knowing which game it is. Ephemeral coordination only (no PowerSync, no
/// durable rows), the documented Supabase-direct exception. No child PII on
/// the wire — just a join code, a game id, and the presenter's name.
///
/// Topic: `dw-live-<spaceId>`. Presenters `track({code, game, presenter})`;
/// watchers subscribe WITHOUT tracking (so they never appear as a session) and
/// read the presence list.
String lobbyTopicFor(String spaceId) => 'dw-live-$spaceId';

/// One live session as advertised in the lobby.
@immutable
class LiveSessionAd {
  const LiveSessionAd({
    required this.code,
    required this.game,
    required this.presenter,
  });

  /// The session join code (the `dw-session-<code>` channel).
  final String code;

  /// The game id — resolve to a `GameDefinition` via `gameById`.
  final String game;

  /// The presenter's display name (for "Maya is presenting Charades").
  final String presenter;

  @override
  bool operator ==(Object other) =>
      other is LiveSessionAd &&
      other.code == code &&
      other.game == game &&
      other.presenter == presenter;

  @override
  int get hashCode => Object.hash(code, game, presenter);
}

/// Presenter side — announces one session to the program lobby until disposed.
class LobbyAnnouncer {
  LobbyAnnouncer._(this._channel);

  /// Join the lobby + track this session. Returns immediately; the track fires
  /// once the channel subscribes.
  factory LobbyAnnouncer.announce({
    required SupabaseClient client,
    required String spaceId,
    required String code,
    required String game,
    required String presenter,
  }) {
    final channel = client.channel(lobbyTopicFor(spaceId));
    channel.subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(
          channel.track({'code': code, 'game': game, 'presenter': presenter}),
        );
      }
    });
    return LobbyAnnouncer._(channel);
  }

  final RealtimeChannel _channel;
  bool _disposed = false;

  /// Stop announcing. Idempotent — safe to call from both `_leave` and
  /// `dispose` (untrack + unsubscribe are best-effort).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _channel.untrack();
    } on Object catch (_) {
      // Best-effort; unsubscribe below removes us from presence regardless.
    }
    await _channel.unsubscribe();
  }
}

/// Watcher side — streams the active sessions in the program. Subscribes
/// WITHOUT tracking, so a watcher never shows up as a session itself.
class LobbyWatcher {
  LobbyWatcher._(this._channel);

  factory LobbyWatcher.watch({
    required SupabaseClient client,
    required String spaceId,
  }) {
    final channel = client.channel(lobbyTopicFor(spaceId));
    final watcher = LobbyWatcher._(channel);
    channel.onPresenceSync((_) => watcher._emit()).subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) watcher._emit();
    });
    return watcher;
  }

  final RealtimeChannel _channel;
  final _ads = StreamController<List<LiveSessionAd>>.broadcast();

  /// The active sessions, re-emitted on every presence change. Seeds nothing
  /// until the first sync (the caller treats "no value yet" as "none live").
  Stream<List<LiveSessionAd>> get ads => _ads.stream;

  // Realtime callbacks can fire after dispose() closes the sink (unsubscribe is
  // async + unawaited) — guard isClosed, exactly like LiveSession.
  void _emit() {
    if (_ads.isClosed) return;
    final seen = <String>{};
    final out = <LiveSessionAd>[];
    for (final state in _channel.presenceState()) {
      for (final presence in state.presences) {
        final p = presence.payload;
        final code = p['code'] as String?;
        final game = p['game'] as String?;
        if (code == null || code.isEmpty || game == null || game.isEmpty) {
          continue;
        }
        // De-dup by code — a presenter can appear more than once across
        // presence refs (reconnects); the room is one session per code.
        if (!seen.add(code)) continue;
        out.add(
          LiveSessionAd(
            code: code,
            game: game,
            presenter: (p['presenter'] as String?) ?? '',
          ),
        );
      }
    }
    _ads.add(out);
  }

  Future<void> dispose() async {
    await _channel.unsubscribe();
    await _ads.close();
  }
}
