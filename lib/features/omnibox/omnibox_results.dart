import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/today/widgets/quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Inline omnibox suggestion list. Not a scaffold — drops into any
/// parent's body when search is active.
///
/// Takes a query string. Empty query → top-N default suggestions.
/// Non-empty → fuzzy-scored across labels, subtitles, and keywords.
class OmniboxResults extends ConsumerWidget {
  const OmniboxResults({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final suggestions = _computeSuggestions(query, groups, viewer);

    if (suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            query.isEmpty
                ? 'Start typing to search…'
                : 'No matches for "$query".',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      // Leave clearance for the floating search bar at top and gesture
      // nav at bottom.
      padding: const EdgeInsets.fromLTRB(0, 64, 0, 24),
      itemCount: suggestions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _SuggestionTile(suggestion: suggestions[i]),
    );
  }

  static List<_Suggestion> _computeSuggestions(
    String query,
    List<Group> groups,
    Viewer viewer,
  ) {
    // UX_DECISIONS §7 — every new feature must register a search entry
    // here so the omnibox stays the single discoverable index of what
    // the app can do. Capability-gate the entry the same way the UI
    // gates the destination.
    final all = <_Suggestion>[
      _Suggestion(
        label: 'Today',
        kindLabel: 'Page',
        icon: Icons.today_outlined,
        keywords: const ['home', 'dashboard'],
        onSelect: (ctx, ref) => ctx.go('/'),
      ),
      _Suggestion(
        label: 'Morning checklist',
        kindLabel: 'Page',
        icon: Icons.task_alt,
        keywords: const ['attendance', 'check-in', 'morning', 'mark'],
        onSelect: (ctx, ref) => ctx.push('/checklist'),
      ),
      _Suggestion(
        label: 'Settings',
        kindLabel: 'Page',
        icon: Icons.settings_outlined,
        keywords: const ['preferences', 'admin', 'config'],
        onSelect: (ctx, ref) => ctx.push('/settings'),
      ),
      _Suggestion(
        label: 'Team',
        kindLabel: 'Page',
        icon: Icons.groups_outlined,
        keywords: const ['staff', 'teachers', 'members'],
        onSelect: (ctx, ref) => ctx.push('/settings/team'),
      ),
      _Suggestion(
        label: 'Program settings',
        kindLabel: 'Page',
        icon: Icons.school_outlined,
        keywords: const ['program', 'space', 'features'],
        onSelect: (ctx, ref) => ctx.push('/settings/program'),
      ),
      // -- Vehicles (added with the fleet feature) ------------------------
      _Suggestion(
        label: 'Vehicles',
        kindLabel: 'Page',
        icon: Icons.directions_bus_outlined,
        keywords: const ['fleet', 'van', 'bus', 'car', 'transport'],
        onSelect: (ctx, ref) => ctx.push('/settings/vehicles'),
      ),
      if (viewer.canManageProgram)
        _Suggestion(
          label: 'Add a vehicle',
          kindLabel: 'Action',
          icon: Icons.add_circle_outline,
          keywords: const ['new vehicle', 'fleet', 'van', 'bus', 'car'],
          onSelect: (ctx, ref) {
            unawaited(ctx.push('/settings/vehicles/new'));
          },
        ),
      // -- Observations (cap-gated) --------------------------------------
      if (viewer.canObserve)
        _Suggestion(
          label: 'New observation',
          kindLabel: 'Action',
          icon: Icons.edit_note_outlined,
          keywords: const ['note', 'log', 'observe', 'observation'],
          onSelect: (ctx, ref) {
            unawaited(startNewObservation(ctx, ref));
          },
        ),
      // -- Add a classroom (director-only) -------------------------------
      if (viewer.canManageProgram)
        _Suggestion(
          label: 'Add a classroom',
          kindLabel: 'Action',
          icon: Icons.add_circle_outline,
          keywords: const ['new group', 'create room', 'classroom'],
          onSelect: (ctx, ref) {
            unawaited(ctx.push('/groups/new'));
          },
        ),
      _Suggestion(
        label: 'Sign out',
        kindLabel: 'Action',
        icon: Icons.logout,
        keywords: const ['log out', 'logout'],
        onSelect: (ctx, ref) {
          unawaited(ref.read(authActionsProvider).signOut());
        },
      ),
      for (final g in groups) ...[
        _Suggestion(
          label: g.name,
          subtitle: g.ageRange,
          kindLabel: 'Classroom',
          icon: Icons.meeting_room_outlined,
          keywords: const ['class', 'room', 'group'],
          onSelect: (ctx, ref) => ctx.push('/groups/${g.id}'),
        ),
        _Suggestion(
          label: 'Take attendance · ${g.name}',
          kindLabel: 'Action',
          icon: Icons.fact_check_outlined,
          keywords: const ['attendance', 'mark', 'present'],
          onSelect: (ctx, ref) => ctx.push('/groups/${g.id}/attendance'),
        ),
        if (viewer.canObserve)
          _Suggestion(
            label: 'Observations · ${g.name}',
            kindLabel: 'Page',
            icon: Icons.menu_book_outlined,
            keywords: const ['notes', 'log', 'observation'],
            onSelect: (ctx, ref) =>
                ctx.push('/groups/${g.id}/observations'),
          ),
      ],
    ];

    if (query.trim().isEmpty) {
      return all.take(10).toList();
    }

    final q = query.toLowerCase().trim();
    final scored = <(_Suggestion, int)>[];
    for (final s in all) {
      final score = s.score(q);
      if (score > 0) scored.add((s, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((t) => t.$1).take(12).toList();
  }
}

class _SuggestionTile extends ConsumerWidget {
  const _SuggestionTile({required this.suggestion});

  final _Suggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(suggestion.icon, color: theme.colorScheme.primary),
      title: Text(suggestion.label),
      subtitle: suggestion.subtitle == null
          ? Text(
              suggestion.kindLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Text(
              '${suggestion.subtitle!} · ${suggestion.kindLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => suggestion.onSelect(context, ref),
    );
  }
}

class _Suggestion {
  _Suggestion({
    required this.label,
    required this.icon,
    required this.kindLabel,
    required this.onSelect,
    this.subtitle,
    this.keywords = const [],
  });

  final String label;
  final String? subtitle;
  final String kindLabel;
  final IconData icon;
  final void Function(BuildContext, WidgetRef) onSelect;
  final List<String> keywords;

  int score(String q) {
    final l = label.toLowerCase();
    final s = subtitle?.toLowerCase();

    if (l == q) return 1000;
    if (l.startsWith(q)) return 500;
    if (l.contains(q)) return 200;
    if (s != null && s.contains(q)) return 100;
    for (final k in keywords) {
      if (k.toLowerCase().contains(q)) return 80;
    }
    return 0;
  }
}
