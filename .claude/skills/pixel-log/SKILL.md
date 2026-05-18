---
name: pixel-log
description: Tail adb logcat for the Different World app on the Pixel. Filtered to just our process.
---

# /pixel-log — adb logcat for the app

```bash
adb -s adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp logcat -v brief \
  --pid=$(adb -s adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp \
    shell pidof com.jardine.differentworld)
```

Or, simpler, just the Flutter `I/flutter` lines:

```bash
adb -s adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp logcat \
  -s flutter
```

## When useful

- The user reports an in-app issue without a stack
- Debugging PowerSync sync cycles (look for `[PowerSync]` lines)
- Checking that a deep link arrived (look for `[deeplink] received:`)
- Confirming that diagnostic prints are firing in profile builds (they
  shouldn't — `kDebugMode` gated)

## Streaming live during a session

Run with `run_in_background: true` and tail the output file. The
`flutter run` stdout is usually enough; logcat is only needed when
you've lost the run process or want platform-level lines.

## Stopping a runaway log

```bash
pkill -f "adb.*logcat"
```
