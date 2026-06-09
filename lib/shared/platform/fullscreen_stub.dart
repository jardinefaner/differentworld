/// Non-web fallback: native present surfaces already fullscreen via
/// `SystemChrome.immersiveSticky`, so there's no separate toggle to offer.
bool get webFullscreenSupported => false;

/// Whether the browser is currently in fullscreen. Always false off web.
bool get isWebFullscreen => false;

/// Toggle browser fullscreen — a no-op off web.
Future<void> toggleWebFullscreen() async {}
