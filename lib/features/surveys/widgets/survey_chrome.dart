import 'package:differentworld/features/surveys/survey_strings.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/features/surveys/widgets/chibi_smiley.dart';
import 'package:differentworld/features/surveys/widgets/survey_inputs.dart';
import 'package:differentworld/features/voice/aura_voices.dart';
import 'package:differentworld/features/voice/survey_tts_service.dart';
import 'package:differentworld/shared/widgets/progress_dots.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

/// Bottom-bar Next button. Hidden during agree3 (auto-advance handles
/// that) and at the closeout page.
///
/// Wave 149: takes a language so the label localises, and accepts a
/// nullable `onTap` so the parent can disable it until the current
/// question's answer is recorded (required-question gate). Disabled
/// state styling comes from FilledButton automatically.
class SurveyForwardButton extends StatelessWidget {
  const SurveyForwardButton({
    required this.question,
    required this.atCloseout,
    required this.onTap,
    required this.language,
    super.key,
  });

  final SurveyQuestion question;
  final bool atCloseout;
  final VoidCallback? onTap;
  final SurveyLanguage language;

  @override
  Widget build(BuildContext context) {
    if (atCloseout) return const SizedBox.shrink();
    if (question.kind == SurveyQuestionKind.agree3) {
      return const SizedBox.shrink();
    }
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_forward),
      label: Text(SurveyStrings.of(language).next),
    );
  }
}

/// Top-of-screen header for the survey-take flow.
///
/// Wave 138: no kid avatar / name — surveys are anonymous. Header
/// shows template title + progress + saving indicator. Progress dots
/// only render once the kid has started (progressTotal > 0).
class SurveyHeader extends StatefulWidget {
  const SurveyHeader({
    required this.template,
    required this.progressIndex,
    required this.progressTotal,
    required this.answeredScored,
    required this.scoredTotal,
    required this.atCloseout,
    required this.saving,
    super.key,
  });

