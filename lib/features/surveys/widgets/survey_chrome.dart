import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/features/surveys/widgets/chibi_smiley.dart';
import 'package:differentworld/features/surveys/widgets/survey_inputs.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/progress_dots.dart';
import 'package:flutter/material.dart';

/// Bottom-bar Next button. Hidden during agree3 (auto-advance handles
/// that) and at the closeout page.
class SurveyForwardButton extends StatelessWidget {
  const SurveyForwardButton({
    required this.question,
    required this.atCloseout,
    required this.onTap,
    super.key,
  });

  final SurveyQuestion question;
  final bool atCloseout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (atCloseout) return const SizedBox.shrink();
    if (question.kind == SurveyQuestionKind.agree3) {
      return const SizedBox.shrink();
    }
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_forward),
      label: const Text('Next'),
    );
  }
}

/// Top-of-screen identity strip: avatar + name, template title, save
/// indicator, progress dots.
class SurveyHeader extends StatefulWidget {
  const SurveyHeader({
    required this.template,
    required this.subject,
    required this.progressIndex,
    required this.progressTotal,
    required this.answeredScored,
    required this.scoredTotal,
    required this.atCloseout,
    required this.saving,
    super.key,
  });

  final SurveyTemplate template;
  final Subject? subject;
  final int progressIndex;
  final int progressTotal;
  final int answeredScored;
  final int scoredTotal;
  final bool atCloseout;

  /// When the parent's autosave is in flight, we briefly pulse a cloud
  /// icon next to the count so the user feels the save commit. Subtle,
  /// not a snackbar.
  final bool saving;

  @override
  State<SurveyHeader> createState() => _SurveyHeaderState();
}

class _SurveyHeaderState extends State<SurveyHeader> {
  bool _pulseCloud = false;

