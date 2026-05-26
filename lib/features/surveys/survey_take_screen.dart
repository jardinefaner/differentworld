import 'dart:async';
import 'dart:math' as math;

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/features/surveys/widgets/survey_chrome.dart';
import 'package:differentworld/features/voice/aura_voices.dart';
import 'package:differentworld/features/voice/survey_tts_service.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/route_title.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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

  /// Wave 120: the kid's chosen TTS voice for this template. Null
  /// until the picker fires on first session (a stale-or-empty
  /// `voice_id` on the response row). Once set, the picker is
  /// skipped on subsequent sessions and audio auto-plays.
  String? _voiceId;

  /// Wave 130: TTS service held as a State field, not via a Riverpod
  /// autoDispose provider. The previous shape disposed the
  /// underlying AudioPlayer between every ref.read() because nothing
  /// `ref.watch`-ed it — kids picked a voice and heard nothing.
  /// Lifecycle: built in initState, disposed in dispose.
  late final SurveyTtsService _tts;

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

  /// Wave 132: each "page" in the PageView is one of these. For
  /// most question kinds (agree3 / text) there's exactly one page
  /// per question. For multiselect questions, we EXPLODE each
  /// option into its own page: the activities list of 7 options
  /// becomes 7 sub-pages, each a yes/no smiley pair. Same answer
  /// shape on disk (List&lt;String&gt; of selected option keys).
  List<_SurveyPage> get _pages {
    final t = _template;
    if (t == null) return const [];
    final out = <_SurveyPage>[];
    for (final q in t.questions) {
      if (q.kind == SurveyQuestionKind.multiselect) {
        for (var i = 0; i < q.options.length; i++) {
          out.add(_SurveyPage(question: q, optionIndex: i));
        }
      } else {
        out.add(_SurveyPage(question: q));
      }
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _page = PageController();
    // Wave 130: one TTS service for the lifetime of this screen.
    // Held here (not via autoDispose provider) so the underlying
    // AudioPlayer survives across ref.read() calls.
    _tts = SurveyTtsService();
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
      // Wave 106: pin the locked URL so the router redirect can
      // bounce any navigation away (e.g. web browser back) back to
      // this screen. `PopScope.canPop: false` only catches Flutter
      // Navigator pops, not `window.history.back()`.
      ref.read(kidModeLockedRouteProvider.notifier).pin(
            '/surveys/${widget.templateId}/take/${widget.subjectId}',
          );
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
    // Wave 106: clear the pinned route so the router redirect stops
    // bouncing future navigations.
    ref.read(kidModeLockedRouteProvider.notifier).pin(null);
    _staffTapReset?.cancel();
    _staffTapReset = null;
    _page.dispose();
    // Wave 130: tear down the AudioPlayer when the screen leaves.
    unawaited(_tts.dispose());
    super.dispose();
  }

  void _seed(SurveyResponse? row) {
    if (_seeded) return;
    _seeded = true;
    if (row != null) {
      _answers = SurveyAnswers.fromJson(row.answers);
      // Wave 120: restore the previously-picked voice. If null, the
      // picker overlay surfaces on first build; otherwise we go
      // straight into question 1 with audio.
      _voiceId = row.voiceId;
      // If the voice is already known, kick off TTS for question 0
      // as soon as the seed completes.
      if (_voiceId != null) {
        // Defer to post-frame so the build pipeline finishes before
        // we trigger the player.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_playQuestion(0));
        });
      }
    }
  }

  /// Wave 120 + 132: kick off TTS for page at `index`. The page
  /// might be a whole question (agree3 / text) or an exploded
  /// multiselect option — in the latter case, play the option
  /// label instead of the question prompt so the kid hears the
  /// specific yes/no being asked.
  Future<void> _playQuestion(int index) async {
    final t = _template;
    final voice = _voiceId;
    if (t == null || voice == null) return;
    final pages = _pages;
    if (index < 0 || index >= pages.length) return;
    final page = pages[index];
    final q = page.question;

    final String text;
    final String cacheSuffix;
    if (page.isOption) {
      final opt = q.options[page.optionIndex!];
      text = opt.label.trim();
      cacheSuffix = '${q.key}__${opt.key}';
    } else {
      text = q.prompt.trim();
      cacheSuffix = q.key;
    }
    if (text.isEmpty) return;
    final cacheKey = '${t.id}__$cacheSuffix'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');
    try {
      final path = await _tts.resolve(
        voiceId: voice,
        text: text,
        cacheKey: cacheKey,
      );
      if (!mounted) return;
      await _tts.play(path);
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[survey-tts] resolve/play failed: $e\n$st');
      }
    }
  }

  /// Wave 120: kid picked a voice on the first-question overlay.
  /// Stash on state, persist on the response row via _autosave, then
  /// auto-play question 0.
  Future<void> _onVoicePicked(String voiceId) async {
    if (!mounted) return;
    setState(() => _voiceId = voiceId);
    final t = _template;
    if (t != null) {
      await ref.read(surveyActionsProvider).save(
            templateId: t.id,
            subjectId: widget.subjectId,
            answers: _answers,
            complete: false,
            voiceId: voiceId,
          );
    }
    if (!mounted) return;
    await _playQuestion(0);
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
    // Wave 132: page count is over the EXPANDED page list (one entry
    // per multiselect option) not the raw question list.
    final pageCount = _pages.length + 1;
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
          // Wave 106: clear the router pin immediately so staff
          // navigating back via the browser back button (web) or
          // system back (native, after PopScope yields) doesn't get
          // bounced. Dispose will run shortly and is idempotent
          // (setting state to null when it's already null is fine).
          ref.read(kidModeLockedRouteProvider.notifier).pin(null);
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

    // Wave 132: page count is now derived from the expanded _pages
    // list (multiselect options inflate to N sub-pages each), not
    // the raw question count.
    final pages = _pages;
    final totalQuestions = pages.length;
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
    // Wave 113: dynamic tab title — "{Template} · {Kid}". When the
    // tab actually says what the kid is filling out, a director
    // QA'ing in multiple tabs can tell them apart.
    final routeTitle = subject == null
        ? t.title
        : '${t.title} · ${subject.firstName}';
    return RouteTitle(
      title: routeTitle,
      child: PopScope(
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
              // Wave 120: if the kid hasn't picked a voice yet for
              // this template, show the picker INSTEAD of the
              // PageView. They tap one of five voices, audio
              // starts auto-playing, picker dismisses, and they
              // proceed to question 1. Already-picked rows skip
              // straight to questions.
              child: _voiceId == null
                  ? _VoicePickerOverlay(
                      onPicked: _onVoicePicked,
                      ttsService: _tts,
                    )
                  : PageView.builder(
                controller: _page,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  // Wave 120: auto-play TTS for the new question.
                  // Closeout page (i == totalQuestions) has no audio.
                  if (i < totalQuestions) unawaited(_playQuestion(i));
                },
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
                  // Wave 132: dispatch on page kind. A page can be:
                  //   - a whole question (agree3 / text) — old behavior
                  //   - one option of a multiselect (yes/no smiley)
                  final page = pages[i];
                  final q = page.question;
                  final onReplay = _voiceId == null
                      ? null
                      : () => unawaited(_playQuestion(i));
                  void afterAnswer({required bool autoAdvance}) {
                    unawaited(_autosave());
                    if (autoAdvance) {
                      // Give the tap-feedback a beat (~450ms) before
                      // the page slides, so the kid sees their pick
                      // register before the swap.
                      Future.delayed(
                        const Duration(milliseconds: 450),
                        () {
                          if (mounted) _advanceFrom(i);
                        },
                      );
                    }
                  }

                  if (page.isOption) {
                    final opt = q.options[page.optionIndex!];
                    return SurveyOptionYesNoPage(
                      questionIndex: i,
                      optionIndex: page.optionIndex!,
                      question: q,
                      option: opt,
                      isYes: _answers
                          .multiselect(q.key)
                          .contains(opt.key),
                      onReplayTts: onReplay,
                      onPickYes: () {
                        final picked =
                            _answers.multiselect(q.key).toSet()..add(opt.key);
                        final updated =
                            SurveyAnswers.fromJson(_answers.toJson())
                              ..setMultiselect(q.key, picked.toList());
                        setState(() => _answers = updated);
                        afterAnswer(autoAdvance: true);
                      },
                      onPickNo: () {
                        final picked =
                            _answers.multiselect(q.key).toSet()
                              ..remove(opt.key);
                        final updated =
                            SurveyAnswers.fromJson(_answers.toJson())
                              ..setMultiselect(q.key, picked.toList());
                        setState(() => _answers = updated);
                        afterAnswer(autoAdvance: true);
                      },
                    );
                  }
                  return SurveyQuestionPage(
                    questionIndex: i,
                    question: q,
                    answers: _answers,
                    onReplayTts: onReplay,
                    onAnswered: (next, {required autoAdvance}) {
                      setState(() => _answers = next);
                      afterAnswer(autoAdvance: autoAdvance);
                    },
                  );
                },
              ),
            ),
            // Close the ternary above (PageView branch).
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
  ),
  );
  }
}