  final SurveyTemplate template;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.template.title,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      widget.template.year,
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
              // Wave 146: replaced the `answeredScored / scoredTotal`
              // fraction with a page counter. The old fraction was
              // computed pre-Wave 132 (before the activities
              // multiselect exploded into 7 yes/no pages), so it
              // read e.g. "3 / 14" while the dot strip showed 5 of
              // 21 dots filled — two different denominators on the
              // same screen. Now the fraction matches the dot count:
              // both are PAGES.
              if (widget.progressTotal > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '${widget.progressIndex} / ${widget.progressTotal}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          if (widget.progressTotal > 0) ...[
            const SizedBox(height: 10),
            ProgressDots(
              count: widget.progressTotal,
              current: widget.atCloseout
                  ? widget.progressTotal - 1
                  : widget.progressIndex - 1,
            ),
          ],
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
    required this.language,
    this.onReplayTts,
    super.key,
  });

  final int questionIndex;
  final SurveyQuestion question;
  final SurveyAnswers answers;
  final void Function(SurveyAnswers next, {required bool autoAdvance})
  onAnswered;

  /// Wave 149: which translation to render. Drives both the prompt
  /// text on screen and the strings inside the input widgets (e.g.
  /// the "Tap to hear it again" semantics hint).
  final SurveyLanguage language;

  /// Wave 131: tapping the prompt text replays the TTS audio. Wired by
  /// survey_take_screen to call `_playQuestion(_index)`. Optional —
  /// when null (older callers / preview contexts), the prompt is a
  /// plain Text with no tap behavior.
  final VoidCallback? onReplayTts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variant = ChibiVariant.forQuestionIndex(questionIndex);
    final strings = SurveyStrings.of(language);
    final promptText = question.promptFor(language);
    // Wave 149: SingleChildScrollView wrapper handles 200 % text
    // scale / small-phone viewports gracefully — content above the
    // viewport limit becomes scrollable instead of overflowing. The
    // inner ConstrainedBox(minHeight) keeps mainAxisAlignment.center
    // working when the content IS shorter than the viewport.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (question.isPractice)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PracticeBadge(
                            theme: theme,
                            label: strings.practiceBadge,
                          ),
                        ),
                      // Wave 131: prompt is tappable for replay. Wrapped in a
                      // Semantics with a hint so screen readers announce the
                      // tap target. Visual hint = subtle volume icon inline
                      // when onReplayTts is wired.
                      Semantics(
                        label: promptText,
                        hint: onReplayTts == null
                            ? null
                            : strings.tapToHearAgain,
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
                                    promptText,
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
                          onAnswered: (next) =>
                              onAnswered(next, autoAdvance: true),
                        ),
                        SurveyQuestionKind.agree5 => Scale5Row(
                          question: question,
                          answers: answers,
                          labels: language == SurveyLanguage.es
                              ? Scale5Sets.agreeLabelsEs
                              : Scale5Sets.agreeLabelsEn,
                          emoji: Scale5Sets.agreeEmoji,
                          onAnswered: (next) =>
                              onAnswered(next, autoAdvance: true),
                        ),
                        SurveyQuestionKind.likeMe5 => Scale5Row(
                          question: question,
                          answers: answers,
                          labels: language == SurveyLanguage.es
                              ? Scale5Sets.likeMeLabelsEs
                              : Scale5Sets.likeMeLabelsEn,
                          emoji: Scale5Sets.likeMeEmoji,
                          onAnswered: (next) =>
                              onAnswered(next, autoAdvance: true),
                        ),
                        SurveyQuestionKind.multiselect => MultiselectList(
                          question: question,
                          answers: answers,
                          variant: variant,
                          onAnswered: (next) =>
                              onAnswered(next, autoAdvance: false),
                        ),
                        SurveyQuestionKind.text => TextAnswer(
                          question: question,
                          answers: answers,
                          onAnswered: (next) =>
                              onAnswered(next, autoAdvance: false),
                        ),
                      },
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PracticeBadge extends StatelessWidget {
  const _PracticeBadge({required this.theme, required this.label});
  final ThemeData theme;
  final String label;

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
          label,
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
///
/// Wave 149: wrapped in a SingleChildScrollView so 200% text scale
/// or short phones don't overflow the page (was the "the end has
/// overflow on mobile" report); also language-aware.
class SurveyCloseoutPage extends StatelessWidget {
  const SurveyCloseoutPage({
    required this.template,
    required this.answeredScored,
    required this.scoredTotal,
    required this.saving,
    required this.onFinish,
    required this.language,
    super.key,
  });

  final SurveyTemplate template;
  final int answeredScored;
  final int scoredTotal;
  final bool saving;
  final VoidCallback? onFinish;
  final SurveyLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = SurveyStrings.of(language);
    final allAnswered = answeredScored == scoredTotal;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 64,
            ),
            child: Center(
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
                    allAnswered
                        ? strings.allDoneTitle
                        : strings.almostThereTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    allAnswered ? strings.allDoneBody : strings.almostThereBody,
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
                    label: Text(strings.finish),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    required this.language,
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

  /// Wave 149: which translation to render.
  final SurveyLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = SurveyStrings.of(language);
    final optionText = option.labelFor(language);
    // Variant rotates by page index across all 8 ChibiVariants. Two
    // adjacent options never look the same.
    final variant = ChibiVariant.forQuestionIndex(questionIndex);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Wave 145: parent prompt subtitle dropped. Option labels
                      // are now full "Did you...?" questions, so the parent
                      // "Check any of the activities you did this year" is
                      // redundant + confusing alongside a self-contained
                      // question. The option label IS the main prompt.
                      //
                      // The option label is the main text of the page — tappable
                      // to replay the TTS.
                      Semantics(
                        label: optionText,
                        hint: onReplayTts == null
                            ? null
                            : strings.tapToHearAgain,
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
                                    optionText,
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
                            label: language == SurveyLanguage.es ? 'No' : 'No',
                            variant: variant,
                            expression: ChibiExpression.sad,
                            selected: !isYes,
                            onTap: onPickNo,
                          ),
                          _BigYesNoButton(
                            label: language == SurveyLanguage.es ? 'Sí' : 'Yes',
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
          ),
        );
      },
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

