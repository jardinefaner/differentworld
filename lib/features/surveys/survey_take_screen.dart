import 'dart:async';
import 'dart:math' as math;

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/surveys/survey_prefs.dart';
import 'package:differentworld/features/surveys/survey_strings.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/features/surveys/widgets/survey_chrome.dart';
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

/// `/surveys/:templateId/take`
///
/// Wave 138: anonymous survey-take. The screen generates a fresh
/// response id in initState (no resume — each landing on this route
/// is a brand-new session) and threads it through every save. Page
/// 0 is a combined "About you" surface: pick a voice + age band +
/// grade + school, then tap Start to begin the questions. From
/// there it's one-question-at-a-time: tap a chibi → auto-advance
/// after a quick squash + particle burst. Multiselect / text
/// questions use the explicit Next button so a kid can change picks
/// before committing. Back button always lets the user revisit an
/// earlier answer (autosave keeps everything synced).
class SurveyTakeScreen extends ConsumerStatefulWidget {
  const SurveyTakeScreen({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  ConsumerState<SurveyTakeScreen> createState() => _SurveyTakeScreenState();
}

class _SurveyTakeScreenState extends ConsumerState<SurveyTakeScreen>
    with WidgetsBindingObserver {
  late final PageController _page;
  SurveyAnswers _answers = SurveyAnswers();
  int _index = 0;
  bool _saving = false;
  String? _error;

  /// Wave 138: the response id generated for THIS take session. Used
  /// as the upsert key for every autosave + the final submit. Fresh
  /// per route landing (no resume).
  late final String _responseId;

  /// The kid's chosen TTS voice for this template. Null until they
  /// pick on the About-you page. Voice is captured per-response now
  /// (Wave 138), not per-(subject, template), so a kid can pick
  /// differently each session.
  String? _voiceId;

  /// Wave 135/138: identity capture state. All three required before
  /// the kid taps Start. Lives only in memory until first autosave;
  /// every change persists to the response row.
  String? _ageBand;
  String? _grade;
  String? _school;
  bool get _identityComplete =>
      _voiceId != null &&
      (_ageBand?.isNotEmpty ?? false) &&
      (_grade?.isNotEmpty ?? false) &&
      (_school?.isNotEmpty ?? false);

  /// True once the kid taps "Start" on the About-you page. Until
  /// then, the PageView stays hidden and the About-you surface
  /// fills the body.
  bool _started = false;

  /// Wave 149: current survey language (EN / ES). Mirrors
  /// `surveyLanguageProvider` but pulled into a field so non-build
  /// methods (`_playQuestion`, autosave) can read it without doing
  /// a ref.read each time. The build method writes this from the
  /// AsyncValue; methods read `_language`.
  SurveyLanguage _language = SurveyLanguage.en;

  /// Wave 130: TTS service held as a State field, not via a Riverpod
  /// autoDispose provider. The previous shape disposed the
  /// underlying AudioPlayer between every ref.read() because nothing
  /// `ref.watch`-ed it — kids picked a voice and heard nothing.
  /// Lifecycle: built in initState, disposed in dispose.
  late final SurveyTtsService _tts;

  /// Wave 137: token for the latest _playQuestion invocation. The
  /// TTS service has its OWN token for `play()`, but that one
  /// guards AFTER resolve completes — meaning a slow first-time
  /// resolve (Supabase fetch) for page N can complete after a fast
  /// cache-hit resolve for page N+1, and the page N audio plays
  /// on top of N+1's. Tracking the latest invocation in
  /// survey-take lets us bail out BEFORE play() runs.
  int _playRequestId = 0;

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
  // Wave 139: tightened from 1500ms → 800ms between consecutive taps.
  // The window is *between taps* (each tap reschedules the reset
  // timer), so a kid randomly mashing the corner can no longer space
  // their taps out over ~7 seconds and accumulate 5. The full gesture
  // must complete in ~3.2 s with no pauses longer than 800 ms.
  static const _staffTapWindow = Duration(milliseconds: 800);

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
    // Wave 138: fresh response id for this session. The first
    // autosave (triggered by voice/identity picks) inserts the row
    // lazily; until then, nothing exists in the DB.
    _responseId = ref.read(surveyActionsProvider).freshResponseId();
    // Wave 130: one TTS service for the lifetime of this screen.
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
      // Wave 142: try/catch around the microtask body. If either
      // notifier ever throws, the surface-level unawaited Future
      // would bubble up to the web's top-level error handler with
      // no useful context. Catching here keeps survey-take usable
      // even if one of these wires is briefly unhealthy.
      try {
        ref.read(kidModeProvider.notifier).enter();
        // Wave 106: pin the locked URL so the router redirect can
        // bounce any navigation away (e.g. web browser back) back to
        // this screen. `PopScope.canPop: false` only catches Flutter
        // Navigator pops, not `window.history.back()`.
        ref
            .read(kidModeLockedRouteProvider.notifier)
            .pin('/surveys/${widget.templateId}/take');
      } on Object catch (e, st) {
        if (kDebugMode) {
          debugPrint('[survey-take] initState microtask failed: $e\n$st');
        }
      }
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(kidModeProvider.notifier).enter();
      if (_staffUnlocked) {
        setState(() => _staffUnlocked = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(kidModeProvider.notifier).exit();
    ref.read(kidModeLockedRouteProvider.notifier).pin(null);
    _staffTapReset?.cancel();
    _staffTapReset = null;
    _page.dispose();
    unawaited(_tts.dispose());
    super.dispose();
  }

  /// Wave 120 + 132 + 137 + 138: kick off TTS for page at `index`. The
  /// page might be a whole question (agree3 / text) or an exploded
  /// multiselect option — in the latter case, play the option label
  /// instead of the question prompt so the kid hears the specific
  /// yes/no being asked.
  ///
  /// Token-guarded against races. If a new _playQuestion fires while
  /// an older one's resolve() is still in flight, the older one
  /// bails out before it can stomp on the newer audio.
  Future<void> _playQuestion(int index) async {
    final t = _template;
    final voice = _voiceId;
    if (t == null || voice == null) return;
    final pages = _pages;
    if (index < 0 || index >= pages.length) return;
    final page = pages[index];
    final q = page.question;
    // Wave 149: choose the language-appropriate text for both the
    // spoken narration and the cache key. The content-hash tag
    // already separates EN vs ES audio under the same (template,
    // question) pair, but `__${lang.code}` makes the bucket layout
    // human-readable too.
    final lang = _language;

    final String text;
    final String cacheSuffix;
    if (page.isOption) {
      final opt = q.options[page.optionIndex!];
      text = opt.labelFor(lang).trim();
      cacheSuffix = '${q.key}__${opt.key}__${lang.code}';
    } else {
      text = q.promptFor(lang).trim();
      cacheSuffix = '${q.key}__${lang.code}';
    }
    if (text.isEmpty) return;
    // Wave 145: content fingerprint so a copy edit invalidates the
    // cached audio for that one option. Wave 149: the language code
    // is now baked into cacheSuffix too, so EN and ES audio for the
    // same question never collide.
    final tag = text.hashCode.toUnsigned(32).toRadixString(36);
    final cacheKey = '${t.id}__${cacheSuffix}__$tag'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');
    final myToken = ++_playRequestId;
    try {
      final source = await _tts.resolve(
        voiceId: voice,
        text: text,
        cacheKey: cacheKey,
      );
      if (!mounted || myToken != _playRequestId) return;
      await _tts.play(source);
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[survey-tts] resolve/play failed: $e\n$st');
      }
    }
  }

  /// Wave 138: voice tapped on the combined About-you page. Stash on
  /// state + autosave (also creates the response row on first call).
  Future<void> _onVoicePicked(String voiceId) async {
    if (!mounted) return;
    setState(() => _voiceId = voiceId);
    await _autosave();
  }

  /// Wave 135/138: a dimension chip was tapped on the About-you page.
  /// Stash on local state + persist on the response row.
  Future<void> _onIdentityPick(String dimension, String label) async {
    if (!mounted) return;
    setState(() {
      switch (dimension) {
        case 'age_band':
          _ageBand = label;
        case 'grade':
          _grade = label;
        case 'school':
          _school = label;
      }
    });
    await _autosave();
  }

  /// Wave 135: "+" button on the About-you page — add a new label
  /// to the per-program catalog. Returns once persisted; the
  /// caller auto-selects it.
  ///
  /// Wave 142: try/catch so a no-Space StateError (the same one that
  /// _autosave can hit) never escapes into the InkWell's discarded
  /// Future and lands as an uncaught web error.
  Future<void> _onIdentityAddOption(String dimension, String label) async {
    try {
      await ref
          .read(surveyActionsProvider)
          .addPickerOption(dimension: dimension, label: label);
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'surveys'),
      );
    }
  }

