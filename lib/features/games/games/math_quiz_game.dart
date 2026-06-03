import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/math_game.dart';
import 'package:differentworld/features/games/game.dart';
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
  MathQuestion? get question =>
      questions.isEmpty ? null : questions[index.clamp(0, questions.length - 1)];
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
  GameVibe get vibe =>
      const GameVibe(accent: Color(0xFF4DD0E1), surface: Color(0xFF06121A));

  @override
  String? get liveRoute => '/live/math-game';

  @override
  Map<String, dynamic> initialState(ContentSource content) {
    final qs = generateMathRound(Random());
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
                fontWeight: FontWeight.w800,
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${s.index + 1} / ${s.total}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                q.mechanic == MathMechanic.choose ? '${q.prompt} = ?' : q.prompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.revealed ? 'There it is!' : 'Say it out loud — then Reveal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 28),
              _answerArea(q, revealed: s.revealed),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answerArea(MathQuestion q, {required bool revealed}) {
    switch (q.mechanic) {
      case MathMechanic.choose:
      case MathMechanic.sequence:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in q.choices)
              _Option(
                label: '$c',
                highlight: revealed && c == q.answer,
                dim: revealed && c != q.answer,
              ),
          ],
        );
      case MathMechanic.trueFalse:
        final answer = q.statementTrue ?? true;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Option(
              label: 'True',
              highlight: revealed && answer,
              dim: revealed && !answer,
            ),
            const SizedBox(width: 16),
            _Option(
              label: 'False',
              highlight: revealed && !answer,
              dim: revealed && answer,
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

/// A non-interactive option — the room answers aloud; Reveal glows the correct
/// one (never a red "wrong"; the others recede).
class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.highlight,
    required this.dim,
  });

  final String label;
  final bool highlight;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? Colors.greenAccent
        : Colors.white.withValues(alpha: dim ? 0.06 : 0.14);
    final fg = highlight
        ? Colors.black87
        : Colors.white.withValues(alpha: dim ? 0.4 : 1);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 116,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.w800),
      ),
    );
  }
}
