import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/omnibox/omnibox_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Legacy inline omnibox results renderer. Today used to drop this
/// into its body when the user was searching. The canonical entry
/// point is now the global overlay (`showOmnibox(context)` from
/// `omnibox_overlay.dart`), bound to Cmd+K and the search icon on
/// every screen.
///
/// This file is preserved as a thin wrapper so any leftover callers
/// keep compiling, but for new code prefer the overlay. The catalog
/// + entry model + section-headed renderer lives in
/// `omnibox_catalog.dart` + `omnibox_overlay.dart`.
class OmniboxResults extends ConsumerWidget {
  const OmniboxResults({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catalog = ref.watch(omniboxCatalogProvider);
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Start typing to search…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final scored = <(OmniboxEntry, int)>[];
    for (final e in catalog) {
      final s = e.score(q);
      if (s > 0) scored.add((e, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final top = scored.map((p) => p.$1).take(12).toList();
    if (top.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No matches for "$query".',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 64, 0, 24),
      itemCount: top.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = top[i];
        return ListTile(
          leading: Icon(e.icon, color: theme.colorScheme.primary),
          title: Text(e.label),
          subtitle: Text(
            e.subtitle ?? e.category.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            bumpRecent(ref, e.id);
            e.onSelect(context, ref);
          },
        );
      },
    );
  }
}