/// Wave 138: combined "About you" page — the FIRST surface every
/// kid sees when they start a survey. Folds the Wave 120 voice
/// picker and the Wave 135 identity-capture chips into one
/// scrollable surface so the kid makes all the per-session
/// choices up front, then taps Start.
///
/// Sections, in order:
///   1. Voice reader (5 chibi voices; tap to preview the sample line)
///   2. Age band chips (with a "+" button to add a new label)
///   3. Grade chips (same)
///   4. School chips (same)
///   5. Start button (enabled only when all four are picked)
///
/// Each pick persists immediately via the parent's autosave; the
/// kid can re-tap any choice to change it before Start. After
/// Start the kid moves into the question PageView and the
/// About-you page never re-surfaces (no resume; the user starts
/// a fresh survey from the template detail screen if they want
/// to redo).
class AboutYouPage extends StatefulWidget {
  const AboutYouPage({
    required this.voiceId,
    required this.ageBand,
    required this.grade,
    required this.school,
    required this.ageBandOptions,
    required this.gradeOptions,
    required this.schoolOptions,
    required this.onPickVoice,
    required this.onPickIdentity,
    required this.onAddIdentityOption,
    required this.onStart,
    required this.ttsService,
    required this.language,
    required this.onPickLanguage,
    required this.volume,
    required this.onVolumeChanged,
    super.key,
  });

  final String? voiceId;
  final String? ageBand;
  final String? grade;
  final String? school;

  final List<String> ageBandOptions;
  final List<String> gradeOptions;
  final List<String> schoolOptions;

  /// Wave 149: current language for both UI strings and voice
  /// filtering, with the setter the toggle calls.
  final SurveyLanguage language;
  final ValueChanged<SurveyLanguage> onPickLanguage;

  /// Wave 149: TTS playback volume in [0, 1]. The slider's onChanged
  /// also feeds back into ttsService so an in-progress preview
  /// reflects the new volume immediately.
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  /// Called when a voice tile is tapped — the parent persists it
  /// onto the response row. The preview audio is played locally by
  /// this widget (so taps feel instant); only the final selection
  /// commits to the DB.
  final Future<void> Function(String voiceId) onPickVoice;

  /// `dimension` is 'age_band' / 'grade' / 'school'; `label` is the
  /// chosen label. Called when a chip is tapped.
  final Future<void> Function(String dimension, String label) onPickIdentity;

  /// Called when "+" is tapped and the user submits a new label.
  final Future<void> Function(String dimension, String label)
  onAddIdentityOption;

  /// Tapping Start. Null disables the button (when any of the four
  /// picks is still empty).
  final VoidCallback? onStart;

  /// Shared TTS service so voice samples piggyback on the same MP3
  /// cache the survey questions use — one sample per voice per
  /// program, ever.
  final SurveyTtsService ttsService;

  @override
  State<AboutYouPage> createState() => _AboutYouPageState();
}

class _AboutYouPageState extends State<AboutYouPage> {
  /// Voice currently being previewed (i.e. last tapped). Mirrors
  /// `widget.voiceId` once the parent's autosave round-trips back,
  /// but exists here so the tile shows the highlighted state
  /// immediately on tap (no wait for the autosave).
  String? get _previewing => widget.voiceId;

  String _sampleKeyFor(AuraVoice v) => 'sample_${v.id}';

  String _sampleTextFor(AuraVoice v) {
    if (v.language == 'es') {
      return '¡Hola! Soy ${v.displayName}. '
          'Puedo leerte las preguntas si me eliges.';
    }
    return "Hi! I'm ${v.displayName}. I can read the questions to you "
        'if you tap me.';
  }

