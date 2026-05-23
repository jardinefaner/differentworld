// Canonical interaction-flow test for the omnibox bar.
//
// This test exists to catch the class of bug we hit on 2026-05-22:
// the bar's focus was being stolen by the `/search` route push,
// closing the soft keyboard, and forcing the user to tap-then-type
// for every single character. The CLAUDE.md "Interaction invariants"
// section is the source of truth for what input surfaces must hold;
// the assertions below mirror those rules.
//
// Scope today:
// * **Unit-level** assertions for the focus-restore timing logic
//   (`shouldRestoreFocusAfterPush`) — fast, deterministic, runs in
//   any CI.
// * **Widget-level** assertions for the [BottomOmniboxBar] widget
//   in isolation — verifies tap → focus, type → onChanged fires,
//   mode-aware affordances render.
//
// What's NOT yet here (deliberately): a full AppShell + go_router
// integration test that exercises the actual route push and asserts
// focus is retained across it. That requires bootstrapping ~6
// providers (viewer, omniboxCatalog, groups, subjects, activities,
// vehicles, members) plus a router. A TODO marker is below; this
// file is the right home when that lands.
//
// When you add a new input surface (TextField-bearing screen),
// either extend this file with assertions for it or create a
// sibling `<surface>_interaction_test.dart` mirroring the shape.

import 'package:differentworld/features/omnibox/bottom_omnibox_bar.dart';
import 'package:differentworld/features/omnibox/omnibox_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure decision: should the focus listener re-grant focus to the
/// bar because the route push just stole it? Extracted from
/// AppShell._onFocusChanged so we can unit-test the timing logic
/// without bootstrapping the full app.
///
/// Returns true when focus loss happened within the 500ms window
/// after a recent `/search` push (the FocusScope rotation steals
/// focus ~70-300ms after push in practice). Returns false otherwise
/// — including when no push has happened yet and when the loss is
/// clearly the user tapping outside (>500ms after push).
///
/// Keep in sync with the inline logic in `AppShell._onFocusChanged`.
@visibleForTesting
bool shouldRestoreFocusAfterPush({
  required DateTime? lastPushAt,
  required DateTime now,
  Duration window = const Duration(milliseconds: 500),
}) {
  if (lastPushAt == null) return false;
  return now.difference(lastPushAt) <= window;
}

