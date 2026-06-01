import 'dart:async';
import 'dart:math';

import 'package:differentworld/features/activity_runtime/math_game.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/math-game` — Math as a GAME: one question at a time, varied
/// mechanics (pick a button, type the answer, true/false, what-comes-next
/// sequences), instant feedback, a score. Questions are generated locally
/// (no AI). The conducted, kid-mode counterpart to the "Many Paths"
/// creative exercise.
class MathGameScreen extends ConsumerStatefulWidget {
  const MathGameScreen({super.key});

  @override
  ConsumerState<MathGameScreen> createState() => _MathGameScreenState();
}

class _MathGameScreenState extends ConsumerState<MathGameScreen> {
  late List<MathQuestion> _questions;
  int _index = 0;
  int _score = 0;
  bool _locked = false; // answered current; showing feedback
  bool _wasCorrect = false;
  bool _done = false;

  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();

  MathQuestion get _q => _questions[_index];

  @override
  void initState() {
    super.initState();
    _questions = generateMathRound(Random());
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _answer(Object given) {
    if (_locked) return;
    final correct = _q.isCorrect(given);
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _locked = true;
      _wasCorrect = correct;
      if (correct) _score++;
    });
    _focus.unfocus();
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      setState(() => _done = true);
      return;
    }
    setState(() {
      _index++;
      _locked = false;
      _ctl.clear();
    });
    if (_q.mechanic == MathMechanic.type) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _q.mechanic != MathMechanic.type) return;
        _focus.requestFocus();
        unawaited(
          SystemChannels.textInput.invokeMethod<void>('TextInput.show'),
        );
      });
    }
  }

  void _again() {
    setState(() {
      _questions = generateMathRound(Random());
      _index = 0;
      _score = 0;
      _locked = false;
      _done = false;
      _ctl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: Colors.black,
        child: _done ? _recap(context) : _game(context),
      ),
    );
  }

  Widget _game(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Question ${_index + 1} / ${_questions.length}   ·   ⭐ $_score',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _q.mechanic == MathMechanic.trueFalse
                      ? _q.prompt
                      : _q.mechanic == MathMechanic.sequence
                      ? _q.prompt
                      : '${_q.prompt} = ?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 32),
                // Keyed by index so the type-field's input connection isn't
                // matched across questions.
                KeyedSubtree(
                  key: ValueKey('q$_index'),
                  child: _answerArea(context),
                ),
                const SizedBox(height: 20),
                if (_locked) _feedback(context),
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
              _BigButton(
                label: '$c',
                onTap: _locked ? null : () => _answer(c),
              ),
          ],
        );
      case MathMechanic.trueFalse:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BigButton(
              label: 'True',
              onTap: _locked ? null : () => _answer(true),
            ),
            const SizedBox(width: 16),
            _BigButton(
              label: 'False',
              onTap: _locked ? null : () => _answer(false),
            ),
          ],
        );
      case MathMechanic.type:
        return Column(
          children: [
            TextField(
              controller: _ctl,
              focusNode: _focus,
              autofocus: true,
              enabled: !_locked,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: '?',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              onSubmitted: (_) => _submitTyped(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (_locked || int.tryParse(_ctl.text.trim()) == null)
                  ? null
                  : _submitTyped,
              child: const Text('Check'),
            ),
          ],
        );
    }
  }

  void _submitTyped() {
    final n = int.tryParse(_ctl.text.trim());
    if (n == null) return;
    _answer(n);
  }

  Widget _feedback(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          _wasCorrect ? '✓ Nice!' : '✗ The answer is ${_answerLabel()}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: _wasCorrect ? Colors.greenAccent : Colors.redAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _next,
          icon: const Icon(Icons.arrow_forward),
          label: Text(_index + 1 >= _questions.length ? 'See score' : 'Next'),
        ),
      ],
    );
  }

  String _answerLabel() {
    if (_q.mechanic == MathMechanic.trueFalse) {
      return _q.statementTrue! ? 'True' : 'False';
    }
    return '${_q.answer}';
  }

  Widget _recap(BuildContext context) {
    final theme = Theme.of(context);
    final n = _questions.length;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Colors.amberAccent,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'You got $_score of $n!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.tonal(
                onPressed: _again,
                child: const Text('Play again'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hand the device back to your teacher.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 72,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}
