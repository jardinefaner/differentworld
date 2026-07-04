import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:flutter/material.dart';

/// Reveal the Picture (docs/GAMES.md) — a hidden picture behind a lettered ×
/// numbered grid. The room calls a cell ("A1", "C3"); the host taps it; that
/// tile lifts and the picture uncovers itself piece by piece until someone
/// guesses it. The host-drives model: kids call out, the teacher taps.
///
/// **Slice 1 — the bundled set:** the picture is a big emoji from a curated
/// catalog (animals / vehicles / food / nature). Zero assets, and it casts
/// perfectly — the glyph is a tiny string on the Realtime wire, so the Receiver
/// renders the same picture with no binary transfer. Slice 2 adds pick-your-own
/// photos (uploaded to Storage so the screen can fetch them by URL).
///
/// Wire-state: `{cols, rows, pic, lbl, rev: [bool×n], d}`. `rev` is the per-cell
/// revealed flags (self-describing, so the Receiver renders from the broadcast).
class GridRevealState {
  const GridRevealState({
    required this.cols,
    required this.rows,
    required this.emoji,
    required this.answer,
    required this.photo,
    required this.revealed,
    required this.done,
  });

  factory GridRevealState.fromMap(Map<String, dynamic> m) => GridRevealState(
    cols: (m['cols'] as num?)?.toInt() ?? 4,
    rows: (m['rows'] as num?)?.toInt() ?? 4,
    emoji: m['pic'] as String? ?? '',
    answer: m['lbl'] as String? ?? '',
    photo: m['photo'] == true,
    revealed: [
      for (final v in (m['rev'] as List? ?? const <dynamic>[])) v == true,
    ],
    done: m['d'] == true,
  );

  final int cols;
  final int rows;

  /// The picture: an emoji glyph, OR (when [photo]) a `person-photos` bucket
  /// path to a staff-uploaded picture.
  final String emoji;
  final String answer;

  /// True when [emoji] is a Storage path to a custom photo (rendered as a
  /// signed-URL image), false when it's an emoji glyph.
  final bool photo;
  final List<bool> revealed; // length cols*rows, row-major
  final bool done;

  int get cellCount => cols * rows;
  bool isRevealed(int i) => i >= 0 && i < revealed.length && revealed[i];
  bool get anyRevealed => revealed.any((v) => v);
  bool get allRevealed => revealed.isNotEmpty && revealed.every((v) => v);

  /// "A1" … cells are lettered across (columns) + numbered down (rows).
  static String label(int row, int col) =>
      '${String.fromCharCode(65 + col)}${row + 1}';
}

/// A curated, kid-legible picture set — common, guessable, render-everywhere
/// glyphs. (Slice 2 will let staff bring their own photo.)
const List<(String, String)> _pictures = <(String, String)>[
  ('🦁', 'Lion'),
  ('🐘', 'Elephant'),
  ('🦒', 'Giraffe'),
  ('🐢', 'Turtle'),
  ('🦋', 'Butterfly'),
  ('🐙', 'Octopus'),
  ('🐝', 'Bee'),
  ('🐧', 'Penguin'),
  ('🦖', 'Dinosaur'),
  ('🐬', 'Dolphin'),
  ('🦉', 'Owl'),
  ('🐸', 'Frog'),
  ('🚀', 'Rocket'),
  ('🚂', 'Train'),
  ('⛵', 'Sailboat'),
  ('🚒', 'Fire truck'),
  ('🌈', 'Rainbow'),
  ('⭐', 'Star'),
  ('🌻', 'Sunflower'),
  ('🌳', 'Tree'),
  ('🍕', 'Pizza'),
  ('🍎', 'Apple'),
  ('🍦', 'Ice cream'),
  ('🎂', 'Cake'),
  ('🏰', 'Castle'),
  ('🎈', 'Balloon'),
  ('☂️', 'Umbrella'),
  ('🎸', 'Guitar'),
];

class GridRevealGame extends GameDefinition<GridRevealState> {
  const GridRevealGame();

