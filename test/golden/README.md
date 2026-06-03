# Golden tests

Per-screen visual regression matrix. Each golden renders one screen
at 4 breakpoints (phone-portrait / phone-landscape / tablet-portrait /
desktop). The PNG output is checked into the repo at
`test/golden/goldens/`.

## These are LOCAL, on-demand checks — OFF by default

Golden rendering is environment-sensitive: font rasterization and
anti-aliasing differ across OS and Flutter versions, so a baseline
generated on one machine fails against another with a near-total pixel
diff (~98%) even when the screen hasn't changed. There is **no pinned
runner** for them (the only CI workflow is `deploy-web.yml`, which
deploys web and does not run tests), so treating them as a gate in the
default suite just made `flutter test` permanently red.

So they are **skipped unless `RUN_GOLDENS=1`** (see `runGoldens` in
`_helpers.dart`). Plain `flutter test` reports them as skipped and stays
green. The baselines are valid **on the machine that generated them** —
regenerate before you rely on them. If we ever want cross-machine
goldens, pin a runner (e.g. a Docker image in CI) and/or load a bundled
font via `flutter_test_config.dart`; font-loading alone is not enough
because Skia AA still differs per platform.

> **Determinism caveat (separate follow-up).** `login` is the only fully
> deterministic golden — it passes a regenerate→verify on the same
> machine. `insights` renders `DateTime.now()`-relative content (see the
> note in `insights_test.dart`) and `captures` / `tasks` drive off
> provider streams, so they can differ run-to-run even on one machine.
> Before those become reliable on-demand checks, pin time with
> `withClock(Clock.fixed(...))` and assert their streams emit a single
> synchronous value (see "What to mock" below). The PNGs in `goldens/`
> are NOT committed fresh — regenerate locally first.

## Running

```sh
# Default suite — goldens are SKIPPED (green even on a fresh machine)
flutter test

# Regenerate the baselines on YOUR machine after a deliberate UI change
RUN_GOLDENS=1 flutter test --update-goldens test/golden/

# Verify against the baselines you just generated
RUN_GOLDENS=1 flutter test test/golden/
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