  Future<void> _onVoiceTap(AuraVoice v) async {
    // Wave 142: wrap the FULL function body so anything thrown by
    // `onPickVoice` (parent autosave hitting a StateError, for one)
    // is captured here instead of escaping into the InkWell's
    // discarded onTap Future and becoming an uncaught web error.
    try {
      // Persist the pick first (parent updates state synchronously)
      // so the tile highlights instantly; then kick off the preview.
      await widget.onPickVoice(v.id);
      if (!mounted) return;
      final source = await widget.ttsService.resolve(
        voiceId: v.id,
        text: _sampleTextFor(v),
        cacheKey: _sampleKeyFor(v),
      );
      if (!mounted) return;
      await widget.ttsService.play(source);
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[about-you] voice preview failed: $e\n$st');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = SurveyStrings.of(widget.language);
    // Voice cast filtered to the chosen language. If the kid switches
    // EN→ES while a voice is already selected, the parent clears the
    // voiceId so the picker re-engages.
    final voices = auraVoicesForLanguage(widget.language.code);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.aboutYouTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  strings.aboutYouSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _SectionLabel(label: strings.language),
                const SizedBox(height: 8),
                _LanguageToggle(
                  selected: widget.language,
                  onPick: widget.onPickLanguage,
                ),
                const SizedBox(height: 20),
                _SectionLabel(label: strings.volume),
                const SizedBox(height: 4),
                _VolumeSlider(
                  value: widget.volume,
                  onChanged: widget.onVolumeChanged,
                ),
                const SizedBox(height: 12),
                _SectionLabel(label: strings.reader),
                const SizedBox(height: 8),
                _VoiceTilesGrid(
                  voices: voices,
                  previewing: _previewing,
                  onTap: _onVoiceTap,
                ),
                const SizedBox(height: 24),
                _DimensionPicker(
                  label: strings.ageBand,
                  dimension: 'age_band',
                  options: widget.ageBandOptions,
                  selected: widget.ageBand,
                  onPick: (l) => widget.onPickIdentity('age_band', l),
                  onAdd: (l) => widget.onAddIdentityOption('age_band', l),
                  addHint: widget.language == SurveyLanguage.es
                      ? 'p. ej. 7-9'
                      : 'e.g. 7-9',
                  defaults: const ['4-6', '7-9', '10-12'],
                ),
                const SizedBox(height: 20),
                _DimensionPicker(
                  label: strings.grade,
                  dimension: 'grade',
                  options: widget.gradeOptions,
                  selected: widget.grade,
                  onPick: (l) => widget.onPickIdentity('grade', l),
                  onAdd: (l) => widget.onAddIdentityOption('grade', l),
                  addHint: widget.language == SurveyLanguage.es
                      ? 'p. ej. 2°'
                      : 'e.g. 2nd',
                  // Wave 167: includes 6th for the BASECamp 4-6 survey
                  // path. The per-space picker promotes the user's
                  // first tap into a real saved option, so these are
                  // first-time defaults only.
                  defaults: const [
                    'TK',
                    'K',
                    '1st',
                    '2nd',
                    '3rd',
                    '4th',
                    '5th',
                    '6th',
                  ],
                ),
                const SizedBox(height: 20),
                _DimensionPicker(
                  label: strings.school,
                  dimension: 'school',
                  options: widget.schoolOptions,
                  selected: widget.school,
                  onPick: (l) => widget.onPickIdentity('school', l),
                  onAdd: (l) => widget.onAddIdentityOption('school', l),
                  addHint: widget.language == SurveyLanguage.es
                      ? 'p. ej. Escuela Lincoln'
                      : 'e.g. Lincoln Elementary',
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      widget.onStart == null
                          ? strings.startNeeds
                          : strings.startReady,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

/// Wave 149: EN / ES segmented toggle at the top of the About-you
/// page.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.selected, required this.onPick});
  final SurveyLanguage selected;
  final ValueChanged<SurveyLanguage> onPick;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SurveyLanguage>(
      segments: const [
        ButtonSegment(
          value: SurveyLanguage.en,
          label: Text('English'),
          icon: Icon(Icons.translate),
        ),
        ButtonSegment(
          value: SurveyLanguage.es,
          label: Text('Español'),
          icon: Icon(Icons.translate),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onPick(s.first),
    );
  }
}

/// Wave 149: volume slider with mute / max icons.
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = value <= 0.0;
    return Row(
      children: [
        Icon(
          muted ? Icons.volume_off_outlined : Icons.volume_down_outlined,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
          ),
        ),
        Icon(
          Icons.volume_up_outlined,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _VoiceTilesGrid extends StatelessWidget {
  const _VoiceTilesGrid({
    required this.voices,
    required this.previewing,
    required this.onTap,
  });

  /// Voices to render — already filtered to the chosen language.
  final List<AuraVoice> voices;
  final String? previewing;
  final Future<void> Function(AuraVoice voice) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final v in voices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: previewing == v.id
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(v),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: previewing == v.id
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondaryContainer,
                        child: Icon(
                          v.gender == 'F'
                              ? Icons.face_3_outlined
                              : v.gender == 'M'
                              ? Icons.face_outlined
                              : Icons.face_6_outlined,
                          color: previewing == v.id
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              v.displayName,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              v.personality,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        previewing == v.id
                            ? Icons.volume_up
                            : Icons.play_circle_outline,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
    this.defaults = const [],
  });

  final String label;
  final String dimension;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onPick;
  final Future<void> Function(String label) onAdd;
  final String addHint;

  /// Wave 139: starter labels rendered when the program hasn't added
  /// any options for this dimension yet (so the first kid taking a
  /// survey never sees an empty row + lone "+" chip). Tapping a
  /// default persists it to the program catalog AND selects it, so
  /// the next kid sees it as a known option (no longer a default).
  final List<String> defaults;

  Future<void> _promptAdd(BuildContext context) async {
    final controller = TextEditingController();
    try {
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
      if (value == null || value.isEmpty) return;
      await onAdd(value);
      // Auto-select the newly added option so the kid doesn't have to
      // tap it after adding.
      onPick(value);
    } on Object catch (e, st) {
      // Wave 142: same StateError-escapes-onTap risk as elsewhere.
      if (kDebugMode) {
        debugPrint('[dimension-picker] add failed: $e\n$st');
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Merge program options with defaults — but only defaults that
    // aren't already program options (otherwise the kid sees the same
    // label twice). Tapping a default goes through onAdd→onPick so it
    // graduates into the program catalog for the next kid.
    final knownLower = {for (final o in options) o.toLowerCase()};
    final displayDefaults = defaults
        .where((d) => !knownLower.contains(d.toLowerCase()))
        .toList(growable: false);
    final hasAny = options.isNotEmpty || displayDefaults.isNotEmpty;
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
            for (final opt in displayDefaults)
              ChoiceChip(
                label: Text(opt),
                selected: selected == opt,
                onSelected: (_) async {
                  // Wave 142: errors from `onAdd` (e.g. StateError on
                  // missing Space) would otherwise escape this async
                  // lambda — which the ChoiceChip's onSelected
                  // (`ValueChanged<bool>?`) silently discards — and
                  // surface as an uncaught web error.
                  try {
                    await onAdd(opt);
                    onPick(opt);
                  } on Object catch (e, st) {
                    if (kDebugMode) {
                      debugPrint(
                        '[dimension-picker] graduate default failed: $e\n$st',
                      );
                    }
                  }
                },
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
        if (!hasAny) ...[
          const SizedBox(height: 6),
          Text(
            'No options yet — tap Add to enter your first.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
