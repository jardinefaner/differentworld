import 'package:flutter/foundation.dart';

/// True only on native mobile (Android / iOS) — the platforms with a
/// usable in-app **camera / QR scanner**. Web and desktop (macOS /
/// Windows / Linux) have no reliable camera plugin: web camera needs
/// flaky `getUserMedia` over HTTPS, and the desktop `camera` /
/// `mobile_scanner` plugins have no implementation at all.
///
/// Capture affordances gate on this and fall back to file pickers /
/// manual entry off-mobile, so a desktop user never taps a dead
/// "Take a photo" / "Scan QR" button (docs/PLATFORM_RUBRIC.md, P1).
///
/// Note `kIsWeb` is checked first: on mobile web `defaultTargetPlatform`
/// reports android/iOS, but web capture still goes through the flaky
/// `getUserMedia` path we're avoiding, so web is always `false` here.
bool get isMobileCapturePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
