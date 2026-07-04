import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// **The Conductor** — cast any text (a song's lyrics, a sentence, the
/// week's words) to the room, then TAP A WORD to spotlight it: that word
/// lights up, the rest dim, and the whole room's eyes land where you point.
/// The teacher conducts the attention. Reuses the cast receiver/cockpit (the
/// stage = the lit text, the controls = the same text but tappable) and the
/// self-describing wire-state pattern (the lines ride in the state). Seeded
/// explicitly via castStage. A = "attention control", D = "sing the song".

/// Split pasted text into lines of words (blank lines dropped).
List<List<String>> parseLyrics(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty)
      [for (final w in line.trim().split(RegExp(r'\s+'))) w],
];

/// The wire-state for casting [text]. `i` = the flat index of the lit word
/// (-1 = nothing lit, the whole text shown evenly).
Map<String, dynamic> conductorSeed(String text, {String title = ''}) => {
  'lines': parseLyrics(text),
  'i': -1,
  'title': title,
};

class ConductorState {
  const ConductorState({
    this.lines = const [],
    this.active = -1,
    this.title = '',
  });

  factory ConductorState.fromMap(Map<String, dynamic> m) => ConductorState(
    lines: [
      for (final line in (m['lines'] as List? ?? const []))
        [for (final w in (line as List? ?? const [])) w.toString()],
    ],
    active: (m['i'] as num?)?.toInt() ?? -1,
    title: (m['title'] as String?) ?? '',
  );

  final List<List<String>> lines;
  final int active;
  final String title;

  int get total {
    var n = 0;
    for (final l in lines) {
      n += l.length;
    }
    return n;
  }
}

class ConductorGame extends GameDefinition<ConductorState> {
  const ConductorGame();

  static const String gameId = 'conductor';

  @override
  String get id => gameId;

  @override
  String get title => 'Conduct';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.slate);

  @override
  bool get seedsFromContentBank => false;

  @override
  Map<String, dynamic> initialState(ContentSource content) => <String, dynamic>{
    'lines': <dynamic>[],
    'i': -1,
    'title': '',
  };

  @override
  ConductorState decode(Map<String, dynamic> state) =>
      ConductorState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final total = ConductorState.fromMap(state).total;
    final last = total <= 0 ? -1 : total - 1;
    final i = (s['i'] as num?)?.toInt() ?? -1;
    switch (intent) {
      case GameIntent.pick: // tap a specific word
        final target = (args['i'] as num?)?.toInt() ?? -1;
        s['i'] = target.clamp(-1, last);
      case GameIntent.next:
        s['i'] = (i + 1).clamp(0, last < 0 ? 0 : last);
      case GameIntent.back:
        s['i'] = i <= 0 ? -1 : i - 1; // step back, then clear
      case GameIntent.reset: // clear the spotlight
        s['i'] = -1;
      case GameIntent.reveal:
      case GameIntent.tally:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(ConductorState s) => {
    GameIntent.pick,
    GameIntent.next,
    GameIntent.back,
    GameIntent.reset,
  };

  @override
  Widget buildStage(BuildContext context, ConductorState s) {
    return ColoredBox(
      color: vibe.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: _Lines(state: s, accent: vibe.accent, big: true),
        ),
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    ConductorState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _Lines(
              state: state,
              accent: vibe.accent,
              big: false,
              onTapWord: (i) => send(GameIntent.pick, {'i': i}),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => send(GameIntent.back),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => send(GameIntent.reset),
                  icon: const Icon(Icons.highlight_off),
                  label: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => send(GameIntent.next),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renders the lines, lighting the active word. [onTapWord] non-null makes
/// every word a tap target (the controller); null = display only (the stage).
class _Lines extends StatelessWidget {
  const _Lines({
    required this.state,
    required this.accent,
    required this.big,
    this.onTapWord,
  });

  final ConductorState state;
  final Color accent;
  final bool big;
  final void Function(int flatIndex)? onTapWord;

  @override
  Widget build(BuildContext context) {
    final hasFocus = state.active >= 0;
    var flat = -1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in state.lines)
          Padding(
            padding: EdgeInsets.symmetric(vertical: big ? 8 : 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: big ? 14 : 8,
              runSpacing: big ? 8 : 4,
              children: [
                for (final word in line)
                  Builder(
                    builder: (context) {
                      flat++;
                      final idx = flat;
                      final lit = state.active == idx;
                      final dim = hasFocus && !lit;
                      final text = Text(
                        word,
                        style: TextStyle(
                          color: lit
                              ? accent
                              : dim
                              ? Colors.white24
                              : Colors.white,
                          fontSize: big ? (lit ? 64 : 48) : 20,
                          fontWeight: lit ? FontWeight.w800 : FontWeight.w500,
                          height: 1.1,
                        ),
                      );
                      if (onTapWord == null) return text;
                      return InkWell(
                        onTap: () => onTapWord!(idx),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: text,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
