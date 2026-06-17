import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// Attention Signals — a non-game presentable (docs/VISION.md #18). One-tap
/// full-screen room cues the teacher throws up from their phone to move the
/// room: Eyes up, Quiet, Clean up, Line up, Breathe, Freeze. The first use of
/// the `pick` intent. Cues are STATIC (in code), so only the picked index
/// rides the wire — the controller renders the same buttons from this list.
class _Cue {
  const _Cue(this.emoji, this.label, this.color);
  final String emoji;
  final String label;
  final Color color;
}

const _cues = <_Cue>[
  _Cue('👀', 'Eyes up', ActivityPalette.blue),
  _Cue('🤫', 'Quiet please', ActivityPalette.deepPurple),
  _Cue('👂', 'Listen', ActivityPalette.teal),
  _Cue('✋', 'Hands up', ActivityPalette.pink),
  _Cue('🧹', 'Clean up', ActivityPalette.amber),
  _Cue('🚶', 'Line up', ActivityPalette.indigo),
  _Cue('🧊', 'Freeze', ActivityPalette.lightBlue),
  _Cue('🌬️', 'Breathe', ActivityPalette.green),
];

class CueState {
  const CueState({required this.index});

  factory CueState.fromMap(Map<String, dynamic> m) =>
      CueState(index: (m['i'] as num?)?.toInt() ?? 0);

  final int index;
}

class CuesGame extends GameDefinition<CueState> {
  const CuesGame();

  @override
  String get id => 'cues';

  @override
  String get title => 'Signals';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.coral);

  @override
  String? get liveRoute => '/live/cues';

  @override
  Map<String, dynamic> initialState(ContentSource content) => {'i': 0};

  @override
  CueState decode(Map<String, dynamic> state) => CueState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final i = (s['i'] as num?)?.toInt() ?? 0;
    switch (intent) {
      case GameIntent.pick:
        final c = (args['cue'] as num?)?.toInt();
        if (c != null && c >= 0 && c < _cues.length) s['i'] = c;
      case GameIntent.next:
        s['i'] = (i + 1) % _cues.length;
      case GameIntent.reset:
        s['i'] = 0;
      case GameIntent.back:
      case GameIntent.reveal:
      case GameIntent.tally:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(CueState s) => {GameIntent.pick, GameIntent.next};

  @override
  Widget buildStage(BuildContext context, CueState s) {
    final cue = _cues[s.index % _cues.length];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      color: cue.color,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cue.emoji, style: const TextStyle(fontSize: 140)),
            const SizedBox(height: 16),
            Text(
              cue.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    CueState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _cues.length; i++)
          FilledButton.tonal(
            onPressed: () => send(GameIntent.pick, {'cue': i}),
            style: i == state.index
                ? FilledButton.styleFrom(
                    backgroundColor: vibe.accent,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: Text('${_cues[i].emoji} ${_cues[i].label}'),
          ),
      ],
    );
  }
}
