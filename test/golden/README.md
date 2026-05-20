# Golden tests

Per-screen visual regression matrix. Each golden renders one screen
at 4 breakpoints (phone-portrait / phone-landscape / tablet-portrait /
desktop). The PNG output is checked into the repo at
`test/golden/goldens/`; CI fails on any pixel diff.

## Running

```sh
# Verify against the checked-in goldens (CI uses this)
flutter test test/golden/

# Regenerate goldens after a deliberate UI change
flutter test --update-goldens test/golden/
```

Always review the regenerated PNG diff before committing — a stray
spacing change or wrong-color regression is exactly the thing this
suite catches.

## Adding a new screen

1. Create `test/golden/<screen>_test.dart`. Use `login_test.dart` as
   the template.
2. Call `goldenAtAllBreakpoints('<screen>', build: () => MyScreen())`.
3. If the screen reads Riverpod providers, pass an `overrides`
   closure with fakes:

   ```dart
   goldenAtAllBreakpoints(
     'today',
     build: () => const TodayScreen(),
     overrides: () => [
       viewerProvider.overrideWith((_) => _fakeViewer),
       insightsProvider.overrideWith((_) => Stream.value([])),
     ],
   );
   ```

4. Run `flutter test --update-goldens` to generate the initial PNGs.
5. Eyeball the PNGs (`open test/golden/goldens/`) to confirm they
   look right.
6. Commit both the test and the PNGs.

## What to mock

The provider overrides should set up a STABLE, MINIMAL world — the
golden has to be deterministic. Avoid:
- Anything with a Timer (animations not pumped)
- Provider streams that emit async
- DateTime.now() — pin a fixed time via `Clock.fixed`

For each screen, document the mocked world INSIDE the test file as
comments. Future regressions caused by mock drift become traceable.

## Coverage targets

| Screen | Status |
|---|---|
| Login | ✅ (template) |
| Today | TODO |
| Today (empty) | TODO |
| Insights list | TODO |
| Capture inbox | TODO |
| Capture inbox (empty) | TODO |
| Group detail | TODO |
| Attendance | TODO |
| Observation feed | TODO |
| Observation form sheet | TODO |
| Subject detail | TODO |
| Survey take (kid mode) | TODO |
| Settings | TODO |
| Team list | TODO |
| Schedule grid | TODO |
| Vehicles list | TODO |
| Family today (guardian) | TODO |

Each row should be its own `<screen>_test.dart`. Adding 16 screens is
a multi-session effort; do them as we touch each surface.

See `docs/SCREEN_QA_MATRIX.md` for the per-screen expectation list
that informs WHAT the golden should show in each state.
