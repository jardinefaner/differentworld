/// True browser fullscreen, web-only.
///
/// On native platforms (iOS / Android / desktop) the present surfaces already
/// go fullscreen via `SystemChrome.setEnabledSystemUIMode(immersiveSticky)`, so
/// there's nothing to do — these are no-ops. The affordance only matters in a
/// browser tab: a teacher casting a present surface (Play today, the journey, a
/// child's growth arc) from a laptop to a TV / projector wants the browser
/// chrome (tabs, address bar) gone. `immersiveSticky` can't do that on web; the
/// Fullscreen API can, but only from a user gesture — so it's wired to a button.
///
/// The web implementation lives in `fullscreen_web.dart` (uses `package:web`);
/// everything else gets the `fullscreen_stub.dart` no-ops.
library;

export 'fullscreen_stub.dart'
    if (dart.library.js_interop) 'fullscreen_web.dart';
