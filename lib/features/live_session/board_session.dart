import 'dart:async';

import 'package:differentworld/features/live_session/live_session.dart'
    show LiveStatus;
import 'package:supabase_flutter/supabase_flutter.dart';

/// The interactive document board (docs/VISION.md #5): phones contribute
/// typed items to a shared living document over Realtime — no names attached.
/// The presenter sees the growing doc; contributors see a post field + the
/// doc in compact view.
///
/// Anonymity by construction: every broadcast payload carries only the item
/// content, never a sender identity. `self: true` so a poster sees their
/// own item land immediately.
enum BoardRole { present, contribute }

/// The type of a board item — shapes what the room can do with it.
enum BoardItemKind {
  idea('💡', 'Idea'),
  question('❓', 'Question'),
  decision('✅', 'Decision'),
  action('🔥', 'Action')
  ;

  const BoardItemKind(this.emoji, this.label);
  final String emoji;
  final String label;

  static BoardItemKind fromKey(String key) =>
      values.firstWhere((k) => k.name == key, orElse: () => BoardItemKind.idea);
}

/// One item on the board.
class BoardItem {
  BoardItem({
    required this.id,
    required this.kind,
    required this.text,
    this.upvotes = 0,
    this.resolved = false,
    this.claimer,
  });

  factory BoardItem.fromMap(Map<String, dynamic> m) => BoardItem(
    id: m['id'] as String? ?? '',
    kind: BoardItemKind.fromKey(m['kind'] as String? ?? 'idea'),
    text: m['text'] as String? ?? '',
    upvotes: (m['v'] as num?)?.toInt() ?? 0,
    resolved: m['r'] == true,
    claimer: m['c'] as String?,
  );

  final String id;
  final BoardItemKind kind;
  final String text;
  int upvotes;
  bool resolved;
  String? claimer;

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind.name,
    'text': text,
    'v': upvotes,
    'r': resolved,
    if (claimer != null) 'c': claimer,
  };
}

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

  // Items keyed by id for O(1) mutation.
  final Map<String, BoardItem> _items = {};
  // Ordered list (insertion order, newest at bottom for document feel).
  final List<String> _order = [];

  List<BoardItem> get items => _order.map((id) => _items[id]!).toList();

  final _items$ = StreamController<List<BoardItem>>.broadcast();
  Stream<List<BoardItem>> get itemStream => _items$.stream;

  final _peers = StreamController<int>.broadcast();
  Stream<int> get peers => _peers.stream;

  final _status = StreamController<LiveStatus>.broadcast();
  Stream<LiveStatus> get status => _status.stream;

  static String topicFor(String code) => 'dw-board-${code.toUpperCase()}';

  void _wire() {
    _channel
        .onBroadcast(
          event: 'add',
          callback: (payload) {
            final item = _itemFromPayload(payload);
            if (item != null && !_items.containsKey(item.id)) {
              _items[item.id] = item;
              _order.add(item.id);
              _emit();
            }
          },
        )
        .onBroadcast(
          event: 'update',
          callback: (payload) {
            final id = payload['id'] as String?;
            if (id == null || !_items.containsKey(id)) return;
            final item = _items[id]!;
            if (payload['v'] != null) {
              item.upvotes = (payload['v'] as num).toInt();
            }
            if (payload['r'] != null) item.resolved = payload['r'] as bool;
            if (payload.containsKey('c')) {
              item.claimer = payload['c'] as String?;
            }
            _emit();
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

  void _emit() {
    if (!_items$.isClosed) _items$.add(items);
  }

  BoardItem? _itemFromPayload(Map<String, dynamic> payload) {
    try {
      return BoardItem.fromMap(payload);
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> _send(String event, Map<String, dynamic> payload) async {
    try {
      await _channel.sendBroadcastMessage(event: event, payload: payload);
    } on Object catch (_) {
      // Best-effort; ephemeral coordination.
    }
  }

  /// Post a new item to the board (anonymous — no sender id on the wire).
  void add(String text, BoardItemKind kind) {
    final t = text.trim();
    if (t.isEmpty) return;
    final item = BoardItem(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      kind: kind,
      text: t,
    );
    unawaited(_send('add', item.toMap()));
  }

  /// +1 an idea (count only, no identity).
  void upvote(String id) {
    final item = _items[id];
    if (item == null) return;
    unawaited(_send('update', {'id': id, 'v': item.upvotes + 1}));
  }

  /// Toggle resolved on a question or decision.
  void toggleResolved(String id) {
    final item = _items[id];
    if (item == null) return;
    unawaited(_send('update', {'id': id, 'r': !item.resolved}));
  }

  /// Claim an action (voluntarily typed name — still optional and manual).
  void claim(String id, String name) {
    final n = name.trim();
    unawaited(_send('update', {'id': id, 'c': n.isEmpty ? null : n}));
  }

  Future<void> dispose() async {
    await _channel.unsubscribe();
    await _items$.close();
    await _peers.close();
    await _status.close();
  }
}
