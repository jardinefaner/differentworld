/// Vertical space the persistent shell (AppShell) reserves so no
/// content ever permanently sits behind the bottom omnibox bar.
///
/// **The layout law (every screen, every state), Wave 53 revision:**
///
/// - Body content fills the entire Scaffold area — TRULY edge-to-edge,
///   no SafeArea wrapper, no top padding. Content extends behind the
///   system status bar (transparent overlay, icons paint over the
///   content with theme-appropriate contrast) AND behind the
///   floating chrome pills (translucent glass overlays).
/// - The first scrollable item that should be visible on initial
///   paint — typically the screen's `ContentHeader` — reserves
///   `statusBarInset + topChromeHeight + topGap` for itself so the
///   title doesn't sit under chrome. ContentHeader handles this
///   internally; one place that knows about chrome.
/// - Bottom of body content, when scrolled to `maxScrollExtent`,
///   ends above [bottomOmniboxHeight] — never permanently behind
///   the omnibox bar. AppShell pads the route content's bottom by
///   this; routes don't need to add it manually.
/// - Centered widgets (loading spinner, EmptyState, NoAccess) sit
///   in the natural viewport center. Floating chrome may overlap
///   them; the chrome's glass blur keeps them readable.
/// - In kid mode the shell hides the chrome AND the omnibox; the
///   bottom inset drops to 0 so the kid surface fills the viewport.
///
/// Centralized here so an opt-out screen (full-bleed photo viewer,
/// etc.) can reference the same numbers it's choosing to skip.
abstract class ShellMetrics {
  /// Effective height of the top chrome pill row (hamburger + back +
  /// per-route actions) measured from below the status bar. Used by
  /// the omnibox suggestion panel to pad-top so it doesn't extend
  /// behind the pills. Body content no longer pads by this — it
  /// extends edge-to-edge and the pills float as glass over it.
  static const double topChromeHeight = 56;

  /// Space the persistent bottom omnibox bar claims above the home
  /// indicator. Body content + omnibox suggestion panel both pad-
  /// bottom by this when the bar is visible.
  static const double bottomOmniboxHeight = 76;

  /// Height of the LIVE block strip when a block is live (it collapses to
  /// zero otherwise). It floats OVER route content just above the omnibox
  /// bar — scrolling content passes under it by design, but a screen with a
  /// FIXED bottom control (a chat composer, a stage's control bar) must add
  /// this much clearance when a block is live or the strip covers the
  /// control (the message-thread composer bug, 2026-08-20).
  static const double liveStripHeight = 36;
}
