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
      containerColor = scheme.primaryContainer.withValues(alpha: 0.45);
      leadingIcon = Icons.bolt_outlined;
      leadingTint = scheme.primary;
      hint = 'Save a quick note — press return';
    } else if (isSlash) {
      containerColor = scheme.tertiaryContainer.withValues(alpha: 0.55);
      leadingIcon = Icons.chevron_right;
      leadingTint = scheme.tertiary;
      hint = 'Slash command — type /today, /log, /attendance…';
    } else {
      containerColor = scheme.surfaceContainerHighest;
      leadingIcon = Icons.search;
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

    return Material(
      // Slight elevation + container tint so the bar reads as a
      // distinct surface against the page body above it. Matches the
      // M3 "bottom app bar" look without the heavy chrome.
      color: scheme.surface,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: ConstrainedBox(
            // Cap the bar's content width on tablet / desktop so it
            // doesn't read as a giant strip; same center-cap the
            // overlay uses.
            constraints: const BoxConstraints(maxWidth: 720),
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
                  if (isFocused)
                    IconButton(
                      tooltip: 'Back to page',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onCollapse,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Icon(
                          leadingIcon,
                          key: ValueKey(leadingIcon),
                          color: leadingTint,
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
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
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
                      icon: const Icon(Icons.close, size: 20),
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
                    icon: Icon(
                      voiceActive ? Icons.stop_circle : Icons.mic_none_outlined,
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
    );
  }
}
