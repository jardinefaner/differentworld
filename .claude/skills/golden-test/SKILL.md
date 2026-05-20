---
name: golden-test
description: Add a golden-test for a new screen — PNGs at 4 breakpoints (phone-portrait / phone-landscape / tablet-portrait / desktop) checked into the repo, CI fails on pixel diff. Use the `goldenAtAllBreakpoints` helper. Triggered when adding a new screen or when a refactor touches the chrome layer.
---

# /golden-test — add a screen to the visual regression matrix

`test/golden/` holds the matrix. Each screen has its own
`<screen>_test.dart` that pumps the widget at every breakpoint and
asserts the rendered PNG matches the checked-in golden.

## Adding a screen

1. Create `test/golden/<name>_test.dart`:

   ```dart
   import 'package:differentworld/features/foo/foo_screen.dart';
   import '_helpers.dart';

   void main() {
     goldenAtAllBreakpoints(
       'foo',
       build: () => wrapForGolden(const FooScreen()),
     );
   }
   ```

2. For screens that read Riverpod providers, build the tree inline
   with overrides (Override isn't publicly exported by
   flutter_riverpod so the helper doesn't take a typed list):

   ```dart
   import 'package:differentworld/app/theme.dart';
   import 'package:flutter/material.dart';
   import 'package:flutter_riverpod/flutter_riverpod.dart';
   import '_helpers.dart';

   void main() {
     goldenAtAllBreakpoints(
       'today',
       build: () => ProviderScope(
         overrides: [
           viewerProvider.overrideWith((_) => _fakeViewer),
           insightsProvider.overrideWith((_) => Stream.value(const [])),
           groupsProvider.overrideWith((_) => Stream.value(const [])),
         ],
         child: MaterialApp(
           theme: buildLightTheme(),
           debugShowCheckedModeBanner: false,
           home: const TodayScreen(),
         ),
       ),
     );
   }
   ```

3. Generate the initial PNGs:

   ```sh
   flutter test --update-goldens test/golden/<name>_test.dart
   ```

4. Eyeball them at `test/golden/goldens/<name>__*.png`. If they
   look right, commit both the test and the PNGs.

## What to mock

The provider overrides should set up a STABLE, MINIMAL world — the
golden must be deterministic. Avoid:
- Anything with a Timer (animations not pumped)
- Provider streams that emit async
- `DateTime.now()` — pin a fixed time at the call site

For each screen, document the mocked world INSIDE the test file as
comments. Mock drift causes regressions; tracing it later is
expensive.

## Reading the matrix

The four breakpoints:

| Key | Size | Persona target |
|---|---|---|
| phone-portrait | 390 × 844 | iPhone 15 |
| phone-landscape | 844 × 390 | rotated |
| tablet-portrait | 1024 × 1366 | 12.9" iPad |
| desktop | 1440 × 900 | 13" laptop |

PNG filename: `goldens/<screen>__<breakpoint>.png`. The double
underscore is the breakpoint sentinel — grep for `<screen>__` to
find every variant.

## CI

Goldens run via `flutter test test/golden/` (no `--update-goldens`).
Any pixel diff fails the build. Update-and-commit when the diff is
intentional; explain WHY in the commit message.

## Coverage targets

See `test/golden/README.md` for the per-screen status table.
Adding all 16 listed screens is a multi-session effort — do them as
you touch each surface, not in one big sweep.

## When NOT to add a golden

- Screens whose entire content is a third-party widget (CameraPreview,
  WebView) — pixel diffing them is brittle.
- Screens that depend on real-world data (e.g. a live attendance
  count) — mock the data first or skip the golden.
- Modal sheets / dialogs — these belong in widget tests, not goldens.

## Implementation pointers

- `test/golden/_helpers.dart` — `goldenAtAllBreakpoints`,
  `wrapForGolden`, `pumpAt`, `expectGolden`
- `test/golden/README.md` — onboarding doc + status table
- `test/golden/login_test.dart` — the simplest working template
- `docs/SCREEN_QA_MATRIX.md` — per-screen state × expectation that
  drives what the goldens should show