/// Wave 120: the 5-voice picker that fires on the first question of a
/// kid's first session for a given template. Kid taps a voice tile to
/// hear a 1-sentence sample (the voice introduces itself by name);
/// when they tap "Pick" the voice locks in and the picker dismisses.
///
/// The tile they last tapped is preview-played; tapping a different
/// tile cuts the previous preview and plays the new one. Only the
/// final tap-then-confirm choice is persisted to the response row.
class _VoicePickerOverlay extends StatefulWidget {
  const _VoicePickerOverlay({
    required this.onPicked,
    required this.ttsService,
  });

  /// Called with the chosen Deepgram voice id after the kid confirms.
  final Future<void> Function(String voiceId) onPicked;

  /// Reused TTS service so the sample audio benefits from the same
  /// cache the survey questions use — once a voice samples once
  /// anywhere in the world, the next kid to preview it gets the
  /// cached sample with no Deepgram call.
  final SurveyTtsService ttsService;

  @override
  State<_VoicePickerOverlay> createState() => _VoicePickerOverlayState();
}

class _VoicePickerOverlayState extends State<_VoicePickerOverlay> {
  String? _previewing;

  /// Stable cache key for each voice's sample line — same key per voice
  /// so every kid in the program shares one MP3 per voice. (5 voices
  /// × 1 sample = 5 cached files for the whole platform.)
  String _sampleKeyFor(AuraVoice v) => 'sample_${v.id}';

