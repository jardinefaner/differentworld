import 'dart:async';
import 'dart:math' as math;

import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/features/surveys/widgets/chibi_smiley.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Three-chibi agree/neutral/disagree row.
///
/// Tap any of the three smileys to set the answer — squash, particle
/// burst, color modulation, auto-advance handled by the caller via
/// [onAnswered]. Practice questions render with friendlier labels.
class Agree3Row extends StatefulWidget {
  const Agree3Row({
    required this.question,
    required this.answers,
    required this.variant,
    required this.onAnswered,
    super.key,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;
  final ChibiVariant variant;
  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  State<Agree3Row> createState() => _Agree3RowState();
}

class _Agree3RowState extends State<Agree3Row> {
  int? _tappingValue;
  Timer? _tapTimer;

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _onTap(int value) {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _tappingValue = value);
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _tappingValue = null);
    });
    final next = SurveyAnswers.fromJson(widget.answers.toJson())
      ..setAgree3(widget.question.key, value);
    widget.onAnswered(next);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.answers.agree3(widget.question.key);
    return LayoutBuilder(
      builder: (context, c) {
        final smileySize = ((c.maxWidth - 32) / 3).clamp(96.0, 160.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final value in const [0, 1, 2])
              SmileyChoice(
                variant: widget.variant,
                expression: ChibiExpression.forAgree3(value),
                label: ChibiExpression.agree3Label(
                  value,
                  practice: widget.question.isPractice,
                ),
                size: smileySize,
                selected: selected == value,
                dimmed: selected != null && selected != value,
                tapping: _tappingValue == value,
                onTap: () => _onTap(value),
              ),
          ],
        );
      },
    );
  }
}

/// One of the three tappable chibis in an [Agree3Row].
class SmileyChoice extends StatelessWidget {
  const SmileyChoice({
    required this.variant,
    required this.expression,
    required this.label,
    required this.size,
    required this.selected,
    required this.dimmed,
    required this.tapping,
    required this.onTap,
    super.key,
  });

  final ChibiVariant variant;
  final ChibiExpression expression;
  final String label;
  final double size;
  final bool selected;
  final bool dimmed;
  final bool tapping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ChibiSmiley(
                      variant: variant,
                      expression: expression,
                      size: size,
                      selected: selected,
                      dimmed: dimmed,
                      tapping: tapping,
                    ),
                    if (tapping)
                      SelectionBurst(
                        key: ValueKey('burst-${UniqueKey()}'),
                        size: size,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: size,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: dimmed
                        ? theme.colorScheme.onSurfaceVariant
                        : selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

/// Eight particles radiating from the center, fading out over ~600ms.
/// Runs once per mount — the parent rebuilds with a new key when it
/// wants the burst to fire again.
class SelectionBurst extends StatefulWidget {
  const SelectionBurst({required this.size, super.key});
  final double size;

  @override
  State<SelectionBurst> createState() => _SelectionBurstState();
}

class _SelectionBurstState extends State<SelectionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    unawaited(_c.forward());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _BurstPainter(
            t: _c.value,
            color: theme.colorScheme.primary,
          ),
          size: Size(widget.size, widget.size),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.t, required this.color});
  final double t; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.55;
    for (var i = 0; i < 8; i++) {
      final angle = i * (math.pi / 4);
      final d = Curves.easeOutCubic.transform(t) * maxR;
      final dx = math.cos(angle) * d;
      final dy = math.sin(angle) * d;
      final alpha = (1 - t).clamp(0.0, 1.0);
      final radius = 5 * (1 - t * 0.6);
      canvas.drawCircle(
        center + Offset(dx, dy),
        radius,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.t != t || old.color != color;
}

/// Multiselect — one row per option, each row has Yes / No chibis.
/// No auto-advance; kid hits Next at the bottom when ready.
class MultiselectList extends StatelessWidget {
  const MultiselectList({
    required this.question,
    required this.answers,
    required this.variant,
    required this.onAnswered,
    super.key,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;
  final ChibiVariant variant;
  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = answers.multiselect(question.key).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'For each one, tap Yes or No.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        for (final opt in question.options) ...[
          _MultiOptionRow(
            label: opt.label,
            variant: variant,
            isYes: picked.contains(opt.key),
            onYes: () {
              unawaited(HapticFeedback.selectionClick());
              final next = picked.toSet()..add(opt.key);
              final updated = SurveyAnswers.fromJson(answers.toJson())
                ..setMultiselect(question.key, next.toList());
              onAnswered(updated);
            },
            onNo: () {
              unawaited(HapticFeedback.selectionClick());
              final next = picked.toSet()..remove(opt.key);
              final updated = SurveyAnswers.fromJson(answers.toJson())
                ..setMultiselect(question.key, next.toList());
              onAnswered(updated);
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MultiOptionRow extends StatelessWidget {
  const _MultiOptionRow({
    required this.label,
    required this.variant,
    required this.isYes,
    required this.onYes,
    required this.onNo,
  });

  final String label;
  final ChibiVariant variant;
  final bool isYes;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const chibiSize = 72.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _OptionToggleChip(
            label: 'No',
            variant: variant,
            expression: ChibiExpression.sad,
            size: chibiSize,
            selected: !isYes,
            onTap: onNo,
          ),
          const SizedBox(width: 8),
          _OptionToggleChip(
            label: 'Yes',
            variant: variant,
            expression: ChibiExpression.happy,
            size: chibiSize,
            selected: isYes,
            onTap: onYes,
          ),
        ],
      ),
    );
  }
}

class _OptionToggleChip extends StatelessWidget {
  const _OptionToggleChip({
    required this.label,
    required this.variant,
    required this.expression,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ChibiVariant variant;
  final ChibiExpression expression;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChibiSmiley(
              variant: variant,
              expression: expression,
              size: size,
              selected: selected,
              dimmed: !selected,
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text question — debounced autosave, no auto-advance.
/// Next button at the bottom lets the kid commit when ready.
class TextAnswer extends StatefulWidget {
  const TextAnswer({
    required this.question,
    required this.answers,
    required this.onAnswered,
    super.key,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;
  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  State<TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<TextAnswer> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.answers.text(widget.question.key),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final updated = SurveyAnswers.fromJson(widget.answers.toJson())
        ..setText(widget.question.key, v.trim());
      widget.onAnswered(updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Write here, or say it out loud and the teacher will type it.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type what they said…',
          ),
          onChanged: _onChanged,
        ),
      ],
    );
  }
}
