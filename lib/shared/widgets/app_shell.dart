import 'dart:async';
import 'dart:ui';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/omnibox/bottom_omnibox_bar.dart';
import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/omnibox/omnibox_history.dart';
import 'package:differentworld/features/omnibox/omnibox_mode.dart';
import 'package:differentworld/features/omnibox/omnibox_search_screen.dart';
import 'package:differentworld/features/omnibox/omnibox_state.dart';
import 'package:differentworld/features/omnibox/slash_commands.dart';
import 'package:differentworld/features/voice/deepgram_voice_service.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/debug_viewer_toggle.dart';
import 'package:differentworld/shared/widgets/desktop_nav_rail.dart';
import 'package:differentworld/shared/widgets/floating_actions.dart';
import 'package:differentworld/shared/widgets/floating_back.dart';
import 'package:differentworld/shared/widgets/floating_hamburger.dart';
import 'package:differentworld/shared/widgets/main_drawer.dart';
import 'package:differentworld/shared/widgets/route_chrome.dart';
import 'package:differentworld/shared/widgets/shell_metrics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, SystemChannels, SystemNavigator;
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

  /// Whether the omnibox suggestion panel is mounted inline (as an
  /// overlay inside this shell's Stack). True while the bar has
  /// focus.
  ///
  /// **Wave 25 (2026-05-22)** — replaces the previous "push `/search`
  /// as a go_router route on focus" approach. The route push triggered
  /// a FocusScope rotation that closed the soft keyboard on Android
  /// reliably (the "keyboard appears and disappears" bug). Rendering
  /// inline keeps the bar's TextField in the same FocusScope, so the
  /// IME never tears down across the panel mount.
  ///
  /// The `/search` route still exists in the router for direct linking
  /// (drawer "Search anything" tile) but the bar-tap path uses this
  /// flag instead.
  bool _searchOverlayOpen = false;

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

  /// Bar focus listener.
  ///
  /// **Wave 25 (2026-05-22)**: open / close the in-shell suggestion
  /// overlay based on bar focus. No route push, no FocusScope
  /// rotation, no IME teardown. The bar's TextField stays primary
  /// focused the entire time the overlay is mounted.
  ///
  /// * **On focus gain**: open the overlay.
  /// * **On focus loss**: close the overlay. Unlike the route-push
  ///   approach, focus loss here is genuine (user tapped outside,
  ///   navigated away) — we never artificially steal focus, so we
  ///   don't need a rescue path.
  ///
  /// Wave 58 follow-up: focus loss alone NO LONGER closes the overlay.
  /// The bar's focus and the overlay's open-state are now independent —
  /// the overlay opens on focus-gain and stays open until an explicit
  /// close action fires (keyboard-hide button, suggestion select, back
  /// gesture via PopScope, scrim tap). Without this decoupling, the
  /// Cupertino swipe-back gesture would steal focus from the
  /// TextField mid-gesture, this listener would set
  /// `_searchOverlayOpen=false`, PopScope's canPop would flip to true
  /// at the next rebuild, and the gesture would commit a route pop
  /// (or, on root, fire the exit-confirmation). The user saw the
  /// app "exit" instead of just dismissing the overlay.
  void _onFocusChanged() {
    if (kDebugMode) {
      debugPrint(
        '[omnibox] focus=${_focus.hasFocus} '
        'primary=${FocusManager.instance.primaryFocus == _focus}',
      );
    }
    if (!mounted) return;
    if (_focus.hasFocus && !_searchOverlayOpen) {
      // Focus gained → open the overlay.
      setState(() => _searchOverlayOpen = true);
    }
    // Focus loss is intentionally ignored — overlay stays open until
    // an explicit close fires _closeSearchOverlay().
  }

  /// Bar value change. The TextField already updated its own
  /// controller; mirror the value into [omniboxQueryProvider] so the
  /// overlay's suggestion list filters as the user types.
  void _onQueryChanged(String value) {
    if (kDebugMode) {
      debugPrint('[omnibox] queryChanged len=${value.length}');
    }
    ref.read(omniboxQueryProvider.notifier).set(value);
  }

  /// Close the overlay programmatically (called by OmniboxSearchScreen
  /// when the user selects a suggestion / runs a slash / saves a
  /// capture). The overlay-as-overlay needs an explicit close path
  /// because there's no Navigator to pop.
  void _closeSearchOverlay() {
    if (!mounted) return;
    _focus.unfocus();
    if (_searchOverlayOpen) {
      setState(() => _searchOverlayOpen = false);
    }
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
    VoidCallback? overlayBackOverride,
  }) {
    // Stable keys on every emitted Positioned so the Stack's
    // reconciliation stays predictable when sibling Stack children
    // (the omnibox overlay, the bar) come and go. Without keys,
    // Flutter would shuffle Element-to-Widget matches on every
    // build and the bar's TextField would rebuild, dropping its
    // input connection → keyboard close.
    if (chrome.topOverlay != null) {
      return [
        Positioned(
          key: const ValueKey('shell-chrome-overlay'),
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
        FloatingBack(
          fallbackRoute: chrome.backFallbackRoute,
          // overlayBackOverride is set when the suggestion overlay is
          // open — closes the overlay instead of popping the route.
          onPressed: overlayBackOverride,
        ),
      );
    }
    if (leftChrome.isNotEmpty) {
      widgets.add(
        Positioned(
          key: const ValueKey('shell-chrome-left'),
          top: topInset + 8,
          left: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: leftChrome,
          ),
        ),
      );
    }
    // Wave 168: dev-only viewer-kind toggle ALWAYS renders in the
    // action pill in debug builds, alongside any route-specific
    // actions. Lets the developer impersonate a Teacher / Substitute
    // / Specialist / Guardian etc. without signing out. Compiled
    // out of release builds via the `if (kDebugMode)` guard on the
    // widget side (the import itself stays; the toggle's build
    // returns SizedBox.shrink in release so it costs nothing).
    final actionsForPill = <Widget>[
      if (kDebugMode) const DebugViewerToggle(),
      ...chrome.actions,
    ];
    if (actionsForPill.isNotEmpty) {
      widgets.add(
        Positioned(
          key: const ValueKey('shell-chrome-actions'),
          top: topInset + 8,
          right: 8,
          child: FloatingActions(children: actionsForPill),
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
  /// the top-ranked search result. Every silent-return path is paired
  /// with a snackbar — return must NEVER feel like a dead key.
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
    if (q.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Type something first, or tap a suggestion.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    OmniboxEntry? best;
    var bestScore = 0;
    for (final e in catalog) {
      final s = e.score(q);
      if (s > bestScore) {
        bestScore = s;
        best = e;
      }
    }
    if (best == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('No match for "$text". Try fewer words.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
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
    // Force the IME up even if Flutter thinks focus never moved.
    // `requestFocus()` alone is a no-op for the keyboard on Android
    // if the framework treats focus as already-held. The user
    // started dictation — they may also want to type alongside,
    // so the keyboard belongs on screen.
    unawaited(SystemChannels.textInput.invokeMethod('TextInput.show'));
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
  /// Every silent-return path is paired with a snackbar so return
  /// never feels like a dead key.
  void _execSlash(String text) {
    final parsed = parseSlashQuery(text);
    final name = parsed.name;
    if (name == null || name.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Type a command after the slash — e.g. /today.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final visible = matchSlashCommands(null, viewer: ref.read(viewerProvider));
    if (visible.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('No slash commands available here.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
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
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Unknown command "/$name".'),
          duration: const Duration(seconds: 2),
        ),
      );
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
    // Wave 121: at desktop widths the hamburger drawer is replaced
    // by a persistent left-side nav rail. The rail only renders for
    // signed-in staff (guardians have no peer destinations to nav
    // between — they live on /, /messages, /children/*), and is
    // hidden in kid mode same as the drawer.
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final showDesktopRail = showDrawer &&
        viewer is! GuardianViewer &&
        viewportWidth >= Breakpoints.tablet;

    // Compute whether the current route is at the root — if so,
    // a back gesture would exit the app entirely. We intercept
    // those gestures and show a confirmation dialog so the user
    // knows what they're about to do.
    //
    // For non-root routes (e.g. /groups/abc), let the back propagate
    // normally (no intercept) — PopScope.canPop=true means default
    // pop happens as usual.
    //
    // In kid mode the shell delegates to the kid-mode handler; don't
    // double-intercept.
    final atRoot =
        GoRouterState.of(context).matchedLocation == '/' && !inKidMode;

    // When the suggestion overlay is open, the system back gesture
    // (swipe-from-left-edge on Android, swipe-back on iOS) should
    // close the OVERLAY first — not pop the underlying route. Without
    // this, a user who tapped the omnibox on /groups/abc and then
    // swiped back would land on Today (route popped) instead of just
    // returning to the page they were on. canPop: false intercepts;
    // the handler below decides what to actually do based on which
    // overlay (if any) is currently visible.
    final canPop = !atRoot && !_searchOverlayOpen;

    // Keyboard shortcuts — desktop-/web-friendly verbs. Cmd-K opens
    // the omnibox (the universal "go anywhere" verb), Esc closes the
    // overlay, Cmd-/ also opens (a Discord / Slack convention). Mobile
    // users never hit these but they're free to add — `CallbackShortcuts`
    // only fires when a keyboard is present.
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          _focus.requestFocus,
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          _focus.requestFocus,
      const SingleActivator(LogicalKeyboardKey.slash, meta: true):
          _focus.requestFocus,
      const SingleActivator(LogicalKeyboardKey.slash, control: true):
          _focus.requestFocus,
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_searchOverlayOpen) _closeSearchOverlay();
      },
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // First: did the back come from the overlay being open? If so,
        // close it and stop — the user wanted to dismiss the overlay,
        // not pop the route.
        if (_searchOverlayOpen) {
          _closeSearchOverlay();
          return;
        }
        // Otherwise we're at root (canPop=false because of atRoot) and
        // the user tried to back out of the app entirely. Confirm.
        if (!mounted) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Close Different World?'),
            content: const Text(
              'You can come back anytime — your work is saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        if (shouldExit ?? false) {
          // `SystemNavigator.pop()` finishes the activity on Android
          // (returns to launcher) and is a no-op on iOS (Apple HIG
          // forbids programmatic exit). That's fine — iOS users
          // background via the home gesture.
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
      // Wave 121: at desktop the persistent rail replaces the
      // hamburger drawer. Drawer slot stays wired below desktop so
      // phone / tablet keep their existing swipe-from-edge gesture
      // + hamburger pill.
      drawer: (showDrawer && !showDesktopRail)
          ? const MainDrawer()
          : null,
      // `resizeToAvoidBottomInset: true` is load-bearing — it shrinks
      // the body so the keyboard occupies its own space below the
      // body. The omnibox bar lives at the bottom of that body, so
      // it sits flush above the keyboard with no extra math.
      resizeToAvoidBottomInset: true,
      body: showDesktopRail
          ? Row(
              children: [
                const SizedBox(width: 240, child: DesktopNavRail()),
                Expanded(child: _buildBodyStack(
                  inKidMode: inKidMode,
                  viewer: viewer,
                  topInset: topInset,
                  chrome: chrome,
                  query: query,
                  mode: mode,
                  showDrawer: false, // hamburger pill hidden at desktop
                  atRoot: atRoot,
                  context: context,
                )),
              ],
            )
          : _buildBodyStack(
              inKidMode: inKidMode,
              viewer: viewer,
              topInset: topInset,
              chrome: chrome,
              query: query,
              mode: mode,
              showDrawer: showDrawer,
              atRoot: atRoot,
              context: context,
            ),
    ),
    ),
    );
  }

  /// Wave 121: the body Stack is now used either standalone (phone /
  /// tablet — the existing rendering) or as the right column of a
  /// desktop layout (alongside [DesktopNavRail]). Extracting it as a
  /// method lets us call it in both shapes without duplicating the
  /// 100+ lines of stack contents.
  Widget _buildBodyStack({
    required bool inKidMode,
    required Viewer viewer,
    required double topInset,
    required RouteChrome chrome,
    required String query,
    required OmniboxMode mode,
    required bool showDrawer,
    required bool atRoot,
    required BuildContext context,
  }) {
    return Stack(
        // Every child is keyed so Flutter's reconciliation matches
        // them ACROSS overlay toggles. Without keys, inserting the
        // overlay child shifts the rest of the children's positions
        // in the list; Flutter then matches existing Elements to
        // wrong slots, rebuilds the bar's TextField, and the IME
        // connection tears down — the user sees the keyboard close.
        // (This was the actual root cause of "keyboard disappears
        // on first tap" — not FocusScope rotation, the prior theory.)
        children: [
          // Route content. Edge-to-edge: the body fills the viewport
          // from top to bottom; the floating chrome pills + omnibox
          // bar overlay it as translucent glass elements. We only
          // reserve BOTTOM space (so the last scrolled item doesn't
          // sit forever behind the omnibox); the TOP is intentionally
          // un-padded so list content scrolls THROUGH the chrome
          // strip — Wave 52 reverted the prior "padded below the
          // chrome" layout-law because it produced a solid-coloured
          // strip at top that read as an opaque appbar even though
          // the pills themselves were already glass.
          //
          // Routes typically start with a ContentHeader; that header
          // is wide enough that the chrome pills (~48dp each, top
          // ~64dp area) only overlap a sliver of it, and the glass
          // blur keeps the underlying text readable.
          Padding(
            key: const ValueKey('shell-route-content'),
            padding: EdgeInsets.only(
              // No omnibox bar for guardians or in kid mode → no
              // bottom reservation needed; route content can fill all
              // the way to the gesture inset.
              bottom: (inKidMode || viewer is GuardianViewer)
                  ? 0
                  : ShellMetrics.bottomOmniboxHeight,
            ),
            // Wave 127: SelectionArea moved here from
            // MaterialApp.builder. Now sits inside the routed
            // Navigator's Overlay scope (provided by Scaffold's
            // ancestor Navigator), so the SelectableRegion's
            // upward Overlay lookup succeeds. Every `Text` inside
            // a route body becomes click-and-drag selectable; the
            // platform default copy/select-all toolbar shows on
            // selection. Excludes chrome / omnibox / drawer (they
            // sit outside this Padding in the Stack), which is
            // the right call — selecting "Today" out of a chrome
            // pill isn't what users want.
            child: SelectionArea(child: widget.child),
          ),
          // Omnibox suggestion panel — rendered inline as an overlay
          // when the bar has focus. NOT a pushed route (see Wave 25
          // notes on _searchOverlayOpen). Sits in the same slot as
          // the route content, opaque to taps so the page underneath
          // doesn't receive them. The bar's TextField stays in this
          // shell's FocusScope across the mount, so the IME stays up.
          //
          // `top: topInset + topChromeHeight` clears the floating
          // chrome pills (which render at `topInset + 8` + ~48dp
          // pill height ≈ `topInset + topChromeHeight`).
          if (!inKidMode && _searchOverlayOpen)
            Positioned(
              key: const ValueKey('shell-omnibox-overlay'),
              // Extend edge-to-edge to the screen top + only stop
              // above the omnibox bar at the bottom. Wave 53 had
              // this starting at topInset + topChromeHeight which
              // left the chrome-strip area uncovered — the body's
              // top edge showed through there, creating a visible
              // seam that read as "appbar background color." Now
              // the glass covers everything except where the bar
              // sits; chrome pills (rendered after this in the
              // Stack order) float on top of the glass.
              top: 0,
              left: 0,
              right: 0,
              bottom: ShellMetrics.bottomOmniboxHeight,
              // Scrim behavior: the overlay must absorb every tap
              // in its bounds. Without this, the BackdropFilter is
              // pointer-transparent and taps on dead space (between
              // rows, padding, etc.) fall through to whatever route
              // sits underneath — clicking "ghost" buttons on Today
              // through the suggestion glass. Wrapping in a
              // GestureDetector with opaque hit-test blocks pass-
              // through; the onTap closes the overlay so tapping
              // empty space is a dismiss gesture (matching modal-
              // sheet expectations). Row taps inside the search
              // screen still win because child gestures beat parent
              // in Flutter's gesture arena.
              //
              // Wave 119: horizontal-drag also closes the overlay.
              // Swipe-back (either direction — left-to-right matches
              // iOS gesture, right-to-left matches Android Material)
              // is a faster dismiss than reaching for the back pill
              // or the Esc key. Velocity threshold keeps small
              // accidental drags from triggering. The list rows
              // themselves don't drag horizontally — child gestures
              // win in Flutter's arena, so this only fires when the
              // user actually swipes empty space or background.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeSearchOverlay,
                onHorizontalDragEnd: (details) {
                  // Velocity is logical px/s. ~300 px/s is a casual
                  // swipe; below that is probably a slow scroll
                  // adjustment that should NOT pop the overlay.
                  final v = details.primaryVelocity ?? 0;
                  if (v.abs() > 300) _closeSearchOverlay();
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: OmniboxSearchScreen(
                    onClose: _closeSearchOverlay,
                  ),
                ),
              ),
            ),
          // Persistent top chrome (hamburger + back + per-route
          // actions). Hidden in kid mode. When the suggestion
          // overlay is open, the chrome pivots to "overlay mode" —
          // always a back-pill that closes the overlay, no per-
          // route actions, no topOverlay. Users see a consistent
          // back affordance whether they got to the suggestion
          // list from Today, a subject detail, or any other route.
          if (!inKidMode)
            ..._buildTopChrome(
              _searchOverlayOpen
                  ? const RouteChrome(showBack: true)
                  : chrome,
              topInset,
              showDrawer: showDrawer && !_searchOverlayOpen,
              overlayBackOverride:
                  _searchOverlayOpen ? _closeSearchOverlay : null,
            ),
          // Composer at the bottom. Sits flush above the keyboard
          // when it's up, flush above the home-indicator safe area
          // otherwise. Hidden in kid mode so the kid surface has no
          // staff-facing affordance. Also hidden for guardians —
          // the omnibox catalog is staff-only (settings, captures,
          // tasks, observations, etc.) and the family lens has its
          // own navigation pattern via the Family Today header.
          if (!inKidMode && viewer is! GuardianViewer)
            Positioned(
              key: const ValueKey('shell-omnibox-bar'),
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
      );
  }
}