  String _sampleTextFor(AuraVoice v) =>
      "Hi! I'm ${v.displayName}. I can read the questions to you "
      'if you tap me.';

  Future<void> _preview(AuraVoice v) async {
    setState(() => _previewing = v.id);
    try {
      final path = await widget.ttsService.resolve(
        voiceId: v.id,
        text: _sampleTextFor(v),
        cacheKey: _sampleKeyFor(v),
      );
      if (!mounted) return;
      await widget.ttsService.play(path);
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[voice-picker] preview failed: $e\n$st');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wave 128: SafeArea wraps the picker so the title doesn't bump
    // into the system status bar on Pixel / iPhone notch / Android
    // gesture inset. Kid-mode strips the omnibox bar but the system
    // status bar still draws on top of the body — without SafeArea,
    // "Pick a reader" overlapped clock + battery + wifi icons.
    return SafeArea(
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Text(
            'Pick a reader',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap to hear them say hi. Then pick the one you like.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: kAuraCast.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final v = kAuraCast[i];
                final selected = _previewing == v.id;
                return Material(
                  color: selected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _preview(v),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondaryContainer,
                            child: Icon(
                              v.gender == 'F'
                                  ? Icons.face_3_outlined
                                  : v.gender == 'M'
                                      ? Icons.face_outlined
                                      : Icons.face_6_outlined,
                              color: selected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Wave 128: cap to one line each so
                                // "Andromeda" / "warm and reassuring"
                                // don't split into two lines on narrow
                                // phones (where they read as a fragmented
                                // mess). The Expanded above gives them
                                // the column width they need.
                                Text(
                                  v.displayName,
                                  style: theme.textTheme.titleLarge,
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
                            selected
                                ? Icons.volume_up
                                : Icons.play_circle_outline,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _previewing == null
                  ? null
                  : () async {
                      final picked = _previewing!;
                      await widget.ttsService.stop();
                      await widget.onPicked(picked);
                    },
              icon: const Icon(Icons.check),
              label: Text(
                _previewing == null
                    ? 'Tap a reader to hear them'
                    : 'Pick ${auraVoiceById(_previewing)?.displayName ?? "this one"}',
              ),
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


/// Wave 132: one PageView page. Most are a whole question; for
/// multiselect questions, each option is its own page so the kid
/// makes one yes/no decision at a time instead of scanning a
/// 7-row checklist.
class _SurveyPage {
  const _SurveyPage({required this.question, this.optionIndex});

  final SurveyQuestion question;

  /// Null for non-multiselect (the whole question is the page).
  /// Non-null for an exploded multiselect option — that option's
  /// label is the page's main text.
  final int? optionIndex;

  bool get isOption => optionIndex != null;
}