void main() {
  group('Focus-restore timing decision', () {
    // The unit tests for the pure decision function. These would
    // have caught the bug if we'd written them BEFORE the fix —
    // the bug was the post-frame callback firing too early (focus
    // hadn't been lost yet), which is a different decision point
    // than the focus-loss-event-driven path that fixed it.

    final now = DateTime(2026, 5, 22, 15, 35, 52, 641);

    test('no push yet → do not restore', () {
      expect(
        shouldRestoreFocusAfterPush(lastPushAt: null, now: now),
        isFalse,
      );
    });

    test('focus lost 50ms after push → restore', () {
      final push = now.subtract(const Duration(milliseconds: 50));
      expect(
        shouldRestoreFocusAfterPush(lastPushAt: push, now: now),
        isTrue,
      );
    });

    test('focus lost 288ms after push (typical case) → restore', () {
      // 288ms is the actual observed latency from the live logcat
      // capture on 2026-05-22, between the push and the FocusScope
      // rotation event on a Pixel 6.
      final push = now.subtract(const Duration(milliseconds: 288));
      expect(
        shouldRestoreFocusAfterPush(lastPushAt: push, now: now),
        isTrue,
      );
    });

    test('focus lost exactly at the 500ms boundary → restore', () {
      final push = now.subtract(const Duration(milliseconds: 500));
      expect(
        shouldRestoreFocusAfterPush(lastPushAt: push, now: now),
        isTrue,
      );
    });

    test('focus lost 501ms after push → do NOT restore (user action)',
        () {
      final push = now.subtract(const Duration(milliseconds: 501));
      expect(
        shouldRestoreFocusAfterPush(lastPushAt: push, now: now),
        isFalse,
      );
    });

    test('focus lost 2s after push → do NOT restore', () {
      final push = now.subtract(const Duration(seconds: 2));
      expect(
        shouldRestoreFocusAfterPush(lastPushAt: push, now: now),
        isFalse,
      );
    });
  });

  group('BottomOmniboxBar widget — isolated', () {
    // These widget tests exercise the bar in isolation with mock
    // callbacks. They don't push routes; the route-retention
    // assertion below is the integration-shaped TODO.

    Widget mount({
      required TextEditingController controller,
      required FocusNode focusNode,
      OmniboxMode mode = OmniboxMode.search,
      bool voiceActive = false,
      VoidCallback? onMicTap,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmit,
      VoidCallback? onClear,
      VoidCallback? onCollapse,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: BottomOmniboxBar(
              controller: controller,
              focusNode: focusNode,
              mode: mode,
              voiceActive: voiceActive,
              onChanged: onChanged ?? (_) {},
              onSubmit: onSubmit ?? (_) {},
              onClear: onClear ?? () {},
              onMicTap: onMicTap ?? () {},
              onCollapse: onCollapse ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('tap on the field gives it focus', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        mount(controller: controller, focusNode: focus),
      );
      expect(focus.hasFocus, isFalse);

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(
        focus.hasFocus,
        isTrue,
        reason: 'Tapping the bar must give the field focus '
            'within one pump — this is the "snappy tap" rule.',
      );
    });

    testWidgets('typing fires onChanged with the entered text',
        (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      String? captured;

      await tester.pumpWidget(
        mount(
          controller: controller,
          focusNode: focus,
          onChanged: (v) => captured = v,
        ),
      );
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();

      expect(captured, equals('a'));
      expect(controller.text, equals('a'));
    });

    testWidgets('capture mode renders the lightning-bolt leading icon',
        (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        mount(
          controller: controller,
          focusNode: focus,
          mode: OmniboxMode.capture,
        ),
      );

      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
    });

    testWidgets('slash mode renders the chevron leading icon',
        (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        mount(
          controller: controller,
          focusNode: focus,
          mode: OmniboxMode.slash,
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('mic button calls onMicTap', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var taps = 0;

      await tester.pumpWidget(
        mount(
          controller: controller,
          focusNode: focus,
          onMicTap: () => taps++,
        ),
      );

      await tester.tap(find.byIcon(Icons.mic_none_outlined));
      await tester.pump();

      expect(taps, equals(1));
    });

    // NOTE: a "back arrow when focused" test belongs at the
    // AppShell level, not here — BottomOmniboxBar reads
    // `focusNode.hasFocus` at build time but doesn't subscribe to
    // focus changes itself. Its parent (AppShell) rebuilds it in
    // production. Asserting that behavior in isolation gives a
    // false negative.
  });

  // TODO(integration): A full-shell test that:
  //   1. Mounts AppShell with a real go_router (`/` → stub home,
  //      `/search` → OmniboxSearchScreen)
  //   2. Overrides viewerProvider, omniboxCatalogProvider, groupsProvider,
  //      subjectsInSpaceProvider, activitiesProvider, locationsProvider,
  //      vehiclesProvider, membersInSpaceProvider with minimal fakes
  //   3. `tester.tap(find.byType(TextField))` → assert focus on bar
  //   4. `tester.enterText(..., 'a')` → triggers _onQueryChanged
  //   5. `tester.pumpAndSettle()` to let the route push complete
  //   6. Assert: `tester.binding.focusManager.primaryFocus` is STILL
  //      the bar's FocusNode (NOT a focus traversable inside /search)
  //
  // This is the test that would have caught today's bug in CI. It's
  // bigger than the others (provider wiring is invasive) and is left
  // as a follow-up — until then, the live-logcat smoke test on a real
  // device is the regression gate.
}
