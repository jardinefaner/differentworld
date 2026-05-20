import 'dart:async';
import 'dart:math' as math;

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/features/surveys/widgets/chibi_smiley.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/progress_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/surveys/:templateId/take/:subjectId`
///
/// One-question-at-a-time runner. Tap a chibi → auto-advance to the
/// next question after a quick squash + particle burst feedback.
/// Multiselect / text questions don't auto-advance — they use the
/// explicit Next button so a kid can change their picks before
/// committing. Back button always lets the user revisit any earlier
/// answer (autosave keeps everything synced).
class SurveyTakeScreen extends ConsumerStatefulWidget {
  const SurveyTakeScreen({
    required this.templateId,
    required this.subjectId,
    super.key,
  });

  final String templateId;
  final String subjectId;

  @override
  ConsumerState<SurveyTakeScreen> createState() => _SurveyTakeScreenState();
}

class _SurveyTakeScreenState extends ConsumerState<SurveyTakeScreen>
    with WidgetsBindingObserver {
  late final PageController _page;
  SurveyAnswers _answers = SurveyAnswers();
  int _index = 0;
  bool _seeded = false;
  bool _saving = false;
  String? _error;

  /// Set true after the staff exit gesture completes; lets the next
  /// pop go through. Re-arms (back to false) whenever kid mode is
  /// still locked, so the user re-does the gesture to leave again.
  bool _staffUnlocked = false;

  /// Rolling tap-count for the hidden staff-exit gesture (5 fast
  /// taps in the top-right corner of the screen). Resets after
  /// `_staffTapWindow` of silence so a kid randomly tapping can't
  /// accidentally unlock.
  int _staffTapCount = 0;
  Timer? _staffTapReset;
  static const _staffTapTarget = 5;
  static const _staffTapWindow = Duration(milliseconds: 1500);

  SurveyTemplate? get _template => SurveyTemplates.byId(widget.templateId);

  @override
  void initState() {
    super.initState();
    _page = PageController();
    // Watch app lifecycle so we can RE-engage kid mode if the user
    // backgrounded the app — defends against the OS resurrecting
    // the Activity without rebuilding the widget tree, in which
    // case `initState` doesn't fire again on resume.
    WidgetsBinding.instance.addObserver(this);
    // Lock the device into kid mode for the duration of this screen.
    // AppShell strips its omnibox bar + body padding + top chrome
    // so the kid sees only the survey surface and can't drift into
    // staff-facing routes via the composer.
    //
    // Defer through a microtask, not addPostFrameCallback: initState
    // runs during the parent route's build phase and AppShell
    // watches kidModeProvider, so a sync write trips Riverpod's
    // "modified during build" assertion.
    unawaited(Future.microtask(() {
      if (!mounted) return;
      ref.read(kidModeProvider.notifier).enter();
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-engage kid mode on resume. The persisted SharedPreferences
    // value typically restores it, but on devices where the
    // notifier rebuilt before persistence loaded, this is the
    // belt + suspenders. Also resets `_staffUnlocked` so an
    // unlocked-but-not-exited surface re-locks if backgrounded —
    // staff has to redo the gesture after coming back.
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(kidModeProvider.notifier).enter();
      if (_staffUnlocked) {
        setState(() => _staffUnlocked = false);
      }
    }
  }

  @override
  void dispose() {
    // Drop the lock when the screen pops. The PopScope below
    // intercepts system-back while still in kid mode, so this only
    // runs after the staff has unlocked (or after a programmatic
    // pop from completion).
    WidgetsBinding.instance.removeObserver(this);
    ref.read(kidModeProvider.notifier).exit();
    _staffTapReset?.cancel();
    _staffTapReset = null;
    _page.dispose();
    super.dispose();
  }

  void _seed(SurveyResponse? row) {
    if (_seeded) return;
    _seeded = true;
    if (row != null) {
      _answers = SurveyAnswers.fromJson(row.answers);
    }
  }

  Future<void> _autosave() async {
    final t = _template;
    if (t == null) return;
    try {
      await ref.read(surveyActionsProvider).save(
            templateId: t.id,
            subjectId: widget.subjectId,
            answers: _answers,
            complete: false,
          );
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'surveys'),
      );
    }
  }

  Future<void> _submit() async {
    final t = _template;
    if (t == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(surveyActionsProvider).save(
            templateId: t.id,
            subjectId: widget.subjectId,
            answers: _answers,
            complete: true,
          );
      if (!mounted) return;
      context.pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'surveys'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Auto-advance: scoot to the next page (or to the closeout page
  /// if we're on the last question). Called from the answer
  /// handlers after the visual feedback window.
  void _advanceFrom(int from) {
    final t = _template;
    if (t == null) return;
    final pageCount = t.questions.length + 1;
    if (from + 1 >= pageCount) return;
    unawaited(_page.animateToPage(
      from + 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    ));
  }

  /// Five quick taps on the hidden top-right corner unlocks kid
  /// mode so a teacher can navigate away. Window resets after 1.5 s
  /// of silence so a kid tapping randomly can't accumulate.
  void _onStaffCornerTap() {
    _staffTapCount += 1;
    _staffTapReset?.cancel();
    if (_staffTapCount >= _staffTapTarget) {
      _staffTapCount = 0;
      _staffTapReset = null;
      setState(() => _staffUnlocked = true);
      // Confirmation so the staff knows the gesture took.
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Unlocked. Press back to exit.'),
        ),
      );
      return;
    }
    _staffTapReset = Timer(_staffTapWindow, () {
      _staffTapCount = 0;
      _staffTapReset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _template;
    if (t == null) {
      return const EdgeScaffold(
        body: Center(child: Text('Survey not found.')),
      );
    }
    ref
        .watch(
          surveyResponseProvider(
            (templateId: widget.templateId, subjectId: widget.subjectId),
          ),
        )
        .whenData(_seed);

    final subjectAsync = ref.watch(subjectByIdProvider(widget.subjectId));
    final subject = subjectAsync.value;

    final totalQuestions = t.questions.length;
    // PageView holds N question pages + 1 closeout page at the end.
    final pageCount = totalQuestions + 1;
    final answeredScored =
        t.scored.where((q) => _answers.isAnswered(q)).length;
    final atCloseout = _index >= totalQuestions;

    // Kid-mode hardening: while locked, refuse the system back
    // gesture. The hidden top-right tap target (5 fast taps in the
    // corner) is the staff-only unlock — once tapped, the next pop
    // goes through normally.
    final inKidMode = ref.watch(kidModeProvider);
    final blockPop = inKidMode && !_staffUnlocked;
    return PopScope(
      canPop: !blockPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // A kid tried to leave. Show a discrete hint so staff who
        // are watching see what's expected; the kid sees a generic
        // copy that doesn't reveal the gesture.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Hand the device back to a teacher to exit.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: DismissGuard(
      isDirty: () => !_seeded || _answers.toJson() != '{}',
      child: EdgeScaffold(
        body: Stack(
          children: [
            // The hidden staff-corner: 48 dp invisible tap target in
            // the very top-right. Five fast taps unlocks (see
            // `_onStaffCornerTap`). Behind everything else so the
            // survey UI's own widgets keep their normal hit areas;
            // the corner only catches taps in the deadzone above
            // the top-right of the first question's chibi grid.
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onStaffCornerTap,
                child: const SizedBox(width: 48, height: 48),
              ),
            ),
            Positioned.fill(
              child: Column(
          children: [
            const SizedBox(height: 56),
            _SurveyHeader(
              template: t,
              subject: subject,
              progressIndex: math.min(_index + 1, totalQuestions),
              progressTotal: totalQuestions,
              answeredScored: answeredScored,
              scoredTotal: t.scored.length,
              atCloseout: atCloseout,
              saving: _saving,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView.builder(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: pageCount,
                itemBuilder: (_, i) {
                  if (i == totalQuestions) {
                    return _CloseoutPage(
                      template: t,
                      answeredScored: answeredScored,
                      scoredTotal: t.scored.length,
                      saving: _saving,
                      onFinish: _saving ? null : _submit,
                    );
                  }
                  final q = t.questions[i];
                  return _QuestionPage(
                    questionIndex: i,
                    question: q,
                    answers: _answers,
                    onAnswered: (next, {required autoAdvance}) {
                      setState(() => _answers = next);
                      unawaited(_autosave());
                      if (autoAdvance) {
                        // Give the chibi tap-animation a beat (~450ms)
                        // before the page slides, so the kid sees
                        // their answer register before the swap.
                        Future.delayed(
                          const Duration(milliseconds: 450),
                          () {
                            if (mounted) _advanceFrom(i);
                          },
                        );
                      }
                    },
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _index == 0
                          ? null
                          : () {
                              unawaited(HapticFeedback.selectionClick());
                              unawaited(_page.previousPage(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOut,
                              ));
                            },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    // Forward affordance ONLY appears for kinds that
                    // don't auto-advance (multiselect / text) and on
                    // the question pages — closeout has its own
                    // Finish button inside the page body.
                    if (!atCloseout) _ForwardButton(
                      question: t.questions[_index],
                      atCloseout: false,
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        _advanceFrom(_index);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _ForwardButton extends StatelessWidget {
  const _ForwardButton({
    required this.question,
    required this.atCloseout,
    required this.onTap,
  });

  final SurveyQuestion question;
  final bool atCloseout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (atCloseout) return const SizedBox.shrink();
    // agree3 auto-advances on tap; the explicit Next button on those
    // pages is dead weight + invites double-press.
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

class _SurveyHeader extends StatefulWidget {
  const _SurveyHeader({
    required this.template,
    required this.subject,
    required this.progressIndex,
    required this.progressTotal,
    required this.answeredScored,
    required this.scoredTotal,
    required this.atCloseout,
    required this.saving,
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
  State<_SurveyHeader> createState() => _SurveyHeaderState();
}

class _SurveyHeaderState extends State<_SurveyHeader> {
  bool _pulseCloud = false;

  @override
  void didUpdateWidget(covariant _SurveyHeader old) {
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

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.questionIndex,
    required this.question,
    required this.answers,
    required this.onAnswered,
  });

  final int questionIndex;
  final SurveyQuestion question;
  final SurveyAnswers answers;
  final void Function(SurveyAnswers next, {required bool autoAdvance}) onAnswered;

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
            SurveyQuestionKind.agree3 => _Agree3Row(
                question: question,
                answers: answers,
                variant: variant,
                onAnswered: (next) =>
                    onAnswered(next, autoAdvance: true),
              ),
            SurveyQuestionKind.multiselect => _MultiselectList(
                question: question,
                answers: answers,
                variant: variant,
                onAnswered: (next) =>
                    onAnswered(next, autoAdvance: false),
              ),
            SurveyQuestionKind.text => _TextAnswer(
                question: question,
                answers: answers,
                onAnswered: (next) =>
                    onAnswered(next, autoAdvance: false),
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

// ---------------------------------------------------------------------------
// agree3 row — three chibis, one shape+color, three expressions.
// Tap one → squash, particle burst, color modulation, auto-advance.
// ---------------------------------------------------------------------------

class _Agree3Row extends StatefulWidget {
  const _Agree3Row({
    required this.question,
    required this.answers,
    required this.variant,
    required this.onAnswered,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;
  final ChibiVariant variant;
  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  State<_Agree3Row> createState() => _Agree3RowState();
}

class _Agree3RowState extends State<_Agree3Row> {
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
              _SmileyChoice(
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

class _SmileyChoice extends StatelessWidget {
  const _SmileyChoice({
    required this.variant,
    required this.expression,
    required this.label,
    required this.size,
    required this.selected,
    required this.dimmed,
    required this.tapping,
    required this.onTap,
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
              // Particle burst rendered on top of the chibi via a
              // Stack so a re-tap can fire a fresh burst without
              // re-laying out the chibi underneath.
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
                      _SelectionBurst(
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
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
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
class _SelectionBurst extends StatefulWidget {
  const _SelectionBurst({required this.size, super.key});
  final double size;

  @override
  State<_SelectionBurst> createState() => _SelectionBurstState();
}

class _SelectionBurstState extends State<_SelectionBurst>
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
          size: Size.square(widget.size),
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
    // Eight particles, spaced 45° apart. Each particle is a small
    // circle that scoots outward + fades + shrinks.
    for (var i = 0; i < 8; i++) {
      final angle = i * (math.pi / 4);
      // Eased outward distance.
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

// ---------------------------------------------------------------------------
// Multiselect — one row per option, each row has Yes / No chibis.
// No auto-advance; kid hits Next at the bottom when ready.
// ---------------------------------------------------------------------------

class _MultiselectList extends StatelessWidget {
  const _MultiselectList({
    required this.question,
    required this.answers,
    required this.variant,
    required this.onAnswered,
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

// ---------------------------------------------------------------------------
// Text question — debounced autosave, no auto-advance, Next at bottom.
// ---------------------------------------------------------------------------

class _TextAnswer extends StatefulWidget {
  const _TextAnswer({
    required this.question,
    required this.answers,
    required this.onAnswered,
  });

  final SurveyQuestion question;
  final SurveyAnswers answers;
  final ValueChanged<SurveyAnswers> onAnswered;

  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
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

// ---------------------------------------------------------------------------
// Closeout — N+1 page after the last question.
// ---------------------------------------------------------------------------

class _CloseoutPage extends StatelessWidget {
  const _CloseoutPage({
    required this.template,
    required this.answeredScored,
    required this.scoredTotal,
    required this.saving,
    required this.onFinish,
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
            // Last page gets the excited variant — the celebration
            // smiley, not tied to any question's variant rotation.
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
