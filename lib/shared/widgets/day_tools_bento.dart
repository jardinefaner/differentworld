import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/widgets/nav_destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The one-tap tools grid — "everything must be one tap away" (the user:
/// "all things must be in the schedule bento… I still hunt down things").
///
/// A compact icon+label grid that lives BELOW the day's content on the daily
/// surfaces (the cockpit home + the schedule), so a teacher never has to open
/// the drawer to reach a tool. It is the daily-surface revival of the old
/// `YourToolsStrip` concept (the cockpit reorg moved persistent tool access
/// into the drawer; this brings the one-tap reach back where the work is).
///
/// **Single source of truth.** The tiles derive from the SAME
/// [buildNavDestinations] list the drawer and the desktop rail render — so it
/// is comprehensive, capability-gated EXACTLY like the drawer (a destination
/// the viewer's caps hide never appears here), and self-maintaining: a new nav
/// destination added later auto-appears in this grid, the drawer, and the rail
/// at once. That is the whole point — one list, every surface.
///
/// On top of the nav destinations it PREPENDS the key first-class actions that
/// aren't nav destinations (today: Capture → `/captures/new`), so the most
/// common "I want to grab this moment" tap is the first tile.
///
/// Count badges (Captures awaiting triage, open Tasks) ride the SAME
/// [NavDestination.countProvider]s the drawer badges — the count is watched
/// per-tile so only the badged tile rebuilds, and the providers are the
/// drawer's existing autoDispose streams (offline-first; no new watches).
class DayToolsBento extends ConsumerWidget {
  const DayToolsBento({this.excludeRoute, super.key});

  /// Drop the destination whose route matches this — so 'Today' doesn't show
  /// on the Today home and 'Schedule' doesn't show on the schedule screen
  /// (you're already there). Matched against [NavDestination.route] AND the
  /// prepended actions' routes.
  final String? excludeRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);

    // Capability-gated already — buildNavDestinations applies every `onlyFor`
    // against the viewer, so we render exactly what the drawer would.
    final destinations = buildNavDestinations(viewer);

    // The prepended first-class actions that aren't nav destinations. Capture
    // is the daily verb (matches role_tools `_capture` → `/captures/new`).
    // NOTE: Attendance is intentionally NOT here — per-cohort attendance lives
    // at `/groups/:id/attendance`; there is no single all-cohort target, so we
    // don't invent a route. (Reachable per-cohort from a group's detail.)
    const actions = <_ToolEntry>[
      _ToolEntry(
        icon: Icons.bolt_outlined,
        label: 'Capture',
        route: '/captures/new',
      ),
    ];

    final entries = <_ToolEntry>[
      ...actions,
      for (final d in destinations)
        _ToolEntry(
          icon: d.icon,
          label: d.label,
          route: d.route,
          countProvider: d.countProvider,
        ),
    ].where((e) => e.route != excludeRoute).toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A quiet section label — "make it obvious first": the grid IS the
        // explanation, so the label is one scannable word, no subtitle.
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'One tap',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // A responsive wrap of compact tiles — ~3-up on a phone, more as the
        // width grows. LayoutBuilder so the column count tracks the real
        // available width (never MediaQuery.size, which rebuilds on every
        // metric change).
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final columns = _columnsFor(constraints.maxWidth);
            final tileWidth =
                (constraints.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < entries.length; i++)
                  SizedBox(
                    // Key by route: the list grows / shrinks with capability
                    // gates, so without a stable key Flutter would match tiles
                    // by position and hand a tile's count subscription to the
                    // wrong destination when a gated item toggles.
                    key: ValueKey('daytool-${entries[i].route}'),
                    width: tileWidth,
                    child: _ToolTile(
                      entry: entries[i],
                      // Cycle a gentle accent across the grid so it reads as a
                      // lively palette, not a wall of one colour. Themed only.
                      accent: _accentFor(theme.colorScheme, i),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// ~3-up on a phone, widening on tablet / desktop. The user's "everything
  /// one tap" means the grid can get long on a phone — that's intentional;
  /// more columns at wider widths keep it compact there.
  int _columnsFor(double width) {
    if (width >= 900) return 6;
    if (width >= 600) return 4;
    return 3;
  }

  /// A deterministic, theme-only accent per tile index. Pulls from the
  /// ColorScheme's container roles so every colour follows OS dark/light and
  /// never hardcodes. The icon chip fills with the accent; the glyph on it
  /// uses [AppColors.onAccent] for guaranteed contrast.
  Color _accentFor(ColorScheme s, int i) {
    final palette = <Color>[
      s.primaryContainer,
      s.tertiaryContainer,
      s.secondaryContainer,
      s.primary,
      s.tertiary,
      s.secondary,
    ];
    return palette[i % palette.length];
  }
}

/// One tool: an icon, a label, the route it pushes, and (optionally) the
/// open-count provider whose badge it shows. A plain value type so the grid
/// can prepend non-nav actions alongside the derived [NavDestination]s.
class _ToolEntry {
  const _ToolEntry({
    required this.icon,
    required this.label,
    required this.route,
    this.countProvider,
  });

  final IconData icon;
  final String label;
  final String route;
  final Provider<int>? countProvider;
}

/// A compact, tappable icon+label tile. The icon sits in an accent-filled chip
/// (glyph tinted via [AppColors.onAccent] for contrast on that fill); the label
/// sits below on the card surface (themed `onSurface`, no tint, so no contrast
/// concern). ≥48dp tap target; one clean Semantics button label per tile.
class _ToolTile extends ConsumerWidget {
  const _ToolTile({required this.entry, required this.accent});

  final _ToolEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Watch the count per-tile so only this tile rebuilds when it changes, and
    // a tile with no provider never subscribes to anything.
    final count = entry.countProvider == null
        ? 0
        : ref.watch(entry.countProvider!);
    final onChip = AppColors.onAccent(accent);

    return Semantics(
      button: true,
      label: count > 0 ? '${entry.label}, $count waiting' : entry.label,
      excludeSemantics: true,
      child: Material(
        // Calm: a hairline-bordered surface tile, not a heavy fill — reads as
        // one quiet system with the rest of the daily surface.
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            // ref.read in the callback (never watch); optimistic push, never
            // awaited in a user-facing handler.
            unawaited(context.push(entry.route));
          },
          child: Padding(
            // Vertical room keeps the whole tile a comfortable ≥48dp target.
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The icon chip + its optional count badge, overlaid top-right.
                // The badge is conditional, so the Stack's children list grows /
                // shrinks when the count flips 0↔n — both children carry a
                // stable key so Flutter matches by key (not position) and never
                // hands the badge's slot to the chip's Element (the
                // "Stack children without keys" invariant).
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      key: const ValueKey('tool-chip'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(entry.icon, size: 21, color: onChip),
                    ),
                    if (count > 0)
                      Positioned(
                        key: const ValueKey('tool-badge'),
                        top: -6,
                        right: -6,
                        child: NavCountBadge(count: count),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
