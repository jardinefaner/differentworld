/// Vertical space the persistent shell (AppShell) reserves so no
/// content ever permanently sits behind the chrome pills or the
/// omnibox bar.
///
/// **The layout law (every screen, every state), Wave 52 revision:**
///
/// - Body content extends EDGE-TO-EDGE from the screen top down.
///   The floating chrome pills (hamburger / back / actions) are
///   translucent glass overlays — list content scrolls THROUGH the
///   chrome strip rather than stopping below it. Earlier revision
///   padded the body by [topChromeHeight] which produced a visible
///   solid-coloured strip at top that read as an opaque appbar.
/// - Bottom of body content, when scrolled to `maxScrollExtent`,
///   ends above [bottomOmniboxHeight] — never permanently behind
///   the omnibox bar. Routes that author their own scrollables can
///   layer their bottom padding on top of this.
/// - Centered widgets (loading spinner, EmptyState, NoAccess)
///   center inside `(0, bottomOmniboxHeight)` slot. The chrome at
///   the top is the only thing that overlaps centered content.
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
}
