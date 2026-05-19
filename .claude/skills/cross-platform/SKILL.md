---
name: cross-platform
description: Web/desktop/mobile compatibility patterns. dart:io vs dart:html, kIsWeb gates, platform-conditional imports, plugin choices. Use when adding any feature that touches files, camera, location, notifications, or deep links.
---

# Cross-platform — six targets, one codebase

This app targets **iOS, iPadOS, Android, web, macOS, Windows, Linux**.
Every feature should run on every platform or degrade gracefully —
never crash and never disable a whole platform silently.

## Gate behaviors with `kIsWeb` + `Platform.is*`, not whole platforms

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;          // ← see "conditional imports" below

if (kIsWeb) {
  // web-specific path
} else if (Platform.isIOS) {
  // iOS-specific
} else if (Platform.isAndroid) {
  // Android-specific
}
```

**Layout gates** on width (`FormFactor.fromWidth(...)`, see
`responsive-breakpoints`), not on `Platform.is*`. iPad in landscape and
a small desktop window want the same two-column layout.

## `dart:io` is forbidden on web

Importing `dart:io` ANYWHERE the web build pulls in → web compile
fails. Two ways out:

### Option A — conditional imports

```dart
// foo.dart
import 'foo_stub.dart'
  if (dart.library.io) 'foo_io.dart'
  if (dart.library.html) 'foo_web.dart';
```

Use when the API surface is the same but the implementation differs
(file picker, secure storage, etc.).

### Option B — runtime kIsWeb guard

```dart
import 'package:flutter/foundation.dart';

Future<void> doFileThing() async {
  if (kIsWeb) {
    // call a web equivalent or no-op
    return;
  }
  // dart:io path — only reached on non-web
}
```

Use when the feature legitimately doesn't exist on web (e.g.
`Isolate.run` heavy crunching — web has different threading).

## Plugin choice — prefer cross-platform packages

Pick packages that already abstract platforms:

| Job | Package | Platforms |
|---|---|---|
| Image pick | `image_picker` | iOS / Android / web / desktop |
| Camera (preview) | `camera` | iOS / Android only — needs web fallback |
| Local storage | `flutter_secure_storage` + `shared_preferences` | all |
| HTTP | `dio` / `http` | all |
| Deep links | `app_links` | iOS / Android / macOS / web |
| Files | `path_provider` | iOS / Android / desktop (web has no FS) |

If a plugin doesn't support a platform, gate with `kIsWeb` and provide
a stub or an empty-state message ("Camera capture isn't available on
the web — upload an existing photo instead").

## Platform configuration files

| Platform | Where | What to register |
|---|---|---|
| iOS | `ios/Runner/Info.plist` | URL schemes, permissions (camera / location / notifications) |
| Android | `android/app/src/main/AndroidManifest.xml` | Intent filters, permissions, deep link hosts |
| macOS | `macos/Runner/Info.plist` + entitlements | Same as iOS + sandbox entitlements |
| Web | `web/index.html` + `web/manifest.json` | Service worker, manifest, icons |

When adding a permission-requiring feature, update ALL relevant
manifests in the same commit.

## Touch / mouse / keyboard

Every interactive element must support all three:

- **Touch**: Material/Cupertino widgets handle this.
- **Mouse**: wrap interactive elements in `MouseRegion` for cursor
  hints if the default isn't right.
- **Keyboard**: `Focus` + `Shortcuts` for non-trivial widgets; every
  primary action should be reachable via tab + enter.

Tap targets ≥ 48 dp **even on desktop**.

## Don't

- Don't import `dart:io` from a file the web build can reach.
- Don't gate features on `Platform.isMobile` (no such thing — use
  `kIsWeb ? web : mobile`).
- Don't ship a feature without testing on at least one non-default
  target (web in Chrome, or macOS desktop). The Pixel is the default
  but it can't catch web-only regressions.
- Don't rely on platform-channel side effects on web — they no-op
  silently. Wrap with `kIsWeb` guards.
