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
enum BoardInstrument { idle, word, spell, number, turn, reveal, sound }

class BoardState {
  const BoardState({
    this.instrument = BoardInstrument.idle,
    this.word = '',
    this.name = '',
    this.number = 0,
  });

  factory BoardState.fromMap(Map<String, dynamic> m) => BoardState(
    instrument: switch (m['kind'] as String?) {
      'word' => BoardInstrument.word,
      'spell' => BoardInstrument.spell,
      'number' => BoardInstrument.number,
      'turn' => BoardInstrument.turn,
      'reveal' => BoardInstrument.reveal,
      'sound' => BoardInstrument.sound,
      _ => BoardInstrument.idle,
    },
    word: (m['word'] as String?) ?? '',
    name: (m['name'] as String?) ?? '',
    number: (m['number'] as num?)?.toInt() ?? 0,
  );

  final BoardInstrument instrument;

  /// The big text for `word`; the LABEL under the number for `number`; the
  /// newline-joined lines for `reveal`.
  final String word;

  /// The kid's name for `spell` / `turn`.
  final String name;

  /// The count for `number`; the count of revealed lines for `reveal`.
  final int number;

  /// The wire-state the caster broadcasts. Self-describing — the receiver
  /// needs no roster/catalog access.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'kind': instrument.name,
    'word': word,
    'name': name,
    'number': number,
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
  GameVibe get vibe => const GameVibe(accent: GameAccents.deepTeal);

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
  ) => state;

  @override
  Set<GameIntent> activeIntents(BoardState state) => const {};

  @override
  Widget buildStage(BuildContext context, BoardState state) {
    return switch (state.instrument) {
      BoardInstrument.word => _WordStage(word: state.word),
      BoardInstrument.spell => _SpellStage(name: state.name, word: state.word),
      BoardInstrument.number => _NumberStage(
        number: state.number,
        label: state.word,
      ),
      BoardInstrument.turn => _TurnStage(name: state.name),
      BoardInstrument.reveal => _RevealStage(
        text: state.word,
        shown: state.number,
      ),
      BoardInstrument.sound => _SoundStage(text: state.word, lit: state.number),
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

/// Count together: one big number, with an optional label under it. Tap the
/// number up on the phone and the whole room counts along.
class _NumberStage extends StatelessWidget {
  const _NumberStage({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
          if (label.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            FittedBox(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Whose turn: a kid's avatar (initials) big with their name + "'s turn". Fair
/// turns the whole room can see.
class _TurnStage extends StatelessWidget {
  const _TurnStage({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    if (name.trim().isEmpty) return const _IdleStage();
    return Padding(
      padding: const EdgeInsets.all(36),
      child: LayoutBuilder(
        builder: (context, c) {
          final r = (c.maxHeight * 0.32).clamp(48.0, 200.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PersonAvatar(name: name, radius: r),
              const SizedBox(height: 24),
              Flexible(
                child: FittedBox(
                  child: Text(
                    "$name's turn",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reveal one at a time: the lines build up on the room screen as the teacher
/// taps "reveal next" — a sentence, a poem, a list, a step sequence.
class _RevealStage extends StatelessWidget {
  const _RevealStage({required this.text, required this.shown});

  final String text;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const _IdleStage();
    final revealed = lines.take(shown.clamp(0, lines.length)).toList();
    if (revealed.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'Ready…',
            style: TextStyle(color: Colors.white38, fontSize: 28),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: FittedBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < revealed.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    revealed[i],
                    style: TextStyle(
                      // The freshest line is brightest; earlier ones settle.
                      color: i == revealed.length - 1
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Split a sound-it-out word into its chunks. The teacher separates sounds
/// with a hyphen, middot, slash, or space (e.g. "but-ter-fly").
List<String> soundChunks(String text) => text
    .split(RegExp(r'[-·/\s]+'))
    .map((c) => c.trim())
    .where((c) => c.isNotEmpty)
    .toList();

/// Sound it out: a word broken into chunks; tap to light each one in turn,
/// then blend. The lit chunks glow; the rest wait dim. Phonics, room-sized.
class _SoundStage extends StatelessWidget {
  const _SoundStage({required this.text, required this.lit});

  final String text;
  final int lit;

  @override
  Widget build(BuildContext context) {
    final chunks = soundChunks(text);
    if (chunks.isEmpty) return const _IdleStage();
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: FittedBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < chunks.length; i++) ...[
                if (i > 0)
                  const Text(
                    '·',
                    style: TextStyle(color: Colors.white24, fontSize: 56),
                  ),
                Text(
                  chunks[i],
                  style: TextStyle(
                    color: i < lit ? Colors.white : Colors.white24,
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
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
