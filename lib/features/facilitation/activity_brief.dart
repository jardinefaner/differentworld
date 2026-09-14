import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/facilitation/activity_run_scripts.dart';
import 'package:differentworld/features/facilitation/run_script_view.dart';
import 'package:flutter/material.dart';

/// Brief the room, then show the activity.
///
/// The games' cursor lives in the wire because a paired receiver renders from
/// the wire and nothing else. **These activities are mirror-only** — no
/// receiver resolves them, so the room is looking at this device's own picture
/// over HDMI or AirPlay. Local state is therefore not a compromise here; the
/// phone IS the screen the room can see, and a wire cursor would have nothing
/// on the other end of it.
///
/// If one of these ever becomes castable to a paired screen, this is the class
/// that has to move to `RunScriptWire` — noted here rather than left for
/// somebody to discover when the beats stop arriving.
class ActivityBrief extends StatefulWidget {
  const ActivityBrief({
    required this.route,
    required this.title,
    required this.child,
    this.surface,
    super.key,
  });

  /// The activity's route — the key into [activityRunScripts]. An activity
  /// with no script is passed straight through, so wrapping one costs nothing
  /// until its beats are written.
  final String route;

  final String title;

  /// The colour the briefing sits on. Defaults to the theme's surface, since
  /// an activity screen — unlike a game stage — has no vibe of its own.
  final Color? surface;

  final Widget child;

  @override
  State<ActivityBrief> createState() => _ActivityBriefState();
}

class _ActivityBriefState extends State<ActivityBrief> {
  int _at = 0;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final script = activityRunScripts[widget.route] ?? const [];
    if (_done || script.isEmpty) return widget.child;
    final surface =
        widget.surface ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    return RunScriptView(
      script: script,
      index: _at,
      title: widget.title,
      surface: surface,
      onLine: AppColors.onAccent(surface),
      onNext: () {
        if (_at >= script.length - 1) {
          setState(() => _done = true);
          return;
        }
        setState(() => _at += 1);
      },
      onBack: _at == 0 ? null : () => setState(() => _at -= 1),
    );
  }
}
