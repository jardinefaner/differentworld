import 'package:flutter/material.dart';

/// One thing you can do from a [SlideBlock] — a labelled, iconed action. The
/// `primary` renders as a filled button in the slide's accent; `actions` render
/// as outlined pills; a `tertiary` renders as a quiet text button.
@immutable
class SlideAction {
  const SlideAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// A **slide** — the app's atom (docs/VISION.md 2026-06-19: *"the app creates
/// slides that coordinate the room, all the necessary info and actions are
/// within this block"*). A self-contained block that carries a moment's INFO
/// and its ACTIONS together: an [eyebrow] label, a big [title], an optional
/// [body], a [primary] action filled in the slide's accent, secondary [actions]
/// as pills, a quiet [tertiary], and an optional [onCast] to present the moment
/// to the room (dream #14/#18).
///
/// **Content-only by design** — the caller frames it: the cockpit fills the
/// screen edge-to-edge in the beat's emotional tone; an in-app context wraps it
/// in a card. [foreground] is the text/icon colour on that frame;
/// [accentBackground] / [accentForeground] fill the primary button. It pushes
/// the actions to the bottom with [Spacer]s, so it lives inside a min-height /
/// scrolling frame (never a fixed box — text-scale stays safe).
class SlideBlock extends StatelessWidget {
  const SlideBlock({
    required this.title,
    required this.foreground,
    required this.accentBackground,
    required this.accentForeground,
    this.eyebrow,
    this.icon,
    this.body,
    this.primary,
    this.actions = const [],
    this.tertiary,
    this.onCast,
    super.key,
  });

  final String title;
  final Color foreground;
  final Color accentBackground;
  final Color accentForeground;
  final String? eyebrow;
  final IconData? icon;
  final Widget? body;
  final SlideAction? primary;
  final List<SlideAction> actions;
  final SlideAction? tertiary;
  final VoidCallback? onCast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foreground;
    final hasPills = actions.isNotEmpty || onCast != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) Icon(icon, size: 40, color: fg),
        const Spacer(),
        if (eyebrow != null)
          Text(
            eyebrow!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          title,
          style: theme.textTheme.displaySmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
            height: 1.05,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: theme.textTheme.titleMedium!.copyWith(
              color: fg.withValues(alpha: 0.9),
            ),
            child: body!,
          ),
        ],
        const Spacer(),
        const SizedBox(height: 16),
        if (primary != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: primary!.onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: accentBackground,
                foregroundColor: accentForeground,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: Icon(primary!.icon),
              label: Text(primary!.label),
            ),
          ),
        if (hasPills) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in actions)
                OutlinedButton.icon(
                  onPressed: a.onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fg,
                    side: BorderSide(color: fg.withValues(alpha: 0.4)),
                  ),
                  icon: Icon(a.icon, size: 18),
                  label: Text(a.label),
                ),
              if (onCast != null)
                OutlinedButton.icon(
                  onPressed: onCast,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fg,
                    side: BorderSide(color: fg.withValues(alpha: 0.4)),
                  ),
                  icon: const Icon(Icons.cast, size: 18),
                  label: const Text('Cast to room'),
                ),
            ],
          ),
        ],
        if (tertiary != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: tertiary!.onPressed,
              style: TextButton.styleFrom(foregroundColor: fg),
              icon: Icon(tertiary!.icon, size: 18),
              label: Text(tertiary!.label),
            ),
          ),
        ],
      ],
    );
  }
}
