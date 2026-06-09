import 'package:web/web.dart' as web;

/// Web supports a real Fullscreen-API toggle.
bool get webFullscreenSupported => true;

/// Whether the document is currently presented fullscreen.
bool get isWebFullscreen => web.document.fullscreenElement != null;

/// Toggle the whole document in/out of fullscreen. Must be called from a user
/// gesture (a button tap) — the browser rejects programmatic requests
/// otherwise. The returned JSPromises are intentionally fire-and-forget.
Future<void> toggleWebFullscreen() async {
  final doc = web.document;
  if (doc.fullscreenElement != null) {
    doc.exitFullscreen();
  } else {
    doc.documentElement?.requestFullscreen();
  }
}
