---
name: kid-mode
description: Opt a screen into "kid mode" — AppShell strips its omnibox bar, top chrome, and drawer so a kid handed the device can't escape to staff-facing routes. Used by survey-take; future kid-journal will too. Triggered when adding a kid-facing surface.
---

# Kid mode — lockdown for kid surfaces

When a screen is built for a kid to use directly (survey-take,
future kid-journal), staff-facing affordances are an escape hatch
into the rest of the app. Kid mode locks them out.

## What it does

`kidModeProvider` is a `Notifier<bool>` in
`lib/features/kid_mode/kid_mode_provider.dart`. When `true`,
AppShell:

- Hides the bottom omnibox bar
- Hides the top chrome (back / hamburger / actions / topOverlay)
- Hides the drawer (Scaffold.drawer set to null)
- Drops the 76 dp bottom inset on widget.child (the kid surface
  fills the screen)

The kid sees ONLY the route's body. No way to navigate without
staff intervention.

## Opt a screen into kid mode

```dart
class MyKidScreen extends ConsumerStatefulWidget {
  // ...
}

class _MyKidScreenState extends ConsumerState<MyKidScreen> {
  @override
  void initState() {
    super.initState();
    // Defer so we don't write during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(kidModeProvider.notifier).enter();
    });
  }

  @override
  void dispose() {
    // Drop the lock when the screen pops. The CALLER (a staff user)
    // is the one who normally pops — if a kid taps system back, we
    // need a guarded exit gesture instead (TODO below).
    ref.read(kidModeProvider.notifier).exit();
    super.dispose();
  }
}
```

## Currently using

- `lib/features/surveys/survey_take_screen.dart` — auto-enters on
  initState, exits on dispose.

## Still TODO

The mechanism is in place but the staff-only exit is NOT. Today's
flow assumes only staff can launch the kid surface; system back +
navigator pop both unlock implicitly via dispose. For surfaces a
kid might launch (kid-journal, future activity check-ins), we need:

1. **Intercept system back** — PopScope inside the kid screen that
   refuses to pop unless the user passes the staff gate.
2. **A staff-only exit** — 5-tap on a hidden corner, OR a PIN
   dialog. The mechanism + UI is future work.
3. **Disable the drawer swipe** — currently Scaffold.drawer is null
   in kid mode so the swipe is a no-op. Verify.

Track in CLAUDE.md persona "Ava" section.

## Don't

- Don't enter kid mode from a screen that staff also uses (e.g.
  attendance, observation form). Those need the omnibox bar.
- Don't forget to `exit()` in dispose — leaving kid mode on after
  the screen pops would lock out staff from the entire app.
- Don't put kid mode inside a modal sheet — sheets don't dispose
  cleanly during navigation and the lock could survive past intent.
- Don't render staff affordances inside the body of a kid surface —
  the kid surface is the WHOLE thing the kid sees.
