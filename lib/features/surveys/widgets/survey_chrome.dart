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
    super.key,
  });

  final int questionIndex;
  final SurveyQuestion question;
  final SurveyAnswers answers;
  final void Function(SurveyAnswers next, {required bool autoAdvance})
      onAnswered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variant = ChibiVariant.forQuestionIndex(questionIndex);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (question.isPractice)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PracticeBadge(theme: theme),
            ),
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
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
