import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/omnibox/bottom_omnibox_bar.dart';
import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/omnibox/omnibox_history.dart';
import 'package:differentworld/features/omnibox/omnibox_mode.dart';
import 'package:differentworld/features/omnibox/omnibox_state.dart';
import 'package:differentworld/features/omnibox/slash_commands.dart';
import 'package:differentworld/features/voice/deepgram_voice_service.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/floating_actions.dart';
import 'package:differentworld/shared/widgets/floating_back.dart';
import 'package:differentworld/shared/widgets/floating_hamburger.dart';
import 'package:differentworld/shared/widgets/main_drawer.dart';
import 'package:differentworld/shared/widgets/route_chrome.dart';
import 'package:differentworld/shared/widgets/shell_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Persistent app shell — drawer + top chrome + bottom omnibox bar.
///
/// **Wave 17 simplification.** The omnibox SUGGESTION LIST used to
/// be a `_OmniboxResultsPanel` overlay inside this shell's Stack
/// with `_expanded` state, a scrim, a PopScope intercept, and
/// hand-painted insets. It's now a real go_router route
/// (`/search` → `OmniboxSearchScreen`) mounted inside the same
/// ShellRoute. Result: this widget collapsed by ~300 lines, the
/// layout law applies to search like any other screen, and back /
/// gesture dismiss work uniformly.
///
/// What still lives here (the things that genuinely need to persist
/// across page transitions):
/// - Drawer ownership (one MainDrawer for the whole app)
/// - Top chrome stack (hamburger / back / actions pills)
/// - Bottom omnibox bar (composer + mic — stays anchored as routes
///   change, LLM-chat style)
/// - Voice dictation controller (one session at a time, survives
///   the route push so dictating "let's look at owen" can be
///   followed by navigation without re-arming the mic)
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Source of truth for the bar's text. Mirrors into
  /// [omniboxQueryProvider] on every change so the search route
  /// re-renders.
  final _ctrl = TextEditingController();

  /// Bar focus. Listening for focus changes drives the auto-push
  /// onto `/search`: tap the bar → focus → push search route.
  final _focus = FocusNode();

  /// Subscription to the Deepgram voice controller's updates. Non-
  /// null only while a session is live; we tear it down on stop.
  StreamSubscription<VoiceUpdate>? _voiceSub;

  /// Mic-button UI state — "listening" pill turns on while a
  /// dictation session is active.
  bool _voiceActive = false;

  /// What the composer's text was BEFORE the user started dictating.
  /// We restore this prefix and append the transcript so a partial
  /// existing query isn't blown away by the voice session.
  String _voicePrefix = '';

  /// Cached voice controller so `dispose()` can cancel without
  /// touching `ref` (which is unsafe once the element is deactivated).
  DeepgramVoiceController? _voice;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    unawaited(_voiceSub?.cancel());
    _voiceSub = null;
    unawaited(_voice?.cancel());
    _voice = null;
    _focus.removeListener(_onFocusChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Focus drives the search route. When the bar gains focus and
  /// we're not already on `/search`, push. When the bar loses focus
  /// while we ARE on search, leave the route alone — the user can
  /// re-tap to re-focus without bouncing in and out.
  ///
  /// Deferred via `Future.microtask` because focus listeners can
  /// fire during the widget tree's build phase (route transitions
  /// re-attach `TextField`s, which can synchronously re-notify
  /// focus listeners). Calling `context.push()` synchronously from
  /// inside a build trips Riverpod's
  /// "modify provider while widget tree was building" assertion
  /// (same pattern documented for `EdgeScaffold`'s chrome publish
  /// in CLAUDE.md). The microtask runs after the current sync tick
  /// but before the next frame, so the navigation still lands in
  /// the same visible frame.
  void _onFocusChanged() {
    if (!mounted) return;
    if (!_focus.hasFocus) return;
    unawaited(Future.microtask(() {
      if (!mounted) return;
      final loc = GoRouterState.of(context).matchedLocation;
      if (loc != '/search') {
        unawaited(context.push('/search'));
      }
    }));
  }

  /// Bar value change. Two writes: keep the controller (already
  /// done by TextField), mirror into the provider so the search
  /// screen re-renders.
  void _onQueryChanged(String value) {
    ref.read(omniboxQueryProvider.notifier).set(value);
  }

  void _clear() {
    _ctrl.clear();
    ref.read(omniboxQueryProvider.notifier).clear();
  }

  /// "Back to page" — collapse the bar and pop /search if we're on
  /// it. The bar's leading-icon-while-focused renders this verb.
  void _collapse() {
    _clear();
    _focus.unfocus();
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc == '/search') {
      context.pop();
    }
  }

  /// Paint the active route's chrome (back button / hamburger +
  /// actions OR a full-width top overlay) as floating Positioned
  /// widgets at the top of the AppShell's body Stack.
  List<Widget> _buildTopChrome(
    RouteChrome chrome,
    double topInset, {
    required bool showDrawer,
  }) {
    if (chrome.topOverlay != null) {
      return [
        Positioned(
          top: topInset + 8,
          left: 8,
          right: 8,
          child: chrome.topOverlay!,
        ),
      ];
    }
    final widgets = <Widget>[];
    final leftChrome = <Widget>[];
    if (showDrawer) {
      leftChrome.add(const FloatingHamburger());
    }
    if (chrome.showBack) {
      if (leftChrome.isNotEmpty) {
        leftChrome.add(const SizedBox(width: 8));
      }
      leftChrome.add(
        FloatingBack(fallbackRoute: chrome.backFallbackRoute),
      );
    }
    if (leftChrome.isNotEmpty) {
      widgets.add(
        Positioned(
          top: topInset + 8,
          left: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: leftChrome,
          ),
        ),
      );
    }
    if (chrome.actions.isNotEmpty) {
      widgets.add(
        Positioned(
          top: topInset + 8,
          right: 8,
          child: FloatingActions(children: chrome.actions),
        ),
      );
    }
    return widgets;
  }

  /// Fire the capture action with the current query, then collapse +
  /// snackbar. The composer becomes the capture surface — typing
  /// "Owen napped well today" + return saves a capture.
  Future<void> _saveAsCapture(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final actions = ref.read(captureActionsProvider);
    _collapse();
    await runReported(
      library: 'captures',
      messenger: messenger,
      onSuccess: 'Saved as a capture.',
      onError: 'Could not save the capture.',
      action: () => actions.start(body: body),
    );
  }

  /// User hit return. Mode decides behavior: capture / slash / open
  /// the top-ranked search result.
  void _onComposerSubmit(String text) {
    final catalog = ref.read(omniboxCatalogProvider);
    final mode = detectMode(query: text, catalog: catalog);

    if (mode == OmniboxMode.capture) {
      unawaited(_saveAsCapture(text));
      return;
    }
    if (mode == OmniboxMode.slash) {
      _execSlash(text);
      return;
    }
    final q = text.toLowerCase().trim();
    if (q.isEmpty) return;
    OmniboxEntry? best;
    var bestScore = 0;
    for (final e in catalog) {
      final s = e.score(q);
      if (s > bestScore) {
        bestScore = s;
        best = e;
      }
    }
    if (best == null) return;
    bumpRecent(ref, best.id);
    final entry = best;
    _collapse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      entry.onSelect(context, ref);
    });
  }

  /// Toggle the Deepgram voice session. Tap once → start recording +
  /// streaming; tap again → stop and keep the transcript. Errors
  /// surface via SnackBar.
  void _toggleVoice() {
    // The explicit type tells the analyzer the promoted result of `??`
    // is non-nullable — without it Dart's flow analysis loses the
    // promotion through the field assignment two lines down.
    // ignore: omit_local_variable_types
    final DeepgramVoiceController voice =
        _voice ?? ref.read(deepgramVoiceProvider);
    _voice = voice;
    if (_voiceActive) {
      unawaited(voice.stop());
      return;
    }
    _voicePrefix = _ctrl.text;
    setState(() => _voiceActive = true);
    _focus.requestFocus();
    _voiceSub = voice.updates.listen(_onVoiceUpdate);
    unawaited(voice.start());
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
    _ctrl
      ..text = combined
      ..selection = TextSelection.collapsed(offset: combined.length);
    // Mirror into the provider so the search route sees the live
    // transcript as the user dictates.
    ref.read(omniboxQueryProvider.notifier).set(combined);

    if (update.state == VoiceState.idle) {
      _voiceActive = false;
      unawaited(_voiceSub?.cancel());
      _voiceSub = null;
      setState(() {});
    }
  }

  /// Resolve the typed slash query to a SlashCommand and run it.
  void _execSlash(String text) {
    final parsed = parseSlashQuery(text);
    final name = parsed.name;
    if (name == null || name.isEmpty) return;
    final visible = matchSlashCommands(null, viewer: ref.read(viewerProvider));
    if (visible.isEmpty) return;
    final exact = visible.firstWhere(
      (c) => c.name == name || c.aliases.contains(name),
      orElse: () => visible.firstWhere(
        (c) => c.matches(name),
        orElse: () => visible.first,
      ),
    );
    if (exact.name != name &&
        !exact.aliases.contains(name) &&
        !exact.matches(name)) {
      return;
    }
    _collapse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      exact.exec(context, ref, parsed.args);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watching the query provider so the mode (and bar tint) update
    // as the user types. The TextField writes both the controller
    // and the provider on every keystroke.
    final query = ref.watch(omniboxQueryProvider);
    final catalog = ref.watch(omniboxCatalogProvider);
    final mode = detectMode(query: query, catalog: catalog);

    final inKidMode = ref.watch(kidModeProvider);
    final chrome = ref.watch(routeChromeProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    final viewer = ref.watch(viewerProvider);
    final showDrawer = viewer.isSignedIn && !inKidMode;
    return Scaffold(
      drawer: showDrawer ? const MainDrawer() : null,
      // `resizeToAvoidBottomInset: true` is load-bearing — it shrinks
      // the body so the keyboard occupies its own space below the
      // body. The omnibox bar lives at the bottom of that body, so
      // it sits flush above the keyboard with no extra math.
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Route content. Inset on both ends by the shell so the
          // layout law (chrome top, omnibox bottom, body in the
          // visible slot) applies to every route uniformly. See
          // ShellMetrics for the constants + rationale.
          Padding(
            padding: EdgeInsets.only(
              top: inKidMode ? 0 : ShellMetrics.topChromeHeight,
              bottom: inKidMode ? 0 : ShellMetrics.bottomOmniboxHeight,
            ),
            child: widget.child,
          ),
          // Persistent top chrome (hamburger + back + per-route
          // actions). Hidden in kid mode.
          if (!inKidMode)
            ..._buildTopChrome(
              chrome,
              topInset,
              showDrawer: showDrawer,
            ),
          // Composer at the bottom. Sits flush above the keyboard
          // when it's up, flush above the home-indicator safe area
          // otherwise. Hidden in kid mode so the kid surface has no
          // staff-facing affordance.
          if (!inKidMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomOmniboxBar(
                controller: _ctrl,
                focusNode: _focus,
                mode: mode,
                voiceActive: _voiceActive,
                onChanged: _onQueryChanged,
                onSubmit: _onComposerSubmit,
                onClear: _clear,
                onMicTap: _toggleVoice,
                onCollapse: _collapse,
              ),
            ),
        ],
      ),
    );
  }
}