  // 4×4 grid (A–D × 1–4) — a satisfying 16 reveals. A difficulty setting
  // (bigger grids) is a clean follow-up via the Settings contract.
  static const int _cols = 4;
  static const int _rows = 4;

  @override
  String get id => 'grid-reveal';

  @override
  String get title => 'Reveal the Picture';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.deepTeal);

  @override
  String? get liveRoute => '/live/grid-reveal';

  // Customizable grid — A–H × 1–8 like a chessboard, or any size in between.
  // The settings sheet (single-device) collects these; the live/cast default
  // path uses [initialState] (the default size) until the cockpit grows a
  // pre-cast config step (a follow-up).
  @override
  List<GameSetting> get settings => const [
    IntSetting(
      id: 'cols',
      label: 'Columns (A, B, C…)',
      min: 2,
      max: 8,
      initial: _cols,
    ),
    IntSetting(
      id: 'rows',
      label: 'Rows (1, 2, 3…)',
      min: 2,
      max: 8,
      initial: _rows,
    ),
  ];

  @override
  Map<String, dynamic> initialState(ContentSource content) =>
      _build(_cols, _rows, content, mixEmoji: true);

  @override
  Map<String, dynamic> initialStateFor(
    ContentSource content,
    Map<String, Object?> values,
  ) => _build(
    values.intSetting('cols', _cols),
    values.intSetting('rows', _rows),
    content,
    // Threaded from the library "Mix with the built-in emoji" toggle via
    // the runner's initialValues (see GridRevealScreen).
    mixEmoji: values['mixEmoji'] as bool? ?? true,
  );

  /// Pick a picture for the round from a pool of the built-in emoji plus the
  /// space's own uploaded photos (kind `picture`, from the content bank). When
  /// [mixEmoji] is false and the space HAS custom photos, only those play;
  /// otherwise the emoji are always included so the game never runs dry. "Play
  /// again" re-runs this (a fresh pick).
  static Map<String, dynamic> _build(
    int cols,
    int rows,
    ContentSource content, {
    required bool mixEmoji,
  }) {
    // Custom photos: staff-uploaded, with a real (non-pending) Storage path.
    final customs = content.take(ContentKind.picture, 64).where((c) {
      final img = c.payload['image'] as String?;
      return img != null && img.isNotEmpty && !img.startsWith('pending:');
    }).toList();

    // Pool entries: (picString, label, isPhoto).
    final pool = <(String, String, bool)>[
      if (mixEmoji || customs.isEmpty)
        for (final e in _pictures) (e.$1, e.$2, false),
      for (final c in customs)
        (
          c.payload['image']! as String,
          (c.payload['label'] as String?) ?? '',
          true,
        ),
    ];
    final pick = pool[Random().nextInt(pool.length)];
    final n = cols * rows;
    return <String, dynamic>{
      'cols': cols,
      'rows': rows,
      'pic': pick.$1,
      'lbl': pick.$2,
      'photo': pick.$3,
      'rev': List<bool>.filled(n, false),
      'd': false,
      'n': n,
    };
  }

  @override
  GridRevealState decode(Map<String, dynamic> state) =>
      GridRevealState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final rev = [
      for (final v in (s['rev'] as List? ?? const <dynamic>[])) v == true,
    ];
    switch (intent) {
      case GameIntent.pick:
        final cell = (args['cell'] as num?)?.toInt();
        if (cell != null && cell >= 0 && cell < rev.length && !rev[cell]) {
          rev[cell] = true;
          s['rev'] = rev;
          if (rev.every((v) => v)) s['d'] = true;
        }
      case GameIntent.reveal:
        // The big reveal — show the whole picture (+ the answer).
        s['rev'] = List<bool>.filled(rev.length, true);
        s['d'] = true;
      case GameIntent.back:
        // Undo the most-recently revealed cell (a mis-tap).
        final last = rev.lastIndexWhere((v) => v);
        if (last >= 0) {
          rev[last] = false;
          s['rev'] = rev;
          s['d'] = false;
        }
      case GameIntent.reset:
        // Hide everything again (a fresh picture comes from re-running
        // initialState on the live/single-device "play again" path).
        s['rev'] = List<bool>.filled(rev.length, false);
        s['d'] = false;
      case GameIntent.next:
      case GameIntent.tally:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(GridRevealState s) => <GameIntent>{
    if (!s.allRevealed) GameIntent.reveal,
    if (s.anyRevealed) GameIntent.back,
    GameIntent.reset,
  };

  @override
  Widget buildStage(BuildContext context, GridRevealState state) =>
      _GridRevealStage(state: state, accent: vibe.accent);

  // The control region IS the tappable grid (the host taps the called cell) +
  // Reveal all / New — so it overrides the standard bar.
  @override
  Widget? buildControls(
    BuildContext context,
    GridRevealState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) => _GridRevealControls(state: state, accent: vibe.accent, send: send);
}

