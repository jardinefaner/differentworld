import 'package:differentworld/shared/widgets/floating_actions.dart';
import 'package:differentworld/shared/widgets/floating_back.dart';
import 'package:differentworld/shared/widgets/floating_hamburger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The replacement for `Scaffold` + `AppBar` across the app.
///
/// - No persistent top chrome. Content fills the screen edge-to-edge.
/// - Optional floating back button in the top-left (auto-shown when
///   the navigator can pop; pass `showBack: false` for the home page).
/// - Optional floating action pill in the top-right ([actions]).
/// - The [body] is wrapped in a `SafeArea` so first-row content sits
///   below the status bar; the bottom is intentionally NOT wrapped so
///   content can scroll under the gesture indicator.
/// - [floatingActionButton] and [bottomSheet] pass through to a
///   real `Scaffold` underneath.
///
/// Title / subtitle live INSIDE [body] as the first scrollable
/// content via `ContentHeader` — not in chrome. That's the whole
/// point of the redesign.
class EdgeScaffold extends StatelessWidget {
  const EdgeScaffold({
    required this.body,
    this.actions = const <Widget>[],
    this.showBack = true,
    this.backFallbackRoute = '/',
    this.drawer,
    this.topOverlay,
    this.floatingActionButton,
    this.bottomSheet,
    this.resizeToAvoidBottomInset,
    super.key,
  });

  final Widget body;
  final List<Widget> actions;

  /// When true (default), the top-left shows a FloatingBack pill.
  /// When false AND [drawer] is non-null, the top-left shows a
  /// FloatingHamburger that opens the drawer.
  final bool showBack;
  final String backFallbackRoute;

  /// Optional left-side drawer. When provided, the top-left renders a
  /// hamburger pill on home pages (showBack: false). On drill-in pages
  /// the FloatingBack stays visible and the drawer is still openable
  /// via swipe-from-left-edge.
  final Widget? drawer;

  /// When non-null, replaces BOTH the left chrome (back / hamburger)
  /// AND the right chrome (action pill) with a single full-width
  /// overlay. Used by the inline search bar on Today — the chrome
  /// transforms into a search input in place.
  final Widget? topOverlay;

  final Widget? floatingActionButton;
  final Widget? bottomSheet;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // System UI icons: dark icons over light scaffold, light over dark.
    // Per-screen AnnotatedRegion so each screen gets the right contrast
    // even if it's themed against the opposite scheme.
    final overlay = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: const Color(0x00000000),
            systemNavigationBarColor: const Color(0x00000000),
            systemNavigationBarContrastEnforced: false,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: const Color(0x00000000),
            systemNavigationBarColor: const Color(0x00000000),
            systemNavigationBarContrastEnforced: false,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        drawer: drawer,
        body: Stack(
          children: [
            // Content. SafeArea only top — bottom flows under gesture nav.
            // Each screen owns its own bottom padding for FAB clearance.
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: body,
              ),
            ),
            // Chrome row. topOverlay wins over the default left+right
            // floating pills when provided — the search bar uses this
            // to replace the whole top in place without restructuring
            // the scaffold.
            if (topOverlay != null)
              Positioned(
                top: topInset + 8,
                left: 8,
                right: 8,
                child: topOverlay!,
              )
            else ...[
              // Top-left: back arrow on drill-ins, hamburger on home pages.
              if (showBack)
                Positioned(
                  top: topInset + 8,
                  left: 8,
                  child: FloatingBack(fallbackRoute: backFallbackRoute),
                )
              else if (drawer != null)
                Positioned(
                  top: topInset + 8,
                  left: 8,
                  child: const FloatingHamburger(),
                ),
              // Top-right: action pill.
              if (actions.isNotEmpty)
                Positioned(
                  top: topInset + 8,
                  right: 8,
                  child: FloatingActions(children: actions),
                ),
            ],
          ],
        ),
        floatingActionButton: floatingActionButton,
        bottomSheet: bottomSheet,
      ),
    );
  }
}
