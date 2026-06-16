import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The app-wide cast affordance (docs/LIVE_SESSIONS.md — the cast model).
/// Rendered in AppShell's top chrome on every staff route, so putting
/// something on the screen is ONE tap from anywhere — not buried in the
/// omnibox / Present hub / a per-game button.
///
/// Slice 1 (here): always opens the cast launcher (`/cast`) — the
/// always-reachable half of "cast whatever I have, wherever I am". Later
/// slices light it up on a castable surface ("Cast this" → present it
/// directly) and show a live "Casting · X" state while a session runs.
/// Auto-hidden in immersive / kid-mode because the whole top chrome is.
class CastChromeButton extends StatelessWidget {
  const CastChromeButton({super.key});

  @override
  Widget build(BuildContext context) => SecondaryActionButton(
        tooltip: 'Cast to a screen',
        icon: Icons.cast,
        onPressed: () => context.push('/cast'),
      );
}
