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
import 'package:flutter/services.dart';
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
  // Explicit focus nodes (owned here) so switching instruments reliably
  // re-takes focus + re-shows the IME — `autofocus` only fires on first mount
  // and drops the keyboard on a fast re-switch (Interaction Guard).
  final _wordFocus = FocusNode();
  final _spellFocus = FocusNode();
  String _spellName = '';
  int _number = 0;
  final _numberLabelCtrl = TextEditingController();
  String _turnName = '';
  final _revealCtrl = TextEditingController();
  final _revealFocus = FocusNode();
  int _revealShown = 0;
  final _soundCtrl = TextEditingController();
  final _soundFocus = FocusNode();
  int _soundLit = 0;

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
    // Focus the first instrument's field once the frame is up (IME show is a
    // post-frame op on Android; requestFocus alone doesn't raise it).
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusActive());
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
    _numberLabelCtrl.dispose();
    _revealCtrl.dispose();
    _soundCtrl.dispose();
    _wordFocus.dispose();
    _spellFocus.dispose();
    _revealFocus.dispose();
    _soundFocus.dispose();
    super.dispose();
  }

  /// Take focus on the active instrument's field and raise the IME. Split out
  /// so the instrument switch and first mount share one reliable path
  /// (requestFocus + an explicit post-frame TextInput.show — CLAUDE.md
  /// interaction invariant 4).
  void _focusActive() {
    if (!mounted) return;
    switch (_active) {
      case BoardInstrument.word:
        _wordFocus.requestFocus();
      case BoardInstrument.spell:
        _spellFocus.requestFocus();
      case BoardInstrument.reveal:
        _revealFocus.requestFocus();
      case BoardInstrument.sound:
        _soundFocus.requestFocus();
      case BoardInstrument.number:
      case BoardInstrument.turn:
      case BoardInstrument.idle:
        // No text field on these — drop the keyboard, don't raise the IME.
        FocusManager.instance.primaryFocus?.unfocus();
        return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(SystemChannels.textInput.invokeMethod('TextInput.show'));
      }
    });
  }

  BoardState get _state => switch (_active) {
        BoardInstrument.word =>
          BoardState(instrument: BoardInstrument.word, word: _wordCtrl.text),
        BoardInstrument.spell => BoardState(
            instrument: BoardInstrument.spell,
            word: _spellWordCtrl.text,
            name: _spellName,
          ),
        BoardInstrument.number => BoardState(
            instrument: BoardInstrument.number,
            number: _number,
            word: _numberLabelCtrl.text,
          ),
        BoardInstrument.turn =>
          BoardState(instrument: BoardInstrument.turn, name: _turnName),
        BoardInstrument.reveal => BoardState(
            instrument: BoardInstrument.reveal,
            word: _revealCtrl.text,
            number: _revealShown,
          ),
        BoardInstrument.sound => BoardState(
            instrument: BoardInstrument.sound,
            word: _soundCtrl.text,
            number: _soundLit,
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
    _focusActive();
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
            // The instrument rack — a scrollable chip row so it grows as we
            // add instruments (docs/LIVE_BOARD.md).
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final i in const [
                    (BoardInstrument.word, 'Big word', Icons.text_fields),
                    (BoardInstrument.spell, 'Spell', Icons.spellcheck),
                    (BoardInstrument.number, 'Count', Icons.pin_outlined),
                    (BoardInstrument.turn, 'Whose turn', Icons.groups_outlined),
                    (BoardInstrument.reveal, 'Reveal', Icons.expand_more),
                    (BoardInstrument.sound, 'Sound it out', Icons.graphic_eq),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(i.$3, size: 18),
                        label: Text(i.$2),
                        selected: _active == i.$1,
                        onSelected: (_) => _setInstrument(i.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            switch (_active) {
              BoardInstrument.word => _WordControls(
                  controller: _wordCtrl,
                  focusNode: _wordFocus,
                  onChanged: (_) => _push(),
                ),
              BoardInstrument.spell => _SpellControls(
                  wordController: _spellWordCtrl,
                  wordFocus: _spellFocus,
                  selectedName: _spellName,
                  onPickName: (n) {
                    setState(() => _spellName = n);
                    _push();
                  },
                  onWordChanged: (_) => _push(),
                ),
              BoardInstrument.number => _NumberControls(
                  number: _number,
                  labelController: _numberLabelCtrl,
                  onStep: (delta) {
                    setState(() => _number = (_number + delta).clamp(0, 9999));
                    _push();
                  },
                  onReset: () {
                    setState(() => _number = 0);
                    _push();
                  },
                  onLabelChanged: (_) => _push(),
                ),
              BoardInstrument.turn => _RosterPicker(
                  selectedName: _turnName,
                  onPick: (n) {
                    setState(() => _turnName = n);
                    _push();
                  },
                ),
              BoardInstrument.reveal => _RevealControls(
                  controller: _revealCtrl,
                  focusNode: _revealFocus,
                  shown: _revealShown,
                  total: _revealCtrl.text
                      .split('\n')
                      .where((l) => l.trim().isNotEmpty)
                      .length,
                  onLinesChanged: (_) => _push(),
                  onStep: (delta) {
                    setState(() => _revealShown =
                        (_revealShown + delta).clamp(0, 99));
                    _push();
                  },
                  onReset: () {
                    setState(() => _revealShown = 0);
                    _push();
                  },
                ),
              BoardInstrument.sound => _RevealControls(
                  controller: _soundCtrl,
                  focusNode: _soundFocus,
                  shown: _soundLit,
                  total: soundChunks(_soundCtrl.text).length,
                  label: 'Word',
                  hint: 'Separate the sounds with - (e.g. but-ter-fly)',
                  nextLabel: 'Light next',
                  minLines: 1,
                  onLinesChanged: (_) => _push(),
                  onStep: (delta) {
                    setState(() => _soundLit = (_soundLit + delta).clamp(0, 99));
                    _push();
                  },
                  onReset: () {
                    setState(() => _soundLit = 0);
                    _push();
                  },
                ),
              BoardInstrument.idle => const SizedBox.shrink(),
            },
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
  const _WordControls({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      decoration: const InputDecoration(
        labelText: 'Word',
        hintText: 'Type a word — it shows big on every screen',
      ),
    );
  }
}

class _SpellControls extends StatelessWidget {
  const _SpellControls({
    required this.wordController,
    required this.wordFocus,
    required this.selectedName,
    required this.onPickName,
    required this.onWordChanged,
  });

  final TextEditingController wordController;
  final FocusNode wordFocus;
  final String selectedName;
  final ValueChanged<String> onPickName;
  final ValueChanged<String> onWordChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RosterPicker(selectedName: selectedName, onPick: onPickName),
        const SizedBox(height: 16),
        TextField(
          controller: wordController,
          focusNode: wordFocus,
          onChanged: onWordChanged,
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

/// Count-together controls: a big −/＋ stepper + an optional label. Reset
/// zeroes it. No text field is auto-focused (counting is tap-driven).
class _NumberControls extends StatelessWidget {
  const _NumberControls({
    required this.number,
    required this.labelController,
    required this.onStep,
    required this.onReset,
    required this.onLabelChanged,
  });

  final int number;
  final TextEditingController labelController;
  final ValueChanged<int> onStep;
  final VoidCallback onReset;
  final ValueChanged<String> onLabelChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              iconSize: 36,
              onPressed: number > 0 ? () => onStep(-1) : null,
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Text(
                '$number',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton.filledTonal(
              iconSize: 36,
              onPressed: () => onStep(1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: labelController,
          onChanged: onLabelChanged,
          decoration: const InputDecoration(
            labelText: 'Label (optional)',
            hintText: 'e.g. days together · kids here · books read',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: number == 0 ? null : onReset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}

/// Reveal-one-at-a-time controls: type the lines (one per line), then tap
/// "Reveal next" to build them up on the room screen.
class _RevealControls extends StatelessWidget {
  const _RevealControls({
    required this.controller,
    required this.focusNode,
    required this.shown,
    required this.total,
    required this.onLinesChanged,
    required this.onStep,
    required this.onReset,
    this.label = 'Lines (one per line)',
    this.hint = 'Type each line; reveal them one at a time',
    this.nextLabel = 'Reveal next',
    this.minLines = 2,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int shown;
  final int total;
  final ValueChanged<String> onLinesChanged;
  final ValueChanged<int> onStep;
  final VoidCallback onReset;
  final String label;
  final String hint;
  final String nextLabel;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onLinesChanged,
          minLines: minLines,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: shown > 0 ? () => onStep(-1) : null,
              icon: const Icon(Icons.undo),
              label: const Text('Back'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: shown < total ? () => onStep(1) : null,
                icon: const Icon(Icons.expand_more),
                label: Text(
                  shown >= total && total > 0 ? 'All shown' : nextLabel,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$shown of $total revealed',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: shown == 0 ? null : onReset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}

/// The roster avatar strip — tap a kid to select them. Shared by Spell-for-me
/// and Whose-turn. Falls back to a name field when there's no roster yet.
class _RosterPicker extends ConsumerWidget {
  const _RosterPicker({required this.selectedName, required this.onPick});

  final String selectedName;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    if (subjects.isEmpty) {
      return TextField(
        onChanged: onPick,
        decoration: const InputDecoration(labelText: 'Name'),
      );
    }
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final name = subjects[i].firstName;
          final selected = name == selectedName;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPick(name),
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
    );
  }
}
