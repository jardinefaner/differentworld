import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One student row on the attendance / morning-checklist screens.
///
/// Per `docs/UX_DECISIONS.md §1+§2`, every status option is visible
/// inline — no swipe-up sheet, no extra animation, no "tap to pick
/// from a modal." Tap a status icon → it auto-saves. Tap the same
/// icon again → status clears.
///
/// Status icons render in this order (matching the spec'd display
/// order in [AttendanceStatus]): Present, Absent, Late, Early
/// pickup, Excused. Selected icon fills in with its semantic color;
/// the rest sit muted.
class AttendanceRow extends StatelessWidget {
  const AttendanceRow({
    required this.subject,
    required this.status,
    required this.onChangeStatus,
    super.key,
  });

  final Subject subject;
  final AttendanceStatus? status;

  /// Called when the user taps a status icon. The widget passes the
  /// new status, OR `null` if the user re-tapped the current status
  /// (which clears it).
  final Future<void> Function(AttendanceStatus?) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = '${subject.firstName} ${subject.lastName}';

    // RepaintBoundary so a tap-ripple on one row doesn't repaint
    // siblings — important on the morning checklist where users
    // tap 20+ rows in quick succession.
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            PersonAvatar(name: fullName, photoUrl: subject.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fullName,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            for (final s in AttendanceStatus.values) ...[
              _StatusButton(
                status: s,
                selected: s == status,
                onTap: () async {
                  unawaited(HapticFeedback.selectionClick());
                  // Re-tap clears; otherwise sets to this status.
                  await onChangeStatus(s == status ? null : s);
                },
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final AttendanceStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = status.color(theme.colorScheme);
    final bg = selected
        ? color
        : theme.colorScheme.surfaceContainerHighest;
    final fg = selected
        ? _onColorFor(color, theme.colorScheme)
        : theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: status.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: status.label,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(status.icon, size: 18, color: fg),
            ),
          ),
        ),
      ),
    );
  }

  /// Pick a foreground that contrasts well with the semantic color
  /// when the button is selected. M3 doesn't have onTertiary in every
  /// scheme paired the way we want, so default to onPrimary for all
  /// non-error colors — it lands white-ish in both light and dark.
  Color _onColorFor(Color bg, ColorScheme scheme) {
    if (bg == scheme.error) return scheme.onError;
    if (bg == scheme.tertiary) return scheme.onTertiary;
    if (bg == scheme.secondary) return scheme.onSecondary;
    if (bg == scheme.onSurfaceVariant) return scheme.surface;
    return scheme.onPrimary;
  }
}
