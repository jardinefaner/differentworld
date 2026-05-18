---
name: no-print-statements
description: Use debugPrint or a properly-gated logger, never raw print(). Triggered when adding logging.
---

# `debugPrint`, not `print`

`print()` writes to stdout uncontrollably and is throttled differently
across platforms. `debugPrint()` is the Flutter idiom — async, throttled,
properly behaves in profile/release.

## Right

```dart
import 'package:flutter/foundation.dart';

debugPrint('[sync] uploaded $count rows');
```

## With PII / sensitive info

Wrap in `kDebugMode` so the line is stripped in profile/release:

```dart
if (kDebugMode) {
  debugPrint('[connector] token prefix: ${session.accessToken.substring(0, 16)}');
}
```

## Wrong

```dart
print('[sync] uploaded $count rows');  // ✗ stdout-blasting
```

## Avoid `debugPrint` in tight loops

Per-frame `debugPrint` is async but still costs frame time in debug
builds. We learned this the hard way with the `[currentMember] watch
emitted` line that printed on every sync emission.

If you need per-event logs in a hot path:

```dart
if (kDebugMode && rowCount > 0) {
  debugPrint('[connector] $rowCount rows uploaded');
}
```

Gate the print itself, not just the body.

## Error reporting

For exceptions, route through `FlutterError.reportError` so they appear
in DevTools and any future crash-reporting integration:

```dart
} on Exception catch (e, st) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: e,
      stack: st,
      library: 'feature-name',
      context: ErrorDescription('Brief context'),
    ),
  );
  // ... user-facing fallback
}
```

## Production logger

We don't have one wired yet. Sentry is in CLAUDE.md's deferred list.
For now, `debugPrint` + `FlutterError.reportError` is the contract.
