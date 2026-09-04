import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.record,
    super.key,
  });

  final Subject subject;
  final AttendanceStatus? status;

  /// The current attendance row, if any. Drives the Wave 105 audit
  /// footnote: when `lastUpdatedBy` exists and differs from
  /// `recordedBy`, the row surfaces "Updated by X · 2m ago" so a
  /// teacher whose write was overwritten by a co-teacher can see
  /// who flipped it. Optional — older call sites that don't have
  /// the record handy stay supported.
  final AttendanceRecord? record;

  /// Called when the user taps a status icon. The widget passes the
  /// new status, OR `null` if the user re-tapped the current status
  /// (which clears it).
  final Future<void> Function(AttendanceStatus?) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = '${subject.firstName} ${subject.lastName}';
    // Wave 105: an overwrite is when someone OTHER than the original
    // author last touched the row. Calm path (single author, no
    // collision) stays visually quiet.
    final overwrittenBy =
        record != null &&
            record!.lastUpdatedBy != null &&
            record!.lastUpdatedBy != record!.recordedBy
        ? record!.lastUpdatedBy
        : null;

    // RepaintBoundary so a tap-ripple on one row doesn't repaint
    // siblings — important on the morning checklist where users
    // tap 20+ rows in quick succession.
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PersonAvatar(name: fullName, photoUrl: subject.photoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: EntityLink(
                    entity: EntityRef(
                      kind: EntityKind.subject,
                      id: subject.id,
                      label: fullName,
                    ),
                    padded: false,
                    // Plain, not the entity tint. EntityLink colours by KIND,
                    // which is right for an inline reference in prose
                    // ("Sofia and Mateo built a fort") and wrong in a list
                    // where every row is the same kind — twenty rust names on
                    // warm paper read as twenty problems, and the brand's own
                    // rule is that glow is scarce.
                    tinted: false,
                    style: theme.textTheme.bodyLarge,
                    // Two lines. Five 48dp buttons take 240dp of a 390dp
                    // phone, leaving ~124dp for the name — "Liam Okafor"
                    // truncated to "Liam Okaf…". A roster row exists to tell
                    // children apart; a clipped surname defeats the screen.
                    maxLines: 2,
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
            if (overwrittenBy != null)
              Padding(
                padding: const EdgeInsets.only(left: 52, top: 2),
                child: _UpdatedByFootnote(
                  memberId: overwrittenBy,
                  updatedAt: record!.updatedAt,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Subtle "Updated by Jane · 2m ago" line under an attendance row
/// whose last writer wasn't the original author. Lazily resolves the
/// member name; falls back to a generic "another teacher" when the
/// member can't be found (e.g. revoked / pending sync). Wave 105.
class _UpdatedByFootnote extends ConsumerWidget {
  const _UpdatedByFootnote({required this.memberId, required this.updatedAt});

  final String memberId;
  final String updatedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final member = ref.watch(memberByIdProvider(memberId)).value;
    final name = member?.displayName.trim().isNotEmpty == true
        ? member!.displayName
        : 'another teacher';
    final when = DateTime.tryParse(updatedAt);
    final whenLabel = when == null ? '' : ' · ${relativeTimeAgo(when)}';
    return Text(
      'Updated by $name$whenLabel',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
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
    final bg = selected ? color : theme.colorScheme.surfaceContainerHighest;
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
            // Wave 97: 48dp tap target — was 36, below WCAG/Material
            // minimum. Attendance is the daily-use surface, marked
            // ~50 times per teacher per day; below-spec targets here
            // hurt the most. Icon stays 18dp so the visual density
            // doesn't change perceptibly.
            child: SizedBox(
              width: 48,
              height: 48,
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
