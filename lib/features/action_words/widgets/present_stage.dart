import 'package:differentworld/app/design_tokens.dart';
import 'package:flutter/material.dart';

/// Shared pieces of the action-words PRESENT/CAST stages — the fullscreen
/// room-facing slideshows (`WorldPresentScreen`, `BeatPresenter`) and the
/// cast receiver's world stage (`WorldCastGame`). These are projection
/// surfaces (raw canvases — docs/THEME_ADHERENCE.md): deliberately dark and
/// hardcoded-white regardless of OS theme, so this file is on the
/// theme-guard allowlist in scripts/check_theme_adherence.sh.

/// The stage's shell: a black Scaffold whose background deepens the room's
/// accent over black (top → bottom gradient), with the content inside a
/// SafeArea.
class PresentStageScaffold extends StatelessWidget {
  const PresentStageScaffold({
    required this.accent,
    required this.child,
    super.key,
  });

  /// The room/world colour — tints the top of the background gradient.
  final Color accent;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(accent.withValues(alpha: 0.45), Colors.black),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}

/// A room-readable "eyebrow label over big statement (+ optional sub-line)"
/// slide face — the shared body of the present screen's big-text slides and
/// the cast stage's equivalent.
class PresentBigText extends StatelessWidget {
  const PresentBigText({
    required this.label,
    required this.big,
    this.sub,
    this.displayFont = true,
    this.shrinkWrap = false,
    super.key,
  });

  final String label;
  final String big;
  final String? sub;

  /// Draw the big line in the display face (the present screen); the cast
  /// receiver keeps the default face.
  final bool displayFont;

  /// True when the slide is centred by a parent (the cast stage's `Center`);
  /// false to fill the page and centre vertically (the present PageView).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: shrinkWrap
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          semanticsLabel: label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 20,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          big,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: displayFont ? AppType.display : null,
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 20),
          Text(
            sub!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 26),
          ),
        ],
      ],
    );
  }
}
