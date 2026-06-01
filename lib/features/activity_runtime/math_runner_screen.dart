import 'dart:async';

import 'package:differentworld/features/activity_runtime/activity_script.dart';
import 'package:differentworld/features/activity_runtime/math_inverse.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/math?target=N` — the first VISIBLE conducted experience
/// (docs/ACTIVITY_RUNTIME.md, Slice 2). Drives one Math inverse activity
/// through its phases: present the target → the learner invents
/// expressions that equal it (validated live) → reveal the room's variety
/// → ponder. A teacher-paced break (game-show-host model), NOT a locked
/// kid surface — the floating back arrow exits like any other screen.
///
/// Prototype scope: the room's answers live in screen state — a run's
/// captures are NOT yet persisted as entries (deferred per the doc). No
/// AI, no network: generation + validation are pure local arithmetic.
class MathRunnerScreen extends ConsumerStatefulWidget {
  const MathRunnerScreen({required this.target, super.key});

  final int target;

  @override
  ConsumerState<MathRunnerScreen> createState() => _MathRunnerScreenState();
}

class _MathRunnerScreenState extends ConsumerState<MathRunnerScreen> {
  late final ActivityRun _run = ActivityRun(mathInverseActivity(widget.target));
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// Expressions the learner has banked this run (this device).
  final List<String> _answers = <String>[];

  /// Live verdict on the in-progress text (null when the field is empty).
  MathVerdict? _verdict;

  Timer? _ponderTimer;

  @override
  void dispose() {
    _ponderTimer?.cancel();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _advance() {
    _ponderTimer?.cancel();
    if (!_run.advance()) return;
    setState(() {
      _verdict = null;
      _ctl.clear();
    });
    final phase = _run.current;
    if (phase.mode == ActivityMode.create) {
      // Raise the keyboard for the input phase. requestFocus alone can
      // skip the Android IME (CLAUDE.md interaction invariant #4).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _run.current.mode != ActivityMode.create) return;
        _focus.requestFocus();
        unawaited(
          SystemChannels.textInput.invokeMethod<void>('TextInput.show'),
        );
      });
    } else {
      _focus.unfocus();
      if (phase.pacing == PacingKind.timer && phase.duration != null) {
        _ponderTimer = Timer(phase.duration!, () {
          if (mounted) _advance();
        });
      }
    }
  }

  void _onChanged(String text) {
    setState(() {
      _verdict = text.trim().isEmpty
          ? null
          : validateMathExpression(
              text,
              widget.target,
              roomAnswers: _answers.toSet(),
            );
    });
  }

  void _submit() {
    final v = _verdict;
    if (v == null || !v.valid || !v.equals || !v.novel) return;
    setState(() {
      _answers.add(_ctl.text.trim());
      _ctl.clear();
      _verdict = null;
    });
    // Keep the field hot so they can bank another path.
    _focus.requestFocus();
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
  }

  @override
  Widget build(BuildContext context) {
    // A teacher-paced break (not a locked kid surface) — the floating
    // back arrow exits like any other screen.
    return EdgeScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              // Keyed by phase id so swapping phases gives Flutter a clean
              // identity — the create-phase TextField never gets matched to
              // a sibling phase's widget (tearing down its input connection).
              child: KeyedSubtree(
                key: ValueKey('phase-${_run.current.id}'),
                child: _phaseBody(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phaseBody(BuildContext context) {
    final phase = _run.current;
    switch (phase.mode) {
      case ActivityMode.present:
        return phase.id == 'reveal'
            ? _reveal(context, phase)
            : _present(context, phase);
      case ActivityMode.create:
        return _create(context, phase);
      case ActivityMode.ponder:
        return _ponder(context, phase);
      // Modes not used by the Math archetype — defensive fallthrough.
      case ActivityMode.click:
      case ActivityMode.shoot:
      case ActivityMode.answer:
      case ActivityMode.vote:
        return _present(context, phase);
    }
  }

  Widget _present(BuildContext context, Phase phase) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${widget.target}',
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          phase.prompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: () {
            unawaited(HapticFeedback.selectionClick());
            _advance();
          },
          child: const Text("Let's go"),
        ),
      ],
    );
  }

  Widget _create(BuildContext context, Phase phase) {
    final theme = Theme.of(context);
    final v = _verdict;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            phase.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _ctl,
            focusNode: _focus,
            autofocus: true,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            style: theme.textTheme.headlineMedium,
            decoration: const InputDecoration(
              hintText: 'like  3 × 4',
              border: OutlineInputBorder(),
            ),
            onChanged: _onChanged,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          _VerdictChip(verdict: v, target: widget.target),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (v != null && v.valid && v.equals && v.novel)
                ? () {
                    unawaited(HapticFeedback.selectionClick());
                    _submit();
                  }
                : null,
            child: const Text('Add this path'),
          ),
          const SizedBox(height: 24),
          if (_answers.isNotEmpty) ...[
            Text(
              'Your paths so far',
              style: theme.textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in _answers) Chip(label: Text(a)),
              ],
            ),
            const SizedBox(height: 24),
          ],
          TextButton(
            onPressed: _answers.isEmpty ? null : _advance,
            child: const Text("I'm done — show the paths"),
          ),
        ],
      ),
    );
  }

  Widget _reveal(BuildContext context, Phase phase) {
    final theme = Theme.of(context);
    // The room's paths first, then a few more the generator found, so even
    // a solo learner sees that one answer has many roads.
    final mine = _answers.toSet();
    final more = generateInverseExpressions(widget.target)
        .where(
          (e) => !mine
              .map(canonicalizeExpression)
              .contains(
                canonicalizeExpression(e),
              ),
        )
        .take(6)
        .toList();
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          phase.prompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        if (_answers.isNotEmpty) ...[
          Text('Yours', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _answers)
                Chip(
                  label: Text(a),
                  backgroundColor: theme.colorScheme.primaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (more.isNotEmpty) ...[
          Text('More paths', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final e in more) Chip(label: Text(e))],
          ),
          const SizedBox(height: 32),
        ],
        Center(
          child: FilledButton(
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              _advance();
            },
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _ponder(BuildContext context, Phase phase) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _advance, // tap to move on early; the timer also advances
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.spa_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            phase.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

/// Live, non-nagging feedback for the create phase.
class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.verdict, required this.target});

  final MathVerdict? verdict;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = verdict;
    final (String text, Color color, IconData icon) = switch (v) {
      null => (
        'Type a question that makes $target',
        theme.colorScheme.outline,
        Icons.edit_outlined,
      ),
      _ when !v.valid => (
        'Not a finished question yet',
        theme.colorScheme.outline,
        Icons.more_horiz,
      ),
      _ when !v.equals => (
        'That makes ${_fmt(v.value)}, not $target',
        theme.colorScheme.error,
        Icons.close,
      ),
      _ when !v.novel => (
        'Someone already found that one — try another!',
        theme.colorScheme.tertiary,
        Icons.refresh,
      ),
      _ => ('Yes! that makes $target', Colors.green, Icons.check_circle),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  String _fmt(double? value) {
    if (value == null) return '?';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
}