  /// Wave 149: language toggle on the About-you page. Switching
  /// language clears the current voiceId (the EN cast and the ES
  /// cast don't overlap), so the kid re-picks from the matching
  /// cast before Start re-enables.
  void _onPickLanguage(SurveyLanguage lang) {
    if (lang == _language) return;
    setState(() {
      _language = lang;
      _voiceId = null;
    });
    persistSurveyLanguage(ref, lang);
    unawaited(_autosave());
  }

  /// Wave 149: volume slider on the About-you page. Apply to the
  /// active player immediately + persist for the next session.
  void _onVolumeChanged(double v) {
    persistSurveyVolume(ref, v);
    unawaited(_tts.setVolume(v));
  }

  /// Wave 149: required-question gate. Returns true if the current
  /// page's question is answered (or is a practice — practices stay
  /// optional). Page index 0..totalQuestions-1; the closeout has
  /// its own logic.
  bool _canAdvanceFromCurrent(
      SurveyTemplate t, List<_SurveyPage> pages) {
    if (_index >= pages.length) return true; // closeout
    final page = pages[_index];
    final q = page.question;
    if (q.isPractice) return true;
    switch (q.kind) {
      case SurveyQuestionKind.agree3:
        // Agree3 auto-advances on tap; the bottom Next is hidden for
        // it anyway. Returning true means tap-Next stays harmless if
        // ever exposed.
        return _answers.agree3(q.key) != null;
      case SurveyQuestionKind.agree5:
      case SurveyQuestionKind.likeMe5:
        // 5-point scales auto-advance on tap, same as agree3.
        return _answers.scale5(q.key) != null;
      case SurveyQuestionKind.multiselect:
        // Each multiselect option page is its OWN yes/no choice. A
        // yes adds the option to the picks list; a no removes it.
        // We require an explicit tap (yes or no) on this option
        // before advancing — i.e. the kid must have answered THIS
        // option page, not just any option of the same question.
        // Since both yes and no are valid, the only signal is that
        // SOMETHING about this question has been touched. For the
        // FIRST option page of a multiselect, we accept ANY tap on
        // any option of the same question; for subsequent options
        // we require the same. Effectively: the answers blob has a
        // key for this question.
        return _answers.isAnswered(q);
      case SurveyQuestionKind.text:
        return _answers.text(q.key).trim().isNotEmpty;
    }
  }

