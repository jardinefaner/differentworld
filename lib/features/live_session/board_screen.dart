import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/live_session/board_session.dart';
import 'package:differentworld/features/live_session/live_session.dart'
    show LiveStatus;
import 'package:differentworld/features/live_session/live_session_screen.dart'
    show generateSessionCode;
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/board` — the interactive document board (docs/VISION.md #5).
/// An open, living document the room builds together over Realtime.
/// No names — just the content. Each item has a type that shapes what
/// the room can do with it:
///   💡 Idea — anyone can +1 it
///   ❓ Question — mark it answered
///   ✅ Decision — mark it decided
///   🔥 Action — someone can claim it
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

enum _Mode { lobby, present, contribute }

class _BoardScreenState extends ConsumerState<BoardScreen> {
  _Mode _mode = _Mode.lobby;
  BoardSession? _session;
  final _subs = <StreamSubscription<dynamic>>[];
  final _codeCtrl = TextEditingController();
  final _textCtrl = TextEditingController();

  List<BoardItem> _items = const [];
  int _peers = 0;
  LiveStatus _status = LiveStatus.connecting;
  BoardItemKind _selectedKind = BoardItemKind.idea;

  void _open(BoardRole role, String code, _Mode mode) {
    final s = BoardSession.open(
      client: ref.read(supabaseProvider),
      role: role,
      code: code,
    );
    _subs
      ..add(s.itemStream.listen((v) => setState(() => _items = v)))
      ..add(s.peers.listen((v) => setState(() => _peers = v)))
      ..add(s.status.listen((v) => setState(() => _status = v)));
    setState(() {
      _session = s;
      _mode = mode;
    });
  }

  Future<void> _leave() async {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    await _session?.dispose();
    if (!mounted) return;
    setState(() {
      _session = null;
      _mode = _Mode.lobby;
      _items = const [];
      _peers = 0;
      _status = LiveStatus.connecting;
    });
  }

  void _post() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    _session?.add(t, _selectedKind);
    _textCtrl.clear();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_session?.dispose());
    _codeCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: const Color(0xFF0E1117),
        child: SafeArea(
          child: switch (_mode) {
            _Mode.lobby => _lobby(context),
            _Mode.present => _documentView(context, big: true),
            _Mode.contribute => _documentView(context, big: false),
          },
        ),
      ),
    );
  }

  // ── Lobby ────────────────────────────────────────────────────────────────
  Widget _lobby(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '📄',
                style: TextStyle(fontSize: 48),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Brainstorm Board',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'A living document the room builds together.\nEveryone adds — no names, just ideas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 8),
              // Item type legend
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final k in BoardItemKind.values)
                    Chip(
                      avatar: Text(
                        k.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      label: Text(k.label),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      labelStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _LobbyCard(
                icon: Icons.laptop_mac,
                title: 'Start the document',
                subtitle: 'The big screen shows the full doc + a join code.',
                accent: Colors.cyanAccent,
                onTap: () => _open(
                  BoardRole.present,
                  generateSessionCode(),
                  _Mode.present,
                ),
              ),
              const SizedBox(height: 14),
              _JoinCard(
                controller: _codeCtrl,
                onJoin: (code) =>
                    _open(BoardRole.contribute, code, _Mode.contribute),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Document view (both present + contribute; big = presenter, small = phone)
  Widget _documentView(BuildContext context, {required bool big}) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
          child: Row(
            children: [
              if (!big) ...[
                _StatusDot(status: _status),
                const SizedBox(width: 8),
              ],
              if (big) ...[
                const Text(
                  'CODE  ',
                  style: TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _session?.code ?? '',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 12),
                _StatusDot(status: _status),
              ],
              const Spacer(),
              if (big) ...[
                const Icon(
                  Icons.people_alt_outlined,
                  color: Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_peers',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(width: 4),
              ],
              TextButton(
                onPressed: _leave,
                child: Text(
                  big ? 'End' : 'Leave',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),

        // Document body
        Expanded(
          child: _items.isEmpty
              ? _emptyDoc(context, big: big)
              : _DocumentBody(
                  items: _items,
                  big: big,
                  session: _session,
                ),
        ),

        // Contributor post bar
        if (!big)
          _PostBar(
            textCtrl: _textCtrl,
            selectedKind: _selectedKind,
            onKindChanged: (k) => setState(() => _selectedKind = k),
            onPost: _post,
          ),
      ],
    );
  }

  Widget _emptyDoc(BuildContext context, {required bool big}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              big ? '📄' : '✍️',
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 12),
            Text(
              big ? 'Waiting for the room…' : 'Add the first item',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No names — just ideas.',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The living document ────────────────────────────────────────────────────
class _DocumentBody extends StatelessWidget {
  const _DocumentBody({
    required this.items,
    required this.big,
    required this.session,
  });

  final List<BoardItem> items;
  final bool big;
  final BoardSession? session;

  @override
  Widget build(BuildContext context) {
    // Group by kind for the document-section feel.
    final byKind = <BoardItemKind, List<BoardItem>>{};
    for (final item in items) {
      (byKind[item.kind] ??= []).add(item);
    }
    // Section order matches the meeting flow.
    final sectionOrder = [
      BoardItemKind.idea,
      BoardItemKind.question,
      BoardItemKind.decision,
      BoardItemKind.action,
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(big ? 24 : 16, 8, big ? 24 : 16, 24),
      children: [
        for (final kind in sectionOrder)
          if (byKind.containsKey(kind))
            _Section(
              kind: kind,
              items: byKind[kind]!,
              big: big,
              session: session,
            ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.kind,
    required this.items,
    required this.big,
    required this.session,
  });

  final BoardItemKind kind;
  final List<BoardItem> items;
  final bool big;
  final BoardSession? session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Row(
            children: [
              Text(kind.emoji, style: TextStyle(fontSize: big ? 20 : 16)),
              const SizedBox(width: 8),
              Text(
                '${kind.label}s'.toUpperCase(),
                style: TextStyle(
                  color: Colors.white38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: big ? 13 : 11,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        for (final item in items)
          _ItemCard(item: item, big: big, session: session),
      ],
    );
  }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    required this.item,
    required this.big,
    required this.session,
  });

  final BoardItem item;
  final bool big;
  final BoardSession? session;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _claiming = false;
  final _claimCtrl = TextEditingController();

  @override
  void dispose() {
    _claimCtrl.dispose();
    super.dispose();
  }

  Color _kindColor(BoardItemKind k) => switch (k) {
    BoardItemKind.idea => const Color(0xFF2979FF),
    BoardItemKind.question => const Color(0xFFF57C00),
    BoardItemKind.decision => const Color(0xFF2E7D32),
    BoardItemKind.action => const Color(0xFFB71C1C),
  };

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final big = widget.big;
    final dimmed = item.resolved;
    final accent = _kindColor(item.kind);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: dimmed ? 0.03 : 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: accent.withValues(alpha: dimmed ? 0.3 : 0.7),
              width: 3,
            ),
          ),
        ),
        padding: EdgeInsets.all(big ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text
            Text(
              item.text,
              style: TextStyle(
                color: dimmed ? Colors.white38 : Colors.white,
                fontSize: big ? 18 : 15,
                fontWeight: FontWeight.w600,
                decoration: dimmed ? TextDecoration.lineThrough : null,
              ),
            ),

            // Actions row
            const SizedBox(height: 8),
            Row(
              children: [
                // Upvote (ideas only)
                if (item.kind == BoardItemKind.idea) ...[
                  _ActionChip(
                    label: item.upvotes > 0 ? '+${item.upvotes}' : '+1',
                    icon: Icons.add,
                    onTap: () => widget.session?.upvote(item.id),
                  ),
                  const SizedBox(width: 8),
                ],

                // Resolve toggle (questions + decisions)
                if (item.kind == BoardItemKind.question ||
                    item.kind == BoardItemKind.decision) ...[
                  _ActionChip(
                    label: item.resolved
                        ? (item.kind == BoardItemKind.question
                              ? 'Answered'
                              : 'Decided')
                        : (item.kind == BoardItemKind.question
                              ? 'Mark answered'
                              : 'Mark decided'),
                    icon: item.resolved
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    active: item.resolved,
                    onTap: () => widget.session?.toggleResolved(item.id),
                  ),
                  const SizedBox(width: 8),
                ],

                // Claim (actions)
                if (item.kind == BoardItemKind.action) ...[
                  if (item.claimer != null)
                    _ActionChip(
                      label: item.claimer!,
                      icon: Icons.person_outline,
                      active: true,
                      onTap: () {},
                    )
                  else
                    _ActionChip(
                      label: 'Take it',
                      icon: Icons.back_hand_outlined,
                      onTap: () => setState(() => _claiming = true),
                    ),
                  const SizedBox(width: 8),
                ],
              ],
            ),

            // Claim name input (appears on "Take it")
            if (_claiming && item.kind == BoardItemKind.action) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _claimCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Your name (optional)',
                        hintStyle: TextStyle(color: Colors.white38),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (v) {
                        widget.session?.claim(item.id, v);
                        setState(() => _claiming = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      widget.session?.claim(item.id, _claimCtrl.text);
                      setState(() => _claiming = false);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(60, 36),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.white38 : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? Colors.white : Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Post bar (contributor only) ───────────────────────────────────────────
class _PostBar extends StatelessWidget {
  const _PostBar({
    required this.textCtrl,
    required this.selectedKind,
    required this.onKindChanged,
    required this.onPost,
  });

  final TextEditingController textCtrl;
  final BoardItemKind selectedKind;
  final ValueChanged<BoardItemKind> onKindChanged;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kind selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final k in BoardItemKind.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Text(
                        k.emoji,
                        style: const TextStyle(fontSize: 13),
                      ),
                      label: Text(k.label),
                      selected: selectedKind == k,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => onKindChanged(k),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onPost(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText:
                        'Add ${selectedKind.article} ${selectedKind.label.toLowerCase()}…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onPost,
                style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Lobby widgets ─────────────────────────────────────────────────────────
class _LobbyCard extends StatelessWidget {
  const _LobbyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.controller, required this.onJoin});

  final TextEditingController controller;
  final ValueChanged<String> onJoin;

  void _submit() {
    final code = controller.text.trim().toUpperCase();
    if (code.length >= 3) onJoin(code);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join to contribute',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'CODE',
                    hintStyle: TextStyle(
                      color: Colors.white24,
                      letterSpacing: 6,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(80, 54)),
                child: const Text('Join'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final LiveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LiveStatus.live => ('Live', Colors.greenAccent),
      LiveStatus.connecting => ('Connecting…', Colors.amberAccent),
      LiveStatus.error => ('Offline', Colors.redAccent),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

extension _KindArticle on BoardItemKind {
  String get article => switch (this) {
    BoardItemKind.idea => 'an',
    BoardItemKind.question => 'a',
    BoardItemKind.decision => 'a',
    BoardItemKind.action => 'an',
  };
}
