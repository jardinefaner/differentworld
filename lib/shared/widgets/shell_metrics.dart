/// Vertical space the persistent shell (AppShell) reserves at the
/// top and bottom of every signed-in screen so no content ever
/// renders under the chrome pills or the omnibox bar.
///
/// **The layout law (every screen, every state):**
///
/// - Top of body content paints below [topChromeHeight] on first
///   render — never under the hamburger / back / actions pills.
/// - Bottom of body content, when scrolled to `maxScrollExtent`,
///   ends above [bottomOmniboxHeight] — never behind the omnibox.
/// - Centered widgets (loading spinner, EmptyState, NoAccess)
///   center inside the `(topChromeHeight, bottomOmniboxHeight)`
///   visible slot rather than the raw viewport.
/// - In kid mode the shell hides the chrome AND the omnibox; both
///   insets drop to 0 so the kid surface fills the viewport.
///
/// These are constants for now; when the chrome row stacks
/// dynamically (e.g. a second pill row) they can be replaced by
/// values read off the chrome stack. Centralized here so an opt-out
/// screen (full-bleed photo viewer, etc.) can reference the same
/// numbers it's choosing to skip.
abstract class ShellMetrics {
  /// Space the top chrome (hamburger + back arrow + per-route action
  /// pills) claims below the status bar. Body content paints below
  /// this; the omnibox suggestion panel pads-top by this so it
  /// never extends under the pills.
  static const double topChromeHeight = 56;

  /// Space the persistent bottom omnibox bar claims above the home
  /// indicator. Body content + omnibox suggestion panel both pad-
  /// bottom by this when the bar is visible.
  static const double bottomOmniboxHeight = 76;
}