/// The big screen: the picture filling a centered grid-shaped box, with opaque
/// labelled tiles on top; revealed tiles lift to show the picture through.
class _GridRevealStage extends StatelessWidget {
  const _GridRevealStage({required this.state, required this.accent});

  final GridRevealState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: AspectRatio(
              aspectRatio: state.cols / state.rows,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The picture, filling the grid box (cover so each cell
                    // covers a real portion — no empty margins). A staff photo
                    // renders via a signed URL; an emoji renders as a big glyph.
                    if (state.photo)
                      PersonPhotoNetwork(
                        urlOrPath: state.emoji,
                        placeholderBuilder: (_) =>
                            const ColoredBox(color: Colors.white),
                      )
                    else
                      ColoredBox(
                        color: Colors.white,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: Text(
                            state.emoji,
                            style: const TextStyle(fontSize: 240),
                          ),
                        ),
                      ),
                    // The cover grid.
                    Column(
                      children: [
                        for (int r = 0; r < state.rows; r++)
                          Expanded(
                            child: Row(
                              children: [
                                for (int c = 0; c < state.cols; c++)
                                  Expanded(
                                    child: _CoverTile(
                                      revealed: state.isRevealed(
                                        r * state.cols + c,
                                      ),
                                      label: GridRevealState.label(r, c),
                                      accent: accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // The answer reveals only when the whole picture is up.
          AnimatedOpacity(
            opacity: state.done ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Text(
              state.answer,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({
    required this.revealed,
    required this.label,
    required this.accent,
  });

  final bool revealed;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: revealed ? 0 : 1,
      duration: const Duration(milliseconds: 280),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1B26),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The host's control: a tappable cell grid (tap the called cell to reveal it)
/// + Reveal all + New.
class _GridRevealControls extends StatelessWidget {
  const _GridRevealControls({
    required this.state,
    required this.accent,
    required this.send,
  });

  final GridRevealState state;
  final Color accent;
  final void Function(GameIntent intent, [Map<String, dynamic> args]) send;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < state.rows; r++)
          Row(
            children: [
              for (int c = 0; c < state.cols; c++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _CellButton(
                      label: GridRevealState.label(r, c),
                      revealed: state.isRevealed(r * state.cols + c),
                      accent: accent,
                      onTap: () => send(
                        GameIntent.pick,
                        {'cell': r * state.cols + c},
                      ),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => send(GameIntent.reset),
                icon: const Icon(Icons.replay),
                label: const Text('New picture'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: state.allRevealed
                    ? null
                    : () => send(GameIntent.reveal),
                icon: const Icon(Icons.visibility),
                label: const Text('Reveal all'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CellButton extends StatelessWidget {
  const _CellButton({
    required this.label,
    required this.revealed,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool revealed;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: revealed ? accent.withValues(alpha: 0.25) : Colors.white10,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        // Revealed cells are inert (already up) — re-tapping does nothing.
        onTap: revealed ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: revealed
              ? Icon(Icons.check, color: accent, size: 18)
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
