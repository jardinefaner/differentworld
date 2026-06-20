import 'package:differentworld/shared/widgets/shell_back_action.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression net for the AppShell back / swipe model (docs/NAV_MIGRATION.md).
///
/// The bugs this pins:
///   • "back / swipe exits the app from a non-home screen" — a top-level
///     route reached via `go` leaves an empty shell stack; back must route
///     HOME, never exit.
///   • "back goes to a screen I never visited" — same root cause; the fix
///     is the same predictable go-home fallback.
/// Both stemmed from deciding off the unreliable `matchedLocation`; the
/// shell now feeds the real shell-navigator `canPop()` into this table.
///
/// **Wave-back-to-route (2026-06-20)**: the omnibox search surface is a
/// real `/search` route now, so there is no overlay for back to "close" —
/// the `closeOverlay` action + `overlayOpen` input were removed. A back
/// gesture on `/search` is an ordinary `systemPop` (the route is on the
/// shell navigator's stack, so `shellCanPop` is true).
void main() {
  group('decideShellBack', () {
    test('a real drill-in pops normally', () {
      expect(
        decideShellBack(
          shellCanPop: true,
          inKidMode: false,
          atHomeRoot: false,
        ),
        ShellBackAction.systemPop,
      );
    });

    test('a pushed route while AT home still pops (does not exit)', () {
      expect(
        decideShellBack(
          shellCanPop: true,
          inKidMode: false,
          atHomeRoot: true,
        ),
        ShellBackAction.systemPop,
      );
    });

    test('the /search route pops like any other pushed route', () {
      // /search is now a real route on the shell navigator's stack, so
      // back on it is an ordinary pop — no special overlay-close branch.
      expect(
        decideShellBack(
          shellCanPop: true,
          inKidMode: false,
          atHomeRoot: false,
        ),
        ShellBackAction.systemPop,
      );
    });

    test('kid-mode locked surface is a no-op (cannot escape via back)', () {
      expect(
        decideShellBack(
          shellCanPop: false,
          inKidMode: true,
          atHomeRoot: false,
        ),
        ShellBackAction.kidModeNoop,
      );
    });

    test(
      'THE FIX: top-level route, nothing to pop, not home → go HOME not exit',
      () {
        expect(
          decideShellBack(
            shellCanPop: false,
            inKidMode: false,
            atHomeRoot: false,
          ),
          ShellBackAction.goHome,
        );
      },
    );

    test('at a home root with nothing to pop → confirm exit', () {
      expect(
        decideShellBack(
          shellCanPop: false,
          inKidMode: false,
          atHomeRoot: true,
        ),
        ShellBackAction.confirmExit,
      );
    });
  });

  group('shellShouldAllowSystemPop', () {
    test('true exactly when the shell can pop', () {
      expect(
        shellShouldAllowSystemPop(shellCanPop: true),
        isTrue,
      );
      expect(
        shellShouldAllowSystemPop(shellCanPop: false),
        isFalse,
      );
    });

    test(
      'invariant: when system pop is allowed, the decision IS systemPop',
      () {
        for (final inKidMode in [true, false]) {
          for (final atHomeRoot in [true, false]) {
            // shellCanPop=true → allow == true
            expect(
              shellShouldAllowSystemPop(shellCanPop: true),
              isTrue,
            );
            expect(
              decideShellBack(
                shellCanPop: true,
                inKidMode: inKidMode,
                atHomeRoot: atHomeRoot,
              ),
              ShellBackAction.systemPop,
            );
          }
        }
      },
    );
  });
}
