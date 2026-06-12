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
void main() {
  group('decideShellBack', () {
    test('a real drill-in pops normally', () {
      expect(
        decideShellBack(
          shellCanPop: true,
          overlayOpen: false,
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
          overlayOpen: false,
          inKidMode: false,
          atHomeRoot: true,
        ),
        ShellBackAction.systemPop,
      );
    });

    test('the overlay always wins — even when the stack could pop', () {
      expect(
        decideShellBack(
          shellCanPop: true,
          overlayOpen: true,
          inKidMode: false,
          atHomeRoot: false,
        ),
        ShellBackAction.closeOverlay,
      );
      expect(
        decideShellBack(
          shellCanPop: false,
          overlayOpen: true,
          inKidMode: true,
          atHomeRoot: true,
        ),
        ShellBackAction.closeOverlay,
      );
    });

    test('kid-mode locked surface is a no-op (cannot escape via back)', () {
      expect(
        decideShellBack(
          shellCanPop: false,
          overlayOpen: false,
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
            overlayOpen: false,
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
          overlayOpen: false,
          inKidMode: false,
          atHomeRoot: true,
        ),
        ShellBackAction.confirmExit,
      );
    });
  });

  group('shellShouldAllowSystemPop', () {
    test('true only when the shell can pop and no overlay is open', () {
      expect(
        shellShouldAllowSystemPop(shellCanPop: true, overlayOpen: false),
        isTrue,
      );
      expect(
        shellShouldAllowSystemPop(shellCanPop: true, overlayOpen: true),
        isFalse,
      );
      expect(
        shellShouldAllowSystemPop(shellCanPop: false, overlayOpen: false),
        isFalse,
      );
    });

    test(
      'invariant: when system pop is allowed, the decision IS systemPop',
      () {
        for (final inKidMode in [true, false]) {
          for (final atHomeRoot in [true, false]) {
            // overlayOpen=false, shellCanPop=true → allow == true
            expect(
              shellShouldAllowSystemPop(shellCanPop: true, overlayOpen: false),
              isTrue,
            );
            expect(
              decideShellBack(
                shellCanPop: true,
                overlayOpen: false,
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