  @override
  void didUpdateWidget(covariant SurveyHeader old) {
    super.didUpdateWidget(old);
    if (widget.saving && !old.saving) {
      setState(() => _pulseCloud = true);
      Future<void>.delayed(const Duration(milliseconds: 850), () {
        if (!mounted) return;
        setState(() => _pulseCloud = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.subject == null
        ? 'Survey'
        : '${widget.subject!.firstName} ${widget.subject!.lastName}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.subject != null)
                PersonAvatar(
                  name: name,
                  photoUrl: widget.subject!.photoUrl,
                ),
              if (widget.subject != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    Text(
                      '${widget.template.title} · ${widget.template.year}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _pulseCloud
                    ? Icon(
                        Icons.cloud_done_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                        key: const ValueKey('saving'),
                      )
                    : const SizedBox(
                        width: 16,
                        key: ValueKey('idle'),
                      ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.answeredScored} / ${widget.scoredTotal}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProgressDots(
            count: widget.progressTotal,
            current: widget.atCloseout
                ? widget.progressTotal - 1
                : widget.progressIndex - 1,
          ),
        ],
      ),
    );
  }
}

/// One scrollable question page. Renders the right input widget for
/// the question's kind (agree3 / multiselect / text) plus a practice
/// badge if applicable.
class SurveyQuestionPage extends StatelessWidget {
  const SurveyQuestionPage({
    required this.questionIndex,
    required this.question,
    required this.answers,
    required this.onAnswered,
    this.onReplayTts,
    super.key,
  });

  final int questionIndex;
  final SurveyQuestion question;
  final SurveyAnswers answers;
  final void Function(SurveyAnswers next, {required bool autoAdvance})
      onAnswered;

  /// Wave 131: tapping the prompt text replays the TTS audio. Wired by
  /// survey_take_screen to call `_playQuestion(_index)`. Optional —
  /// when null (older callers / preview contexts), the prompt is a
  /// plain Text with no tap behavior.
  final VoidCallback? onReplayTts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variant = ChibiVariant.forQuestionIndex(questionIndex);
    // Wave 133: full-bleed. SingleChildScrollView still wraps the
    // content (so a long text-question on a small phone scrolls),
    // but the inner Column is sized to the viewport's min height
    // and uses MainAxisAlignment.center to float the question +
    // smileys vertically — feels like a single-purpose page, not
    // a card stuck to the top.
    return LayoutBuilder(
      builder: (ctx, c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          if (question.isPractice)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PracticeBadge(theme: theme),
            ),
          // Wave 131: prompt is tappable for replay. Wrapped in a
          // Semantics with a hint so screen readers announce the
          // tap target. Visual hint = subtle volume icon inline
          // when onReplayTts is wired.
          Semantics(
            label: question.prompt,
            hint: onReplayTts == null
                ? null
                : 'Tap to hear it again',
            button: onReplayTts != null,
            child: InkWell(
              onTap: onReplayTts,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        question.prompt,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    if (onReplayTts != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.volume_up_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          switch (question.kind) {
            SurveyQuestionKind.agree3 => Agree3Row(
                question: question,
                answers: answers,
                variant: variant,
                onAnswered: (next) => onAnswered(next, autoAdvance: true),
              ),
            SurveyQuestionKind.multiselect => MultiselectList(
                question: question,
                answers: answers,
                variant: variant,
                onAnswered: (next) => onAnswered(next, autoAdvance: false),
              ),
            SurveyQuestionKind.text => TextAnswer(
                question: question,
                answers: answers,
                onAnswered: (next) => onAnswered(next, autoAdvance: false),
              ),
          },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeBadge extends StatelessWidget {
  const _PracticeBadge({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'PRACTICE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onTertiaryContainer,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// N+1 page after the last question — celebration chibi + finish
/// button. Renders a warning copy if not every scored question is
/// answered (the kid can still finish; partial saves are fine).
class SurveyCloseoutPage extends StatelessWidget {
  const SurveyCloseoutPage({
    required this.template,
    required this.answeredScored,
    required this.scoredTotal,
    required this.saving,
    required this.onFinish,
    super.key,
  });

  final SurveyTemplate template;
  final int answeredScored;
  final int scoredTotal;
  final bool saving;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allAnswered = answeredScored == scoredTotal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ChibiSmiley(
              variant: ChibiVariant.circleGold,
              expression: ChibiExpression.excited,
              size: 160,
              selected: true,
            ),
            const SizedBox(height: 16),
            Text(
              allAnswered ? 'All done!' : "You're almost there!",
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              allAnswered
                  ? 'Great job. Tap Finish to save your answers.'
                  : 'Tap Back to fill in the $scoredTotal — $answeredScored '
                      "you haven't answered yet, or Finish to save what "
                      'you have.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onFinish,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wave 132: one option of a multiselect, rendered as a dedicated
/// yes/no page. The activities multiselect (7 options) explodes into
/// 7 of these pages. Visual rhythm: each page rotates through the 8
/// ChibiVariant looks so the kid doesn't see the same color/posture
/// 7 times in a row — what the user called "randomised" smileys.
///
/// Storage: the parent maintains the same `List<String>` of selected
/// option keys that the original MultiselectList uses, so existing
/// answers stay compatible.
class SurveyOptionYesNoPage extends StatelessWidget {
  const SurveyOptionYesNoPage({
    required this.questionIndex,
    required this.optionIndex,
    required this.question,
    required this.option,
    required this.isYes,
    required this.onPickYes,
    required this.onPickNo,
    this.onReplayTts,
    super.key,
  });

  /// Page index in the expanded PageView — drives variant rotation.
  final int questionIndex;

  /// Position within the parent question's options list. Currently
  /// unused for visual variation (questionIndex is the rotation
  /// driver) but kept on the widget for downstream tweaks.
  final int optionIndex;

  final SurveyQuestion question;
  final SurveyOption option;
  final bool isYes;
  final VoidCallback onPickYes;
  final VoidCallback onPickNo;
  final VoidCallback? onReplayTts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Variant rotates by page index across all 8 ChibiVariants. Two
    // adjacent options never look the same.
    final variant = ChibiVariant.forQuestionIndex(questionIndex);
    // Wave 133: same full-bleed treatment as SurveyQuestionPage.
    return LayoutBuilder(
      builder: (ctx, c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Smaller question prompt sits as a subtitle at the top so
          // the kid remembers which prompt they're answering yes/no
          // to (the activities multiselect's parent prompt is
          // "Check any of the activities you did this year").
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // The option label is the main text of the page — tappable
          // to replay the TTS.
          Semantics(
            label: option.label,
            hint: onReplayTts == null ? null : 'Tap to hear it again',
            button: onReplayTts != null,
            child: InkWell(
              onTap: onReplayTts,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        option.label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    if (onReplayTts != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.volume_up_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Big yes / no smiley pair. Larger than the inline
          // _MultiOptionRow used to be — each option is its own
          // page now so we can give the choice the visual presence
          // of a single agree3 question.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BigYesNoButton(
                label: 'No',
                variant: variant,
                expression: ChibiExpression.sad,
                selected: !isYes,
                onTap: onPickNo,
              ),
              _BigYesNoButton(
                label: 'Yes',
                variant: variant,
                expression: ChibiExpression.happy,
                selected: isYes,
                onTap: onPickYes,
              ),
            ],
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigYesNoButton extends StatelessWidget {
  const _BigYesNoButton({
    required this.label,
    required this.variant,
    required this.expression,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ChibiVariant variant;
  final ChibiExpression expression;
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
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChibiSmiley(
                variant: variant,
                expression: expression,
                selected: selected,
                size: 128,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wave 135: identity-capture page. Shown right after the kid picks a
/// voice (and before question 1) when any of `ageBand` / `grade` /
/// `school` is missing on the response row. Each dimension renders
/// as a row of chips populated from the per-program
/// `survey_picker_options` catalog, with a trailing "+" button that
/// adds a new label inline. The added label persists for the
/// program: the next kid who reaches this page sees it as a
/// pre-existing chip.
///
/// The whole page locks the "Continue" button until all three
/// dimensions are picked. Tap a chip → it's selected; tap a
/// different chip → selection swaps. No deselect.
class IdentityCapturePage extends StatelessWidget {
  const IdentityCapturePage({
    required this.ageBand,
    required this.grade,
    required this.school,
    required this.ageBandOptions,
    required this.gradeOptions,
    required this.schoolOptions,
    required this.onPick,
    required this.onAddOption,
    required this.onContinue,
    super.key,
  });

  final String? ageBand;
  final String? grade;
  final String? school;

  /// One list per dimension. Empty on first survey-take in a program.
  final List<String> ageBandOptions;
  final List<String> gradeOptions;
  final List<String> schoolOptions;

  /// `dimension` is 'age_band' / 'grade' / 'school'; `label` is the
  /// chosen label. Called when a chip is tapped.
  final void Function(String dimension, String label) onPick;

  /// Called when "+" is tapped and the user submits a new label.
  final Future<void> Function(String dimension, String label) onAddOption;

  /// Continue to question 1. Disabled until all three are picked.
  final VoidCallback onContinue;

  bool get _ready =>
      (ageBand?.isNotEmpty ?? false) &&
      (grade?.isNotEmpty ?? false) &&
      (school?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'A few things about you',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'These help us see patterns across kids without using '
              'names. Pick one for each.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _DimensionPicker(
              label: 'Age band',
              dimension: 'age_band',
              options: ageBandOptions,
              selected: ageBand,
              onPick: (l) => onPick('age_band', l),
              onAdd: (l) => onAddOption('age_band', l),
              addHint: 'e.g. 7-9',
            ),
            const SizedBox(height: 20),
            _DimensionPicker(
              label: 'Grade',
              dimension: 'grade',
              options: gradeOptions,
              selected: grade,
              onPick: (l) => onPick('grade', l),
              onAdd: (l) => onAddOption('grade', l),
              addHint: 'e.g. 2nd',
            ),
            const SizedBox(height: 20),
            _DimensionPicker(
              label: 'School',
              dimension: 'school',
              options: schoolOptions,
              selected: school,
              onPick: (l) => onPick('school', l),
              onAdd: (l) => onAddOption('school', l),
              addHint: 'e.g. Lincoln Elementary',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _ready ? onContinue : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(_ready ? 'Start the survey' : 'Pick one for each'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionPicker extends StatelessWidget {
  const _DimensionPicker({
    required this.label,
    required this.dimension,
    required this.options,
    required this.selected,
    required this.onPick,
    required this.onAdd,
    required this.addHint,
  });

  final String label;
  final String dimension;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onPick;
  final Future<void> Function(String label) onAdd;
  final String addHint;

  Future<void> _promptAdd(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: addHint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await onAdd(value);
    // Auto-select the newly added option so the kid doesn't have to
    // tap it after adding.
    onPick(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              ChoiceChip(
                label: Text(opt),
                selected: selected == opt,
                onSelected: (_) => onPick(opt),
              ),
            // Trailing "+" chip. Tapping opens a dialog to type the
            // new label; submitting persists it + auto-picks it.
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: () => _promptAdd(context),
            ),
          ],
        ),
      ],
    );
  }
}
