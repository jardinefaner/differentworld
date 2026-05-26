import 'package:differentworld/shared/breakpoints.dart';
import 'package:flutter/material.dart';

/// The list+detail layout pattern for screens that historically
/// drilled-in on phone but should show both panels side-by-side on a
/// desktop window.
///
/// **At widths ≥ [collapseAt]** (default `Breakpoints.tablet` = 1200dp)
/// renders `Row(list, divider, detail-or-placeholder)`. The list stays
/// visible while the user inspects each detail; the back button doesn't
/// have to bounce between pages.
///
/// **Below [collapseAt]** renders only [list]. The caller is responsible
/// for routing a tap on a list item to the full-screen detail surface
/// (typically `context.push('/.../<id>')`). The drill-in pattern is
/// preserved on phone where there isn't enough room to show both.
///
/// **Selection on wide windows** is conventionally stored in the URL
/// (e.g. `?selected=<id>`) so refresh / bookmark / browser-back work.
/// The list is responsible for reading that param and tapping into
/// `onSelect` (which typically `context.replace`s with the new param).
///
/// **The placeholder** is shown on the right column when no row is
/// selected. Defaults to a small centered "Pick a row" hint; pass a
/// richer prompt when the surface has a recommendation ("Start with
/// today's flagged kid").
///
/// Example wiring at /settings/team:
/// ```dart
/// final selected = GoRouterState.of(context).uri.queryParameters['selected'];
/// MasterDetailScaffold(
///   list: TeamList(
///     selectedId: selected,
///     onTap: (id) {
///       final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
///       if (wide) {
///         context.replace('/settings/team?selected=$id');
///       } else {
///         context.push('/settings/team/$id');
///       }
///     },
///   ),
///   detail: selected == null ? null : MemberSummaryPanel(memberId: selected),
/// )
/// ```
class MasterDetailScaffold extends StatelessWidget {
  const MasterDetailScaffold({
    required this.list,
    this.detail,
    this.placeholder,
    this.collapseAt = Breakpoints.tablet,
    this.listWidth = 360,
    super.key,
  });

  /// The master list — typically a `ListView` of tappable cards. At
  /// any width below [collapseAt] this is rendered alone; at or above
  /// it stays in the left column.
  final Widget list;

  /// The detail panel — typically a summary card / form / preview of
  /// whatever's selected. When `null` the [placeholder] renders
  /// instead on wide windows; on narrow windows nothing detail-
  /// related shows (drill-in routing is the caller's responsibility).
  final Widget? detail;

  /// What to render in the right column when [detail] is null (no
  /// row selected) on wide windows. Defaults to a centered hint —
  /// pass something richer when the screen has a recommended row.
  final Widget? placeholder;

  /// Width at which the layout flips from drill-in (mobile) to two-
  /// column (desktop). Defaults to 1200dp.
  final double collapseAt;

  /// Width of the left list column on wide windows. The detail panel
  /// takes the remainder.
  final double listWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < collapseAt) {
          // Narrow — render only the list. Caller pushes detail routes.
          return list;
        }
        final theme = Theme.of(context);
        return Row(
          children: [
            SizedBox(
              width: listWidth,
              child: list,
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(
              child: detail ?? placeholder ?? _DefaultPlaceholder(),
            ),
          ],
        );
      },
    );
  }
}

class _DefaultPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Pick a row to see details',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
