---
name: cupertino-transitions
description: All platforms use CupertinoPageTransitionsBuilder via the theme. Don't override per-route; don't reintroduce Zoom or FadeForwards builders. Triggered when modifying themes or route transitions.
---

# Cupertino transitions on every platform

`lib/app/theme.dart` pins both `buildLightTheme()` and `buildDarkTheme()`
to `CupertinoPageTransitionsBuilder` on Android, iOS, macOS, Linux, and
Windows.

Material's defaults (ZoomPageTransitionsBuilder on Android, M3's
FadeForwardsPageTransitionsBuilder) are 300–500 ms and feel sluggish
on 60 Hz panels. The iOS slide is ~350 ms with a tight curve and reads
as snappy under load. Bonus: the slide composes with Android 14+
predictive back gesture for free.

## Don't reintroduce

- Per-route `CustomTransitionPage` with `PageTransitionsBuilder` overrides
- `PageRouteBuilder` with manual `SlideTransition`
- `MaterialPageRoute(maintainState: false)` — kills the back stack

## When a screen wants something different

In practice, never. The handful of cases where it might make sense
(modal full-screen photo viewer, etc.) belong on `showDialog` or
`Navigator.of(context).push(PageRouteBuilder(...))` with `opaque: false`
— not via the global theme.

## Pair with

- `push-not-go` — `push` is what triggers the transition
- `floating-back-only` — back via swipe gesture or floating pill
