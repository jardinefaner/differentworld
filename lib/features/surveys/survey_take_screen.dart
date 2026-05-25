import 'dart:async';
import 'dart:math' as math;

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/features/surveys/widgets/survey_chrome.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
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

  /// Five quick taps on the hidden top-right corner BEGINS the
  /// exit dance. If a staff PIN is configured for this Space
  /// (`SpaceCaps.staffPin`), a PIN dialog opens; the wrong PIN
  /// keeps the lock. If no PIN is configured, the gesture itself
  /// unlocks (the previous behavior).
  ///
  /// Window resets after 1.5 s of silence so a kid tapping
  /// randomly can't accumulate.
  Future<void> _onStaffCornerTap() async {
    _staffTapCount += 1;
    _staffTapReset?.cancel();
    if (_staffTapCount >= _staffTapTarget) {
      _staffTapCount = 0;
      _staffTapReset = null;
      final result = await showKidModeExitDialog(context, ref);
      if (!mounted) return;
      switch (result) {
        case KidModeExitResult.unlocked:
        case KidModeExitResult.noPinConfigured:
          setState(() => _staffUnlocked = true);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Unlocked. Press back to exit.'),
            ),
          );
        case KidModeExitResult.cancelled:
          // Staff dismissed the dialog (or kid tapped wrong) —
          // the lock stays. Silent.
          break;
      }
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
        body: EmptyState(
          icon: Icons.quiz_outlined,
          title: 'Survey not found',
        ),
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
            // Survey-take is a KID-MODE surface — the shell drops its
            // chrome insets to 0, so the body fills from the top. A
            // small spacer keeps the header off the status bar.
            const SizedBox(height: 16),
            SurveyHeader(
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
                    return SurveyCloseoutPage(
                      template: t,
                      answeredScored: answeredScored,
                      scoredTotal: t.scored.length,
                      saving: _saving,
                      onFinish: _saving ? null : _submit,
                    );
                  }
                  final q = t.questions[i];
                  return SurveyQuestionPage(
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
                    if (!atCloseout) SurveyForwardButton(
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
