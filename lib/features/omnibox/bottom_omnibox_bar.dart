import 'dart:ui';

import 'package:differentworld/features/omnibox/omnibox_mode.dart';
import 'package:flutter/material.dart';

/// The persistent bottom strip — multi-modal composer. Lives in the
/// AppShell as a `bottomNavigationBar`-style fixture so it rides above
/// the system keyboard inset, stays visible across page transitions,
/// and gives the user a thumb-zone-reachable spine (think ChatGPT /
/// Claude / Gemini composer).
///
/// The bar is purely presentational — it owns no state beyond the
/// text controller and focus node it's handed. The AppShell decides
/// what "focused" means (it overlays the results panel above the bar
/// when the field gains focus) AND what [mode] the composer is in
/// (search vs capture, computed from the query + catalog via
/// [detectMode]).
///
/// Visuals morph with mode:
///   - Search: search-glass leading icon + "Search anything…" hint
///   - Capture: lightning-bolt leading icon + "Save a quick note…"
///     hint + a faint primary-tinted background so the user sees the
///     mode shift before they hit Enter
class BottomOmniboxBar extends StatelessWidget {
  const BottomOmniboxBar({
    required this.controller,
    required this.focusNode,
    required this.mode,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
    required this.onMicTap,
    required this.onCollapse,
    this.voiceActive = false,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Current detected mode. Drives the leading icon, hint text, and
  /// container tint.
  final OmniboxMode mode;

  final ValueChanged<String> onChanged;

  /// User hit return on the field. AppShell decides what to do based
  /// on the current [mode] — fire capture or open the top result.
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;
  final VoidCallback onMicTap;

  /// Tapped when the user wants to dismiss the expanded results
  /// panel and return to the page underneath. Routed to the leading-
  /// icon slot whenever the field is focused — gives the user a
  /// visible "back to page" affordance instead of relying on tapping
  /// outside the panel (which on phone is barely any pixels).
  final VoidCallback onCollapse;

  /// True while a voice-dictation session is live. The mic button
  /// renders as "stop" (filled red) and the bar shows a subtle
  /// "Listening…" badge so the user remembers the mic is open.
  final bool voiceActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasText = controller.text.isNotEmpty;
    final isFocused = focusNode.hasFocus;
    final isCapture = mode == OmniboxMode.capture;
    final isSlash = mode == OmniboxMode.slash;

    // Three-way visual: search (default), capture (primary tint +
    // lightning bolt), slash (tertiary tint + chevron). Each mode
    // gets a distinct hint so the user always knows what return
    // will do.
    Color containerColor;
    Color leadingTint;
    IconData leadingIcon;
    String hint;
    if (isCapture) {
      // Transparent fill — the page shows through the blur; the mode now reads
      // from the coloured border + the leading icon + the hint, not a tint.
      containerColor = Colors.transparent;
      // Solid bolt — matches the icon-weight vocabulary of the rest
      // of the bar (close, arrow_back) and the chrome pills.
      leadingIcon = Icons.bolt;
      leadingTint = scheme.primary;
      hint = 'Save a quick note — press return';
    } else if (isSlash) {
      containerColor = Colors.transparent;
      // Terminal (solid, command-line semantic) — chevron_right was
      // the lone outlined/navigation-style outlier among the bar's
      // otherwise-solid icon vocabulary. Terminal also reads "slash
      // command" more clearly than a directional chevron.
      leadingIcon = Icons.terminal;
      leadingTint = scheme.tertiary;
      hint = 'Slash command — type /today, /log, /attendance…';
    } else {
      // Transparent fill — no colour behind the bar; the page shows through
      // the blur. Matches the top chrome's GlassPill (now tint-free too), so
      // the bar and the action pill read consistently against the page body.
      containerColor = Colors.transparent;
      leadingIcon = Icons.search;
      // `onSurfaceVariant` (not `onSurface`) by design — the
      // unfocused bar glyph is a de-emphasized placeholder, NOT a
      // foregrounded action like the chrome pills' `arrow_back`
      // (which uses `onSurface`). Same M3 vocabulary, different
      // roles.
      leadingTint = scheme.onSurfaceVariant;
      hint = 'Search anything — pages, actions, kids…';
    }
    final Color borderColor;
    if (isCapture) {
      borderColor = scheme.primary;
    } else if (isSlash) {
      borderColor = scheme.tertiary;
    } else if (isFocused) {
      borderColor = scheme.primary.withValues(alpha: 0.4);
    } else {
      borderColor = Colors.transparent;
    }

    // Floating glass — same vocabulary as the top chrome's GlassPill.
    // Outer Material is fully transparent so the bar reads as one
    // hovering pill against the page body, not an M3 bottom-bar
    // strip cutting the screen. The inner AnimatedContainer's
    // BackdropFilter provides the blur; the container's `color`
    // (already a tinted/translucent value per mode) gives the visual
    // chrome. Adds a small bottom padding so the pill genuinely
    // floats above the OS gesture nav rather than seating against
    // the bezel.
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        // Wave 107: Align.bottomCenter so the 720dp pill centers in
        // the viewport instead of pinning to the bottom-LEFT edge of
        // a 1920px screen. AppShell positions this whole widget with
        // Positioned(left:0, right:0, bottom:0); without the Align,
        // the ConstrainedBox child rendered at top-start of that
        // stretched parent — leaving 1200dp of empty bar to its
        // right at desktop widths, which read as broken layout.
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: ConstrainedBox(
            // Cap the bar's content width on tablet / desktop so it
            // doesn't read as a giant strip; same center-cap the
            // overlay uses.
            constraints: const BoxConstraints(maxWidth: 720),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                // Same blur strength as GlassPill — keeps the look
                // consistent between the bar and the top action pill.
                // RepaintBoundary above (via ClipRRect+BackdropFilter
                // being a leaf in the route stack) keeps the blur
                // raster cached across body rebuilds.
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: borderColor,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  // Leading slot. When the field has focus the panel
                  // is open over the page — the leading icon morphs
                  // into a back-arrow so tapping it closes the panel
                  // and returns to the page. Otherwise it shows the
                  // mode glyph (search / bolt / chevron).
                  //
                  // Both branches occupy the same 48×48 footprint so
                  // the bar's leading slot doesn't visibly resize as
                  // focus toggles. The unfocused branch uses a plain
                  // `SizedBox` (not `IconButton(onPressed: null)`)
                  // because Material 3 dims disabled IconButtons to
                  // 38% opacity — that made the unfocused leading
                  // glyph visibly weaker than the focused back-arrow.
                  if (isFocused)
                    IconButton(
                      tooltip: 'Hide suggestions',
                      // `keyboard_hide` (not `arrow_back`) — this
                      // button collapses the open suggestion panel +
                      // dismisses the keyboard. `arrow_back` reads
                      // as "navigate back in the app stack," which
                      // this button does NOT do — the underlying
                      // page hasn't changed. Using the literal
                      // dismiss-keyboard glyph removes the semantic
                      // mismatch a fresh user would otherwise hit.
                      //
                      // Same `leadingTint` as the unfocused mode-
                      // glyph so there's no hue flip on focus
                      // toggle.
                      icon: Icon(Icons.keyboard_hide, color: leadingTint),
                      onPressed: onCollapse,
                    )
                  else
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: Icon(
                            leadingIcon,
                            key: ValueKey(leadingIcon),
                            color: leadingTint,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: onSubmit,
                      autocorrect: false,
                      textInputAction: isCapture
                          ? TextInputAction.done
                          : TextInputAction.search,
                      textCapitalization: isCapture
                          ? TextCapitalization.sentences
                          : TextCapitalization.none,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        // `isCollapsed: true` makes the TextField
                        // size to its content height (the text line
                        // height). With `contentPadding: zero`, the
                        // surrounding Row's `crossAxisAlignment:
                        // center` (Row's default) puts the text
                        // baseline at the vertical center of the
                        // 48dp icon row. Previously a `vertical: 14`
                        // contentPadding offset the baseline below
                        // the icon centers — looked misaligned even
                        // though every icon was the same size.
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: hint,
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  if (hasText && !voiceActive)
                    IconButton(
                      tooltip: 'Clear',
                      // Subordinate to the mic — clear is a
                      // destructive secondary action that shouldn't
                      // visually compete with the primary mode
                      // toggle next to it.
                      icon: Icon(
                        Icons.close,
                        color: scheme.onSurfaceVariant,
                      ),
                      onPressed: onClear,
                    ),
                  // Voice mic — toggles a live Deepgram dictation
                  // session. While listening, the icon flips to a
                  // filled "stop" + tinted error background so the
                  // user knows the mic is open. Tap again to commit.
                  IconButton(
                    tooltip: voiceActive
                        ? 'Stop dictation'
                        : 'Dictate by voice',
                    // Solid mic matches the rest of the bar's
                    // weight vocabulary (the outlined variant read
                    // ~15% lighter than its sibling icons).
                    icon: Icon(
                      voiceActive ? Icons.stop_circle : Icons.mic,
                      color: voiceActive ? scheme.error : null,
                    ),
                    onPressed: onMicTap,
                  ),
                ],
              ),
            ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
