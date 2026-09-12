import 'dart:async';

import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// **What the adult can change, right now** — the fifth facet of the
/// facilitation engine (docs/FACILITATION.md).
///
/// The instruments existed and could not be reached. Spotlight, the timer,
/// attention signals, Now & Next and Quick Poll were all built, and all filed
/// as cards in the activity deck — so a counselor mid-Bingo who needed to pick
/// a child had to LEAVE the activity, walk back to the deck, find the card,
/// and lose their place. The app was adding to the coordination work it exists
/// to absorb.
///
/// This is the seam that fixes it: one control, available from inside any
/// activity, that opens an instrument over the top and returns you to exactly
/// where you were. The activity's route stays alive underneath, so its state
/// survives — a half-played board is still half-played when you come back.
///
/// **Why a sheet is right here** even though this app pushes tasks to pages:
/// picking a name, starting a timer and flashing "eyes up" are GLANCES, not
/// tasks (CLAUDE.md, "Modals — a glance, never a task"). Choosing which
/// instrument is the glance; the instrument itself then gets a full page.
enum RoomTool {
  pickSomeone(
    label: 'Pick someone',
    hint: 'Fair turns — everyone before anyone repeats',
    icon: Icons.casino_outlined,
    route: '/present/picker',
  ),
  timer(
    label: 'Timer',
    hint: 'How long we have, big enough to read across the room',
    icon: Icons.timer_outlined,
    route: '/present/timer',
  ),
  signals(
    label: 'Signals',
    hint: 'Eyes up · clean up · breathe',
    icon: Icons.pan_tool_outlined,
    route: '/present/cues',
  ),
  nowNext(
    label: 'Now & next',
    hint: "What we're doing, and what follows",
    icon: Icons.list_alt_outlined,
    route: '/present/now-next',
  ),
  quickPoll(
    label: 'Quick poll',
    hint: 'Vote together, see the winner',
    icon: Icons.how_to_vote_outlined,
    route: '/present/poll',
  );

  const RoomTool({
    required this.label,
    required this.hint,
    required this.icon,
    required this.route,
  });

  final String label;
  final String hint;
  final IconData icon;
  final String route;
}

/// Open the instrument picker. Each choice pushes its own route, so the
/// activity underneath keeps its state and a back gesture returns to it.
Future<void> showRoomTools(BuildContext context) async {
  final tool = await showGlassSheet<RoomTool>(
    context: context,
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GlassDragHandle(),
          for (final t in RoomTool.values)
            ListTile(
              leading: Icon(t.icon),
              title: Text(t.label),
              subtitle: Text(t.hint),
              onTap: () => Navigator.of(ctx).pop(t),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (tool == null || !context.mounted) return;
  unawaited(context.push(tool.route));
}

/// The control itself — small, quiet, and in the body's bottom where a thumb
/// already lives (the half-second rule). Drop it into any activity surface.
class RoomToolsButton extends StatelessWidget {
  const RoomToolsButton({this.compact = false, super.key});

  /// Icon only — for a control bar that has no width to spare.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: 'Room tools',
        onPressed: () => unawaited(showRoomTools(context)),
        icon: const Icon(Icons.handyman_outlined),
      );
    }
    return TextButton.icon(
      onPressed: () => unawaited(showRoomTools(context)),
      icon: const Icon(Icons.handyman_outlined, size: 18),
      label: const Text('Room tools'),
    );
  }
}
