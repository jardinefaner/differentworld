import 'dart:ui';

import 'package:flutter/material.dart';

/// The persistent bottom strip — the app's "go anywhere" affordance.
/// Lives in the AppShell pinned above the system gesture inset so it
/// stays visible across page transitions and gives the user a thumb-
/// zone-reachable spine (think ChatGPT / Claude / Gemini composer).
///
/// **Wave-back-to-route (2026-06-20).** The bar used to BE the editable
/// composer: it owned the TextField, the mode tinting, voice mic, and the
/// AppShell overlaid a translucent suggestion panel above it on focus.
/// That overlay (a) made the back-swipe fall through to the app-exit
/// confirm and (b) read as hard-to-see frosted glass over the page.
///
/// Now the bar is a PRESENTATIONAL TAP-TARGET: a single [onTap] pushes
/// the real `/search` route, whose own autofocused field raises the
/// keyboard ("its own page, ready to type"). No TextField lives here any
/// more — so there is no cross-route focus handoff to tear down the IME,
/// and the search SURFACE is a solid `EdgeScaffold` page instead of glass.
///
/// What stays: the bar itself is still floating **transparent glass**
/// chrome (the permanent chrome law — the page body shows through edge to
/// edge). It reads as a search box via the leading icon + placeholder
/// hint, but it is a button, not a field.
class BottomOmniboxBar extends StatelessWidget {
  const BottomOmniboxBar({
    required this.onTap,
    super.key,
  });

  /// Tapped anywhere on the pill — AppShell pushes `/search`.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const hint = 'Search anything — pages, actions, kids…';

    // Floating glass — same vocabulary as the top chrome's GlassPill.
    // Outer Material is fully transparent so the bar reads as one
    // hovering pill against the page body, not an M3 bottom-bar strip
    // cutting the screen. The inner container's BackdropFilter provides
    // the blur; the fill stays transparent (the chrome law — the page
    // shows through edge to edge, never a tinted band). A small bottom
    // padding keeps the pill floating above the OS gesture nav rather
    // than seating against the bezel.
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        // Align.bottomCenter so the 720dp pill centers in the viewport
        // instead of pinning to the bottom-LEFT edge of a wide screen.
        // AppShell positions this whole widget with Positioned(left:0,
        // right:0, bottom:0); without the Align the ConstrainedBox child
        // rendered at top-start of that stretched parent.
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: ConstrainedBox(
              // Cap the bar's content width on tablet / desktop so it
              // doesn't read as a giant strip; same center-cap the search
              // page uses for its content column.
              constraints: const BoxConstraints(maxWidth: 720),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  // Same blur strength as GlassPill — keeps the look
                  // consistent between the bar and the top action pill.
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Material(
                    // Transparent so only the blur + hairline border read
                    // as chrome; InkWell gives the whole pill a ripple +
                    // a real 56dp tap target.
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: onTap,
                      child: Semantics(
                        button: true,
                        label: 'Search',
                        hint:
                            'Opens search to find pages, actions, '
                            'and children',
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            children: [
                              // Leading search glyph in the same 48×48
                              // footprint the chrome pills use. `onSurface
                              // Variant` (not `onSurface`) by design — this
                              // is a de-emphasized placeholder affordance,
                              // not a foregrounded action.
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: Icon(
                                    Icons.search,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              // The hint, styled as a placeholder so the
                              // pill reads like a search box even though
                              // it's a button.
                              Expanded(
                                child: Text(
                                  hint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
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
          ),
        ),
      ),
    );
  }
}
