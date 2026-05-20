import 'package:differentworld/features/auth/login_screen.dart';

import '_helpers.dart';

/// Login screen — the simplest golden in the matrix. No providers
/// to override; the screen is content-only and renders identically
/// regardless of viewer state.
///
/// Use this as the template for new golden tests:
///   1. New file `test/golden/<screen>_test.dart`
///   2. Call `goldenAtAllBreakpoints('<screen>', build: ...)` from
///      `main()`.
///   3. For screens that need provider overrides, return a manually-
///      constructed `ProviderScope(overrides: [...], child:
///      MaterialApp(home: MyScreen()))` from the build closure. The
///      `wrapForGolden` helper is the no-overrides shorthand.
void main() {
  goldenAtAllBreakpoints(
    'login',
    build: () => wrapForGolden(const LoginScreen()),
  );
}
