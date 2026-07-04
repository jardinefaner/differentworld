import 'package:flutter/material.dart';

/// A row that explains *why* it's disabled instead of greying out
/// silently. Used wherever a control is hidden by capability — new
/// hires hit these often and need information, not a wall.
///
/// Renders the underlying [child] (typically a [ListTile]) with a
/// small lock chip on the trailing edge and a [tooltip] explanation
/// that surfaces on long-press / hover. Tapping the lock fires
/// [onLockedTap] (default: a snackbar with the tooltip text), so the
/// user gets feedback either way.
class CapabilityLockedTile extends StatelessWidget {
  const CapabilityLockedTile({
    required this.child,
    required this.tooltip,
    this.onLockedTap,
    super.key,
  });

  /// The would-be enabled control. Wrapped in an `IgnorePointer` so
  /// internal taps don't fire; we add our own affordance instead.
  final Widget child;

  /// Short explanation: "Only directors can do this", "Add the MAT
  /// certification first", etc.
  final String tooltip;

  /// Override what tapping the locked row does. Default: pop a
  /// snackbar carrying [tooltip].
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (onLockedTap != null) {
              onLockedTap!();
              return;
            }
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(tooltip)),
            );
          },
          child: Stack(
            children: [
              // Visually mute but keep the layout — the user sees
              // the affordance they'd otherwise reach for, with a
              // gentle desaturation that signals "locked, not gone."
              IgnorePointer(
                child: Opacity(
                  opacity: 0.55,
                  child: child,
                ),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Locked',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
