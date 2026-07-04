// Canonical interaction-flow test for the omnibox.
//
// **Wave-back-to-route (2026-06-20).** The omnibox search surface moved
// from an in-shell overlay (whose editable field lived in the bottom BAR)
// to a real `/search` route whose OWN autofocused field raises the
// keyboard. The bottom bar is now a presentational TAP-TARGET that pushes
// `/search`. So the old assertions about the bar holding focus / surviving
// a route push no longer apply to the BAR — they apply to the search
// PAGE's field, which autofocuses on mount.
//
// This test exists to keep the CLAUDE.md "Interaction invariants" honest:
// * The bar is a button — tapping it fires its `onTap` (which, in the
//   real shell, pushes `/search`).
// * The bar carries a search affordance (icon + placeholder hint) so a
//   fresh user reads it as "tap to search".
// * Tapping the bar does NOT itself put a TextField in focus (there is no
//   TextField on the bar any more) — the keyboard comes up on the pushed
//   page, asserted by its own autofocus.
//
// The page's field autofocus is exercised by the full-shell integration
// test sketched at the bottom of this file; until that lands, the live
// on-device smoke test is the regression gate for "tap bar → page →
// keyboard up and stays up".

import 'package:differentworld/features/omnibox/bottom_omnibox_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BottomOmniboxBar widget — isolated', () {
    Widget mount({required VoidCallback onTap}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: BottomOmniboxBar(onTap: onTap),
          ),
        ),
      );
    }

    testWidgets('tapping the bar fires onTap (it is a button, not a field)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(mount(onTap: () => taps++));

      // The whole pill is one tap target — tap the search glyph.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      expect(
        taps,
        equals(1),
        reason:
            'The bar is a tap-target that pushes /search; its '
            'onTap must fire on tap. (CLAUDE.md interaction rule: '
            'a tap must dispatch, never a silent no-op.)',
      );
    });

    testWidgets('the bar has NO editable field (input lives on the page)', (
      tester,
    ) async {
      await tester.pumpWidget(mount(onTap: () {}));

      expect(
        find.byType(TextField),
        findsNothing,
        reason:
            'The editable composer field moved onto the /search '
            'page (autofocused). The bar must not host a TextField — '
            'that is what made the cross-route focus handoff tear down '
            'the IME in the old design.',
      );
    });

    testWidgets('the bar shows a search affordance (icon + placeholder hint)', (
      tester,
    ) async {
      await tester.pumpWidget(mount(onTap: () {}));

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(
        find.textContaining('Search anything'),
        findsOneWidget,
        reason:
            'A fresh user must read the pill as a search box even '
            'though it is a button — the placeholder hint carries that.',
      );
    });

    testWidgets('the bar exposes a Semantics button for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(mount(onTap: () {}));

      // The pill renders ONE merged button node (InkWell + the explicit
      // Semantics). Match by RegExp because the node's label merges the
      // "Search" label with the placeholder hint text — both are read to
      // the user, which is fine; what matters is a tappable button
      // labelled with "Search". (a11y invariant.)
      expect(
        find.bySemanticsLabel(RegExp('Search')),
        findsOneWidget,
        reason:
            'The tap-target must announce itself as a button to '
            'VoiceOver / TalkBack.',
      );
      handle.dispose();
    });
  });

  // TODO(integration): A full-shell test that:
  //   1. Mounts AppShell with a real go_router (`/` → stub home,
  //      `/search` → OmniboxSearchScreen)
  //   2. Overrides viewerProvider, omniboxCatalogProvider, groupsProvider,
  //      subjectsInSpaceProvider, activitiesProvider, locationsProvider,
  //      vehiclesProvider, membersInSpaceProvider with minimal fakes
  //   3. `tester.tap(find.byType(BottomOmniboxBar))` → asserts `/search`
  //      pushed
  //   4. After `pumpAndSettle()`, asserts the search page's TextField
  //      holds primary focus (autofocus raised the IME) — the
  //      Wave-back-to-route guarantee that the keyboard comes up AND stays
  //      up because the field is on the page (no cross-route handoff).
  //   5. `tester.enterText(..., 'a')` → the result sections rebuild.
  //   6. Tapping a suggestion pops `/search` and dispatches the entry's
  //      action via the captured root-navigator context.
  //
  // It's bigger than the others (provider wiring is invasive) and is left
  // as a follow-up — until then, the live on-device smoke test is the
  // regression gate.
}
