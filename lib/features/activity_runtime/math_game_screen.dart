import 'dart:async';
import 'dart:math';

import 'package:differentworld/features/activity_runtime/math_game.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `/activity/math-game` — Math as a host-run break (docs/ACTIVITY_ROADMAP.md
/// Wave 2). TEACHER-paced, NO typing, NO grading: one question at a time,
/// big; the room answers ALOUD; the teacher taps **Reveal** (the answer
/// glows — celebratory, never a red "wrong" on the others) then **Next**.
/// No score. Questions generated locally (no AI).
class MathGameScreen extends StatefulWidget {
  const MathGameScreen({super.key});

  @override
  State<MathGameScreen> createState() => _MathGameScreenState();
}

class _MathGameScreenState extends State<MathGameScreen> {
  late List<MathQuestion> _questions;
  int _index = 0;
  bool _revealed = false;
  bool _done = false;

  MathQuestion get _q => _questions[_index];

  @override
  void initState() {
    super.initState();
    _questions = generateMathRound(Random());
  }

  void _reveal() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _revealed = true);
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      setState(() => _done = true);
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  void _again() {
    setState(() {
      _questions = generateMathRound(Random());
      _index = 0;
      _revealed = false;
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: Colors.black,
        child: SafeArea(child: _done ? _recap(context) : _game(context)),
      ),
    );
  }

  Widget _game(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_index + 1} / ${_questions.length}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _q.mechanic == MathMechanic.choose ? '${_q.prompt} = ?' : _q.prompt,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _revealed ? 'There it is!' : 'Say it out loud — then Reveal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 28),
                _answerArea(context),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: _revealed
                      ? FilledButton.icon(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
                          ),
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            _index + 1 >= _questions.length
                                ? 'See the round'
                                : 'Next',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _reveal,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text(
                            'Reveal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _answerArea(BuildContext context) {
    switch (_q.mechanic) {
      case MathMechanic.choose:
      case MathMechanic.sequence:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in _q.choices)
              _Option(
                label: '$c',
                highlight: _revealed && c == _q.answer,
                dim: _revealed && c != _q.answer,
              ),
          ],
        );
      case MathMechanic.trueFalse:
        final answer = _q.statementTrue ?? true;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Option(
              label: 'True',
              highlight: _revealed && answer,
              dim: _revealed && !answer,
            ),
            const SizedBox(width: 16),
            _Option(
              label: 'False',
              highlight: _revealed && !answer,
              dim: _revealed && answer,
            ),
          ],
        );
    }
  }

  Widget _recap(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 56),
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
              '${_questions.length} questions, together.',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 28),
            FilledButton.tonal(
              onPressed: _again,
              child: const Text('Play again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A non-interactive option — the room answers aloud; Reveal glows the
/// correct one (never a red "wrong" on the others; they just recede).
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.w800),
      ),
    );
  }
}
