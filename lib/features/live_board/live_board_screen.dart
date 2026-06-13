import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/live_board/board_game.dart';
import 'package:differentworld/features/live_session/cast_session.dart';
import 'package:differentworld/features/live_session/live_game_screen.dart'
    show generateSessionCode;
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// `/live-board` — **the Live Board** (docs/LIVE_BOARD.md): the phone as a
/// classroom instrument. The teacher picks an instrument and drives it; every
/// room screen that joined the cast code updates live. A preview shows exactly
/// what the room sees.
///
/// This is the CASTER. Room screens are the EXISTING cast receiver — they join
/// via Cast → Be the screen → enter this code; because [BoardGame] is registered
/// in the game registry, the receiver renders it with no receiver changes.
class LiveBoardScreen extends ConsumerStatefulWidget {
  const LiveBoardScreen({super.key});

  @override
  ConsumerState<LiveBoardScreen> createState() => _LiveBoardScreenState();
}

class _LiveBoardScreenState extends ConsumerState<LiveBoardScreen> {
  late final String _code = generateSessionCode();
  CastSession? _session;
  final _subs = <StreamSubscription<dynamic>>[];
  int _peers = 0;

  BoardInstrument _active = BoardInstrument.word;
  final _wordCtrl = TextEditingController();
  final _spellWordCtrl = TextEditingController();
  String _spellName = '';

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable()); // don't sleep mid-class
    final session = CastSession.cast(
      client: ref.read(supabaseProvider),
      code: _code,
    );
    _subs.add(
      session.peers.listen((v) {
        if (mounted) setState(() => _peers = v);
      }),
    );
    _session = session;
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_session?.dispose());
    _wordCtrl.dispose();
    _spellWordCtrl.dispose();
    super.dispose();
  }

  BoardState get _state => switch (_active) {
        BoardInstrument.word =>
          BoardState(instrument: BoardInstrument.word, word: _wordCtrl.text),
        BoardInstrument.spell => BoardState(
            instrument: BoardInstrument.spell,
            word: _spellWordCtrl.text,
            name: _spellName,
          ),
        BoardInstrument.idle => const BoardState(),
      };

  /// Push the current instrument's state to every screen, and refresh the
  /// on-phone preview.
  void _push() {
    _session?.castStage(BoardGame.gameId, _state.toMap());
    setState(() {});
  }

  void _setInstrument(BoardInstrument i) {
    setState(() => _active = i);
    _push();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EdgeScaffold(
      backFallbackRoute: '/present',
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const ContentHeader(
              title: 'Live Board',
              subtitle: 'One phone, every screen — pick an instrument',
            ),
            _JoinCard(code: _code, peers: _peers),
            const SizedBox(height: 16),
            // What the room sees — the same stage the receiver renders.
            Text('What the room sees', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: const BoardGame().vibe.surface,
                  child: const BoardGame().buildStage(context, _state),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<BoardInstrument>(
              segments: const [
                ButtonSegment(
                  value: BoardInstrument.word,
                  label: Text('Big word'),
                  icon: Icon(Icons.text_fields),
                ),
                ButtonSegment(
                  value: BoardInstrument.spell,
                  label: Text('Spell for me'),
                  icon: Icon(Icons.spellcheck),
                ),
              ],
              selected: {_active},
              onSelectionChanged: (s) => _setInstrument(s.first),
            ),
            const SizedBox(height: 16),
            if (_active == BoardInstrument.word)
              _WordControls(controller: _wordCtrl, onChanged: (_) => _push())
            else
              _SpellControls(
                wordController: _spellWordCtrl,
                selectedName: _spellName,
                onPickName: (n) {
                  setState(() => _spellName = n);
                  _push();
                },
                onWordChanged: (_) => _push(),
              ),
          ],
        ),
      ),
    );
  }
}

/// The join code + live screen count, so the teacher can point the room's
/// screens at this board.
class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.code, required this.peers});

  final String code;
  final int peers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join code', style: theme.textTheme.labelSmall),
              Text(
                code,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              peers == 0
                  ? 'On each room screen: Cast → Be the screen → enter this code.'
                  : '$peers screen${peers == 1 ? '' : 's'} connected.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: peers == 0
                    ? scheme.onSurfaceVariant
                    : scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordControls extends StatelessWidget {
  const _WordControls({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      decoration: const InputDecoration(
        labelText: 'Word',
        hintText: 'Type a word — it shows big on every screen',
      ),
    );
  }
}

class _SpellControls extends ConsumerWidget {
  const _SpellControls({
    required this.wordController,
    required this.selectedName,
    required this.onPickName,
    required this.onWordChanged,
  });

  final TextEditingController wordController;
  final String selectedName;
  final ValueChanged<String> onPickName;
  final ValueChanged<String> onWordChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subjects = ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Who asked?', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        if (subjects.isEmpty)
          // No roster — let the teacher type the name.
          TextField(
            onChanged: onPickName,
            decoration: const InputDecoration(labelText: 'Name'),
          )
        else
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final s = subjects[i];
                final name = s.firstName;
                final selected = name == selectedName;
                return GestureDetector(
                  onTap: () => onPickName(name),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: PersonAvatar(name: name, radius: 26),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 64,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: wordController,
          onChanged: onWordChanged,
          autofocus: true,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Spell it',
            hintText: 'Type the word; the room sees the avatar + the word',
          ),
        ),
      ],
    );
  }
}
