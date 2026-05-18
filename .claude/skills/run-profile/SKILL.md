---
name: run-profile
description: Launch on the Pixel in profile mode (AOT, no debug overhead) for feel-testing animations and perf. Use when the user complains about lag in debug builds.
---

# /run-profile — Pixel in profile mode

Debug mode is 3-5× slower than profile mode. If the user complains the
app feels laggy, the first move is to ship in profile, not to chase
phantom perf issues in the debug build.

```bash
flutter run --profile -d adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp
```

## Profile mode quirks

- **Hot reload disabled** (`r` does nothing, `R` triggers a full restart)
- **DevTools still works** for inspector + perf overlay
- **Assertions stripped** but Riverpod's `ProviderObserver` still logs
- **kDebugMode is false** → any code wrapped in `if (kDebugMode) {...}`
  is omitted (e.g. the connector's token-prefix debugPrint)

## When to use

- "Feels laggy" → try profile first, fix only if still bad
- Animation timing comparisons (Cupertino transitions, AnimatedSwitcher)
- Frame budget testing (60 fps with overlay enabled)
- Before declaring a screen "feels good" — debug build feel is a lie

## When debug is right

- Iterating on code (you want hot reload)
- Debugging async / sync bugs (asserts catch more)
- Verifying that the kDebugMode-gated debugPrints fire as intended
