import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';

/// **The Live Board** (docs/LIVE_BOARD.md) — the phone as a classroom
/// instrument. A cast-only [GameDefinition] (like `WorldCastGame`): registered
/// so the existing Cast receiver renders it for free, driven from the phone via
/// `CastSession.castStage` with an explicit, self-describing wire-state. The
/// reducer is a no-op — every edit re-casts the whole state, so there are no
/// per-keystroke intents to design.
///
/// The render law is **auto-fit**: every instrument scales its content to fill
/// the screen and never scrolls or clips (`FittedBox`). "All must fit."
enum BoardInstrument { idle, word, spell }

class BoardState {
  const BoardState({
    this.instrument = BoardInstrument.idle,
    this.word = '',
    this.name = '',
  });

  factory BoardState.fromMap(Map<String, dynamic> m) => BoardState(
        instrument: switch (m['kind'] as String?) {
          'word' => BoardInstrument.word,
          'spell' => BoardInstrument.spell,
          _ => BoardInstrument.idle,
        },
        word: (m['word'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
      );

  final BoardInstrument instrument;
  final String word;
  final String name;

  /// The wire-state the caster broadcasts. Self-describing — the receiver
  /// needs no roster/catalog access.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'kind': instrument.name,
        'word': word,
        'name': name,
      };
}

class BoardGame extends GameDefinition<BoardState> {
  const BoardGame();

  static const String gameId = 'board';

  @override
  String get id => gameId;

  @override
  String get title => 'Live Board';

  @override
  GameVibe get vibe =>
      const GameVibe(accent: Color(0xFF2A9D8F), surface: Color(0xFF0B0F0E));

  // Cast-only — seeded explicitly via castStage, never from the content bank,
  // so it stays out of the standard game launcher.
  @override
  bool get seedsFromContentBank => false;

  @override
  Map<String, dynamic> initialState(ContentSource content) =>
      const BoardState().toMap();

  @override
  BoardState decode(Map<String, dynamic> state) => BoardState.fromMap(state);

  // No reducer intents — the caster re-casts the full state on every edit.
  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) =>
      state;

  @override
  Set<GameIntent> activeIntents(BoardState state) => const {};

  @override
  Widget buildStage(BuildContext context, BoardState state) {
    return switch (state.instrument) {
      BoardInstrument.word => _WordStage(word: state.word),
      BoardInstrument.spell => _SpellStage(name: state.name, word: state.word),
      BoardInstrument.idle => const _IdleStage(),
    };
  }
}

/// One big word, scaled to fill (auto-fit). The room's whole screen is the word.
class _WordStage extends StatelessWidget {
  const _WordStage({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    if (word.trim().isEmpty) return const _IdleStage();
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: FittedBox(
          child: Text(
            word,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }
}

/// Spell-for-me: the kid's avatar (initials) + the word, side by side and big.
/// Row on a wide screen, stacked on a tall one; both pieces auto-fit.
class _SpellStage extends StatelessWidget {
  const _SpellStage({required this.name, required this.word});

  final String name;
  final String word;

  @override
  Widget build(BuildContext context) {
    if (word.trim().isEmpty && name.trim().isEmpty) return const _IdleStage();
    return Padding(
      padding: const EdgeInsets.all(36),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= c.maxHeight;
          final avatarRadius = (wide ? c.maxHeight : c.maxWidth) * 0.22;
          final avatar = PersonAvatar(
            name: name.trim().isEmpty ? '?' : name,
            radius: avatarRadius.clamp(40, 160),
          );
          final wordBox = FittedBox(
            child: Text(
              word,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          );
          if (wide) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 32),
                Flexible(child: Center(child: wordBox)),
              ],
            );
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(height: 28),
              Flexible(child: Center(child: wordBox)),
            ],
          );
        },
      ),
    );
  }
}

/// Nothing on the board yet — a calm prompt (also the receiver's first paint
/// before the teacher picks an instrument).
class _IdleStage extends StatelessWidget {
  const _IdleStage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, color: Colors.white24, size: 56),
            SizedBox(height: 16),
            Text(
              'Pick an instrument on the phone',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
