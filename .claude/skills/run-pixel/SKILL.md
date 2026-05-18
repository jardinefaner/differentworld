---
name: run-pixel
description: Launch the app on the user's Pixel 6 wireless. Default run target per saved memory.
---

# /run-pixel — launch on Pixel 6 wireless

Default run target per the user's memory:

```bash
flutter run -d adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp
```

Run in the background via the Bash tool's `run_in_background: true` so
the conversation can continue. Tee to `/tmp/dw-pixel.log` for later
inspection.

## If the Pixel isn't reachable

```bash
flutter devices
```

If the Pixel doesn't show, tell the user — don't silently fall back to
Chrome or macOS. The Pixel is the primary testing surface.

## After native changes

```bash
flutter clean && flutter pub get
flutter run -d adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp
```

Native dep additions, manifest changes, Info.plist changes, build_runner
output changes that touch generated registrants — all need the clean.

## Common log signatures

- `Validated and applied checkpoint` — PowerSync sync round-trip succeeded
- `Skipped N frames` — main-thread blockage; rare for debug, investigate if continuous
- `Lost connection to device` — phone went to sleep / out of WiFi range, not a crash