  /// Wave 138: kid tapped Start on the About-you page. Flip into
  /// the PageView and auto-play question 0's audio.
  Future<void> _onStart() async {
    if (!mounted) return;
    if (!_identityComplete) return;
    setState(() => _started = true);
    await _playQuestion(0);
  }

  Future<void> _autosave() async {
    final t = _template;
    if (t == null) return;
    try {
      await ref.read(surveyActionsProvider).save(
            id: _responseId,
            templateId: t.id,
            answers: _answers,
            complete: false,
            voiceId: _voiceId,
            ageBand: _ageBand,
            grade: _grade,
            school: _school,
          );
    } on Object catch (e, st) {
      // Wave 142: catch Object, not Exception. SurveyActions.save
      // throws StateError when spaceId is null (no Space yet, race
      // during cold boot) — StateError is Error, not Exception, so
      // `on Exception` misses it. An uncaught Error from an onTap
      // lambda becomes a top-level uncaught web error.
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
            id: _responseId,
            templateId: t.id,
            answers: _answers,
            complete: true,
            voiceId: _voiceId,
            ageBand: _ageBand,
            grade: _grade,
            school: _school,
          );
      if (!mounted) return;
      // Wave 148: kill any in-flight audio BEFORE the pop animation
      // starts. Dispose runs after pop and disposes the player,
      // but on web that gap can be 200-300 ms of leftover voice
      // playing into the survey-list screen.
      unawaited(_tts.stop());
      // Wave 143: drop the kid-mode pin BEFORE popping. Otherwise
      // the router's redirect (which runs synchronously on the
      // pop's matchedLocation change) sees lockedRoute still =
      // `/surveys/X/take`, returns it, and bounces the user right
      // back into the survey. Dispose clears the pin too — but
      // dispose runs AFTER the redirect resolves the pop, so it's
      // too late.
      ref.read(kidModeLockedRouteProvider.notifier).pin(null);
      context.pop();
    } on Object catch (e, st) {
      // Wave 142: catch Object, not Exception. SurveyActions.save
      // throws StateError when spaceId is null (no Space yet, race
      // during cold boot) — StateError is Error, not Exception, so
      // `on Exception` misses it. An uncaught Error from an onTap
      // lambda becomes a top-level uncaught web error.
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
  /// unlocks.
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
          // Wave 148: cut any in-flight TTS the moment staff
          // unlocks. They're about to leave; the kid is no longer
          // listening; the voice should not keep narrating
          // questions on the way out.
          unawaited(_tts.stop());
          ref.read(kidModeLockedRouteProvider.notifier).pin(null);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Unlocked. Press back to exit.'),
            ),
          );
        case KidModeExitResult.cancelled:
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

    // Wave 132: page count is derived from the expanded _pages list.
    final pages = _pages;
    final totalQuestions = pages.length;
    // PageView holds N question pages + 1 closeout page at the end.
    final pageCount = totalQuestions + 1;
    final answeredScored =
        t.scored.where((q) => _answers.isAnswered(q)).length;
    final atCloseout = _index >= totalQuestions;

    // Kid-mode hardening: while locked, refuse the system back
    // gesture. The hidden top-right tap target is the staff unlock.
    final inKidMode = ref.watch(kidModeProvider);
    final blockPop = inKidMode && !_staffUnlocked;

    // Wave 149: sync the current language + volume out of their
    // providers into local state. `_language` is read by
    // non-build methods like `_playQuestion`; volume is forwarded to
    // the TTS service the moment it changes.
    final lang = ref.watch(surveyLanguageProvider).value
        ?? SurveyLanguage.en;
    if (lang != _language) _language = lang;
    final volume = ref.watch(surveyVolumeProvider).value ?? 1.0;
    // Push volume to the player whenever it changes (also covers
    // first build — initial player volume is 1.0 from the constructor,
    // but if persisted volume is lower we want it applied).
    unawaited(_tts.setVolume(volume));

    // Wave 149: the bottom Next is gated on the current page's
    // question being answered (required-question rule). Practice
    // questions stay optional. Agree3 auto-advances on tap, so this
    // really gates multiselect/text from being skipped blank.
    final canAdvance = _canAdvanceFromCurrent(t, pages);
    return RouteTitle(
      title: t.title,
      child: PopScope(
        canPop: !blockPop,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Hand the device back to a teacher to exit.'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: DismissGuard(
          isDirty: () => _answers.toJson() != '{}',
          child: EdgeScaffold(
            body: Stack(
              children: [
                // Hidden staff-corner: 48 dp invisible tap target.
                // Wave 143: moved from top-RIGHT to top-LEFT. The
                // top-right is where SurveyHeader renders the score
                // ("11 / 11"); a kid tapping the score five times
                // could accidentally unlock staff mode because the
                // GestureDetector was HitTestBehavior.translucent
                // (taps register here AND pass through to the
                // header). The top-left has no content overlap.
                Positioned(
                  top: 0,
                  left: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _onStaffCornerTap,
                    child: const SizedBox(width: 48, height: 48),
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    children: [
                      // Wave 143: real status-bar inset instead of
                      // a fixed 16 dp. On phones with notches /
                      // bigger status bars (Pixel 6: 24 dp; some
                      // Androids 32+ dp), the fixed 16 dp left
                      // the header drawing UNDER the status bar.
                      // EdgeScaffold intentionally doesn't wrap the
                      // body in SafeArea so the surface can draw
                      // edge-to-edge — kid-mode surfaces handle the
                      // top inset themselves.
                      SizedBox(
                        height: MediaQuery.paddingOf(context).top + 8,
                      ),
                      // Wave 138: the header's "Subject" identity
                      // panel is dropped; the survey is anonymous,
                      // so the header just shows template + progress.
                      // Wave 139: pass progressTotal=0 while on
                      // About-you so the header hides both the dots
                      // and the score (avoids "0 / 11" before any
                      // question has been seen).
                      SurveyHeader(
                        template: t,
                        progressIndex: math.min(_index + 1, totalQuestions),
                        progressTotal: _started ? totalQuestions : 0,
                        answeredScored: answeredScored,
                        scoredTotal: t.scored.length,
                        atCloseout: atCloseout,
                        saving: _saving,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: !_started
                            ? _AboutYouBinding(
                                voiceId: _voiceId,
                                ageBand: _ageBand,
                                grade: _grade,
                                school: _school,
                                onPickVoice: _onVoicePicked,
                                onPickIdentity: _onIdentityPick,
                                onAddIdentityOption: _onIdentityAddOption,
                                onStart: _identityComplete ? _onStart : null,
                                ttsService: _tts,
                                language: lang,
                                onPickLanguage: _onPickLanguage,
                                volume: volume,
                                onVolumeChanged: _onVolumeChanged,
                              )
                            : PageView.builder(
                                controller: _page,
                                // Wave 149: disable user swipe. The
                                // bottom Next button (and the agree3
                                // auto-advance) are the ONLY way
                                // forward, so the required-answer
                                // gate can't be bypassed by a swipe.
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                onPageChanged: (i) {
                                  setState(() => _index = i);
                                  if (i < totalQuestions) {
                                    unawaited(_playQuestion(i));
                                  } else {
                                    // Wave 148: kid swiped to the
                                    // closeout page. No new audio
                                    // fires there, so without an
                                    // explicit stop the last
                                    // question's TTS keeps playing
                                    // over the "All done!" surface.
                                    unawaited(_tts.stop());
                                  }
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
                                      language: lang,
                                    );
                                  }
                                  final page = pages[i];
                                  final q = page.question;
                                  final onReplay = _voiceId == null
                                      ? null
                                      : () =>
                                          unawaited(_playQuestion(i));
                                  void afterAnswer(
                                      {required bool autoAdvance}) {
                                    unawaited(_autosave());
                                    if (autoAdvance) {
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
                                      language: lang,
                                      onPickYes: () {
                                        final picked = _answers
                                            .multiselect(q.key)
                                            .toSet()
                                          ..add(opt.key);
                                        final updated =
                                            SurveyAnswers.fromJson(
                                                _answers.toJson())
                                              ..setMultiselect(
                                                  q.key, picked.toList());
                                        setState(() => _answers = updated);
                                        afterAnswer(autoAdvance: true);
                                      },
                                      onPickNo: () {
                                        final picked = _answers
                                            .multiselect(q.key)
                                            .toSet()
                                          ..remove(opt.key);
                                        final updated =
                                            SurveyAnswers.fromJson(
                                                _answers.toJson())
                                              ..setMultiselect(
                                                  q.key, picked.toList());
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
                                    language: lang,
                                    onAnswered:
                                        (next, {required autoAdvance}) {
                                      setState(() => _answers = next);
                                      afterAnswer(autoAdvance: autoAdvance);
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
                      // Bottom Back / Next row only renders once the
                      // kid has started the questions. The About-you
                      // page owns its own Start button inline.
                      if (_started)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _index == 0
                                      ? null
                                      : () {
                                          unawaited(
                                              HapticFeedback.selectionClick());
                                          unawaited(_page.previousPage(
                                            duration: const Duration(
                                                milliseconds: 240),
                                            curve: Curves.easeOut,
                                          ));
                                        },
                                  icon: const Icon(Icons.arrow_back),
                                  label: Text(SurveyStrings.of(lang).back),
                                ),
                                const Spacer(),
                                if (!atCloseout)
                                  SurveyForwardButton(
                                    question: t.questions[
                                        _safeQuestionIndex(t, _index)],
                                    atCloseout: false,
                                    language: lang,
                                    onTap: canAdvance
                                        ? () {
                                            unawaited(HapticFeedback
                                                .selectionClick());
                                            _advanceFrom(_index);
                                          }
                                        : null,
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

  /// The exploded-pages list maps multiselect options onto
  /// per-option pages; the bottom Next button still wants to know
  /// what KIND of question we're on (so it can hide for agree3).
  /// Walk back from page index to the parent question index.
  int _safeQuestionIndex(SurveyTemplate t, int pageIndex) {
    var remaining = pageIndex;
    for (var qi = 0; qi < t.questions.length; qi++) {
      final q = t.questions[qi];
      final span = q.kind == SurveyQuestionKind.multiselect
          ? q.options.length
          : 1;
      if (remaining < span) return qi;
      remaining -= span;
    }
    return t.questions.length - 1;
  }
}

/// Wave 138: Riverpod binding for [AboutYouPage]. Watches the three
/// per-program picker-options streams and pipes them in; otherwise
/// it's a thin wrapper around the pure widget.
class _AboutYouBinding extends ConsumerWidget {
  const _AboutYouBinding({
    required this.voiceId,
    required this.ageBand,
    required this.grade,
    required this.school,
    required this.onPickVoice,
    required this.onPickIdentity,
    required this.onAddIdentityOption,
    required this.onStart,
    required this.ttsService,
    required this.language,
    required this.onPickLanguage,
    required this.volume,
    required this.onVolumeChanged,
  });

  final String? voiceId;
  final String? ageBand;
  final String? grade;
  final String? school;
  final Future<void> Function(String voiceId) onPickVoice;
  final Future<void> Function(String dimension, String label) onPickIdentity;
  final Future<void> Function(String dimension, String label)
      onAddIdentityOption;
  final VoidCallback? onStart;
  final SurveyTtsService ttsService;
  final SurveyLanguage language;
  final ValueChanged<SurveyLanguage> onPickLanguage;
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final ageAsync = ref.watch(
      surveyPickerOptionsProvider(
        (spaceId: spaceId, dimension: 'age_band'),
      ),
    );
    final gradeAsync = ref.watch(
      surveyPickerOptionsProvider(
        (spaceId: spaceId, dimension: 'grade'),
      ),
    );
    final schoolAsync = ref.watch(
      surveyPickerOptionsProvider(
        (spaceId: spaceId, dimension: 'school'),
      ),
    );
    List<String> labels(AsyncValue<List<SurveyPickerOption>> a) =>
        (a.value ?? const []).map((o) => o.label).toList();

    return AboutYouPage(
      voiceId: voiceId,
      ageBand: ageBand,
      grade: grade,
      school: school,
      ageBandOptions: labels(ageAsync),
      gradeOptions: labels(gradeAsync),
      schoolOptions: labels(schoolAsync),
      onPickVoice: onPickVoice,
      onPickIdentity: onPickIdentity,
      onAddIdentityOption: onAddIdentityOption,
      onStart: onStart,
      ttsService: ttsService,
      language: language,
      onPickLanguage: onPickLanguage,
      volume: volume,
      onVolumeChanged: onVolumeChanged,
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
