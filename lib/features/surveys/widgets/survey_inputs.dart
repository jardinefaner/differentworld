import 'dart:async';
import 'dart:math' as math;

import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/features/surveys/widgets/chibi_smiley.dart';
import 'package:differentworld/features/voice/deepgram_voice_service.dart';
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
///
/// Wave 134: a mic icon on the trailing edge of the field opens a
/// live Deepgram dictation session. The kid (or teacher) taps it,
/// speaks, and the transcript appends to whatever's already in the
/// field. Same prefix-preservation pattern as the omnibox bar and
/// the observation form mic: snapshot the field value at session
/// start, append the live transcript stream.
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
  // Wave 134: Deepgram dictation. Local controller (not the AppShell
  // singleton) so survey-take isolation matches the observation form.
  late final DeepgramVoiceController _voice;
  StreamSubscription<VoiceUpdate>? _voiceSub;
  bool _voiceActive = false;
  String _voicePrefix = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.answers.text(widget.question.key),
    );
    _voice = DeepgramVoiceController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_voiceSub?.cancel());
    unawaited(_voice.dispose());
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

  void _toggleVoice() {
    if (_voiceActive) {
      unawaited(_voice.stop());
      return;
    }
    _voicePrefix = _controller.text;
    setState(() => _voiceActive = true);
    _voiceSub = _voice.updates.listen(_onVoiceUpdate);
    unawaited(_voice.start());
  }

  void _onVoiceUpdate(VoiceUpdate update) {
    if (!mounted) return;
    if (update.state == VoiceState.error) {
      _voiceActive = false;
      unawaited(_voiceSub?.cancel());
      _voiceSub = null;
      final msg = update.errorMessage ?? 'Voice dictation failed.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(msg)),
      );
      setState(() {});
      return;
    }
    final transcript = update.transcript.trim();
    final glue = (_voicePrefix.isEmpty || transcript.isEmpty) ? '' : ' ';
    final combined = '$_voicePrefix$glue$transcript';
    _controller
      ..text = combined
      ..selection = TextSelection.collapsed(offset: combined.length);
    // Treat each transcript chunk like a typed change so autosave
    // catches up.
    _onChanged(combined);
    if (update.state == VoiceState.idle) {
      _voiceActive = false;
      unawaited(_voiceSub?.cancel());
      _voiceSub = null;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _voiceActive
              ? 'Listening… tap the mic to stop.'
              : 'Tap the mic to say it out loud, or type below.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: _voiceActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Type what they said…',
            // Wave 134: mic icon as suffix. Big tap target via
            // IconButton's default 48dp insets — same pattern the
            // observation form uses.
            suffixIcon: IconButton(
              tooltip: _voiceActive ? 'Stop dictation' : 'Dictate by voice',
              icon: Icon(
                _voiceActive ? Icons.stop_circle : Icons.mic_none_outlined,
                color: _voiceActive ? theme.colorScheme.error : null,
              ),
              onPressed: _toggleVoice,
            ),
          ),
          onChanged: _onChanged,
        ),
      ],
    );
  }
}

/// Wave 167: 5-point scale row used by `agree5` and `likeMe5` questions.
/// Five tappable cells, each with an emoji at top + a 2-line label
/// underneath. Tap → store value 0..4 → caller auto-advances.
///
/// The five labels and emoji are passed in, so the same widget powers
/// "Strongly disagree → Strongly agree" (agree5) and "Not like me →
/// Exactly like me" (likeMe5). For older 4-6th graders, this scale
/// is what the BASECamp paper survey uses, so the digital take has
/// to match for the data to be comparable across years.
class Scale5Row extends StatefulWidget {
  const Scale5Row({
    required this.question,
    required this.answers,
    required this.labels,
    required this.emoji,
    required this.onAnswered,
    super.key,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;

  /// Five labels rendered under each cell. Index 0 = leftmost
  /// ("Strongly disagree" / "Not like me"); index 4 = rightmost.
  final List<String> labels;

  /// Five emoji glyphs, one per cell. For agree5 the 5 sad-to-happy
  /// faces; for likeMe5 a 5-cell circle progression (○ ◔ ◑ ◕ ●) or
  /// similar.
  final List<String> emoji;

  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  State<Scale5Row> createState() => _Scale5RowState();
}

class _Scale5RowState extends State<Scale5Row> {
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
      ..setScale5(widget.question.key, value);
    widget.onAnswered(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.answers.scale5(widget.question.key);
    return LayoutBuilder(
      builder: (context, c) {
        // Five cells with small gutters between. Older kids handle a
        // tighter grid than the K-3 smiley row.
        final cellSize = ((c.maxWidth - 32) / 5).clamp(56.0, 110.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var value = 0; value < 5; value++)
              _Scale5Cell(
                emoji: widget.emoji[value],
                label: widget.labels[value],
                size: cellSize,
                selected: selected == value,
                dimmed: selected != null && selected != value,
                tapping: _tappingValue == value,
                onTap: () => _onTap(value),
                color: theme.colorScheme.primary,
              ),
          ],
        );
      },
    );
  }
}

class _Scale5Cell extends StatelessWidget {
  const _Scale5Cell({
    required this.emoji,
    required this.label,
    required this.size,
    required this.selected,
    required this.dimmed,
    required this.tapping,
    required this.onTap,
    required this.color,
  });

  final String emoji;
  final String label;
  final double size;
  final bool selected;
  final bool dimmed;
  final bool tapping;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaleAnim = tapping ? 0.9 : (selected ? 1.06 : 1.0);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedScale(
          scale: scaleAnim,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.18)
                        : theme.colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? color
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                      width: selected ? 3 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: dimmed ? 0.4 : 1.0,
                    child: Text(
                      emoji,
                      style: TextStyle(
                        fontSize: math.min(size * 0.55, 48),
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: size + 12,
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: dimmed
                          ? theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            )
                          : selected
                          ? color
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      height: 1.2,
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
}

/// Wave 167: standard label/emoji sets for the two 5-point scales.
/// Centralised so the take screen, table renderer, and any future
/// docs share one source of truth.
abstract final class Scale5Sets {
  /// Five faces from strongly-disagree to strongly-agree.
  static const agreeEmoji = ['🙁', '🫤', '😐', '🙂', '😃'];

  /// English labels for agree5.
  static const agreeLabelsEn = [
    'Strongly disagree',
    'Disagree',
    'Kind of agree',
    'Agree',
    'Strongly agree',
  ];

  /// Spanish labels for agree5.
  static const agreeLabelsEs = [
    'Muy en desacuerdo',
    'En desacuerdo',
    'Más o menos',
    'De acuerdo',
    'Muy de acuerdo',
  ];

  /// Filled-progression emoji for likeMe5 — same shape as the React
  /// mock so the kid associates "more filled = more like me."
  static const likeMeEmoji = ['○', '◔', '◑', '◕', '●'];

  static const likeMeLabelsEn = [
    'Not like me',
    'A little like me',
    'Somewhat like me',
    'Mostly like me',
    'Exactly like me',
  ];

  static const likeMeLabelsEs = [
    'No como yo',
    'Poco como yo',
    'Algo como yo',
    'Bastante como yo',
    'Igual que yo',
  ];
}
