import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/math_game.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:flutter/material.dart';

/// The Math Game on the unified framework: one question at a time, big; the
/// room answers ALOUD; the teacher taps Reveal (the answer glows — never a red
/// "wrong"), then Next. No typing, no grading. Questions are generated locally
/// (arithmetic is free + infinite) and ride in the wire-state, so it can now
/// go present/live too.
class MathQuizState {
  const MathQuizState({
    this.index = 0,
    this.revealed = false,
    this.done = false,
    this.questions = const [],
  });

  factory MathQuizState.fromMap(Map<String, dynamic> m) => MathQuizState(
    index: (m['i'] as num?)?.toInt() ?? 0,
    revealed: m['r'] == true,
    done: m['d'] == true,
    questions: [
      for (final q in (m['qs'] as List? ?? const []))
        _questionFromMap((q as Map).cast<String, dynamic>()),
    ],
  );

  final int index;
  final bool revealed;
  final bool done;
  final List<MathQuestion> questions;

  int get total => questions.length;
  MathQuestion? get question => questions.isEmpty
      ? null
      : questions[index.clamp(0, questions.length - 1)];
  bool get atEnd => index >= questions.length - 1;
}

Map<String, dynamic> _questionToMap(MathQuestion q) => {
  'm': q.mechanic.name,
  'p': q.prompt,
  'a': q.answer,
  'c': q.choices,
  if (q.statementTrue != null) 'st': q.statementTrue,
};

MathQuestion _questionFromMap(Map<String, dynamic> m) => MathQuestion(
  mechanic: MathMechanic.values.firstWhere(
    (e) => e.name == m['m'],
    orElse: () => MathMechanic.choose,
  ),
  prompt: (m['p'] as String?) ?? '',
  answer: (m['a'] as num?)?.toInt() ?? 0,
  choices: [for (final c in (m['c'] as List? ?? const [])) (c as num).toInt()],
  statementTrue: m['st'] as bool?,
);

class MathQuizGame extends GameDefinition<MathQuizState> {
  const MathQuizGame();

  @override
  String get id => 'math-game';

  @override
  String get title => 'Math Game';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.slate);

  @override
  String? get liveRoute => '/live/math-game';

  @override
  List<GameSetting> get settings => const [
    IntSetting(
      id: 'min',
      label: 'Smallest number',
      min: 0,
      max: 20,
      initial: 1,
    ),
    IntSetting(
      id: 'max',
      label: 'Biggest number',
      min: 5,
      max: 100,
      initial: 12,
    ),
    MultiSetting(
      id: 'ops',
      label: 'Operations',
      options: [
        (value: 'add', label: '+'),
        (value: 'subtract', label: '−'),
        (value: 'multiply', label: '×'),
        (value: 'divide', label: '÷'),
      ],
      initial: {'add'},
    ),
    IntSetting(
      id: 'count',
      label: 'How many questions',
      min: 4,
      max: 20,
      initial: 8,
    ),
  ];

  @override
  Map<String, dynamic> initialState(ContentSource content) =>
      initialStateFor(content, defaultSettingValues(settings));

  @override
  Map<String, dynamic> initialStateFor(
    ContentSource content,
    Map<String, Object?> values,
  ) {
    final minN = values.intSetting('min', 1);
    final maxN = values.intSetting('max', 12);
    final count = values.intSetting('count', 8);
    final opIds = values.multiSetting('ops', const {'add'});
    final ops = {
      for (final o in MathOp.values)
        if (opIds.contains(o.name)) o,
    };
    final qs = generateMathRound(
      Random(),
      count: count,
      min: minN,
      max: maxN,
      operations: ops.isEmpty ? const {MathOp.add} : ops,
    );
    return {
      'i': 0,
      'r': false,
      'd': false,
      'n': qs.length,
      'qs': [for (final q in qs) _questionToMap(q)],
    };
  }

  @override
  MathQuizState decode(Map<String, dynamic> state) =>
      MathQuizState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final i = (s['i'] as num?)?.toInt() ?? 0;
    final n = (s['n'] as num?)?.toInt() ?? 0;
    switch (intent) {
      case GameIntent.reveal:
        s['r'] = true;
      case GameIntent.next:
        if (i >= n - 1) {
          s['d'] = true;
        } else {
          s['i'] = i + 1;
          s['r'] = false;
        }
      case GameIntent.reset: // Replay the same round (the reducer is pure).
        s['i'] = 0;
        s['r'] = false;
        s['d'] = false;
      case GameIntent.back:
      case GameIntent.tally:
      case GameIntent.pick:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(MathQuizState s) {
    if (s.done) return {GameIntent.reset};
    return s.revealed ? {GameIntent.next} : {GameIntent.reveal};
  }

  @override
  Widget buildStage(BuildContext context, MathQuizState s) {
    final theme = Theme.of(context);
    if (s.done) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: vibe.accent, size: 56),
            const SizedBox(height: 16),
            Text(
              'Nice round!',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${s.total} questions, together.',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      );
    }
    final q = s.question;
    if (q == null) return const SizedBox.shrink();
    return GameStage.frame(
      context,
      eyebrow: '${s.index + 1} / ${s.total}',
      hero: GameStage.hero(
        context,
        q.mechanic == MathMechanic.choose ? '${q.prompt} = ?' : q.prompt,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            s.revealed ? 'There it is!' : 'Say it out loud — then Reveal',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
          ),
          const SizedBox(height: 28),
          _answerArea(context, q, revealed: s.revealed),
        ],
      ),
    );
  }

  Widget _answerArea(
    BuildContext context,
    MathQuestion q, {
    required bool revealed,
  }) {
    switch (q.mechanic) {
      case MathMechanic.choose:
      case MathMechanic.sequence:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in q.choices)
              GameStage.option(
                context,
                '$c',
                accent: vibe.accent,
                selected: revealed && c == q.answer,
                dimmed: revealed && c != q.answer,
                fontSize: 24,
              ),
          ],
        );
      case MathMechanic.trueFalse:
        final answer = q.statementTrue ?? true;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameStage.option(
              context,
              'True',
              accent: vibe.accent,
              selected: revealed && answer,
              dimmed: revealed && !answer,
              fontSize: 22,
            ),
            const SizedBox(width: 16),
            GameStage.option(
              context,
              'False',
              accent: vibe.accent,
              selected: revealed && !answer,
              dimmed: revealed && answer,
              fontSize: 22,
            ),
          ],
        );
    }
  }

  @override
  Widget? buildControls(
    BuildContext context,
    MathQuizState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    final (intent, icon, label) = state.done
        ? (GameIntent.reset, Icons.replay, 'Play again')
        : state.revealed
        ? (
            GameIntent.next,
            Icons.arrow_forward,
            state.atEnd ? 'See the round' : 'Next',
          )
        : (GameIntent.reveal, Icons.visibility_outlined, 'Reveal');
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => send(intent),
            icon: Icon(icon),
            label: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
