// Many `nodes.add(...)` runs build the section list; cascades there
// hurt readability more than they help. Silenced per file.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/omnibox/omnibox_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Open the omnibox from anywhere. Pushes a full-screen overlay (not
/// a bottom sheet — we want the user's typing focus on the field, not
/// "the page below is still in play").
///
/// Bound to `Cmd+K` / `Ctrl+K` at the app shell so a keyboard user
/// can summon it from any screen.
Future<void> showOmnibox(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, anim, _) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          ),
          child: const _OmniboxOverlay(),
        );
      },
    ),
  );
}

class _OmniboxOverlay extends ConsumerStatefulWidget {
  const _OmniboxOverlay();

  @override
  ConsumerState<_OmniboxOverlay> createState() => _OmniboxOverlayState();
}

class _OmniboxOverlayState extends ConsumerState<_OmniboxOverlay> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    // Center the omnibox on tablet/desktop; full width on phone.
    final maxWidth = media.size.width > 720 ? 640.0 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: scheme.surface,
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SearchField(
                      controller: _ctrl,
                      focusNode: _focus,
                      onChanged: (v) => setState(() => _query = v),
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    Flexible(
                      child: _OmniboxResultsView(
                        query: _query,
                        onSelected: (entry) {
                          // Bump recent then close, then fire — closing
                          // first frees the route stack so the
                          // destination push lands on the page below.
                          bumpRecent(ref, entry.id);
                          Navigator.of(context).pop();
                          // The entry's onSelect uses ctx + ref. Use the
                          // route's context — the overlay's context is
                          // about to be torn down.
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) {
                            if (!mounted) return;
                            entry.onSelect(context, ref);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Icon(Icons.search, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autocorrect: false,
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText:
                    'Search anything — pages, actions, kids, vehicles…',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
              ),
              style: theme.textTheme.titleMedium,
              onSubmitted: (_) {},
            ),
          ),
          // Voice mic stub — the speech_to_text plugin + mic
          // permission flow is deferred (see CLAUDE.md "Persona-driven
          // UI work intentionally deferred"). The icon is here so the
          // affordance exists and users learn the gesture; the snackbar
          // explains it's coming.
          IconButton(
            tooltip: 'Voice search (coming soon)',
            icon: const Icon(Icons.mic_none_outlined),
            onPressed: () {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Voice search is coming. For now, just type.',
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Renders the catalog with section grouping + Recent / For you now
/// when the query is empty.
class _OmniboxResultsView extends ConsumerWidget {
  const _OmniboxResultsView({
    required this.query,
    required this.onSelected,
  });

  final String query;
  final void Function(OmniboxEntry) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catalog = ref.watch(omniboxCatalogProvider);
    final byId = {for (final e in catalog) e.id: e};
    final recentIds =
        ref.watch(recentOmniboxIdsProvider).value ?? const <String>[];
    final pinnedIds =
        ref.watch(pinnedOmniboxIdsProvider).value ?? const <String>[];

    final q = query.trim().toLowerCase();
    // Active vertical's labels drive "Classrooms" header text per
    // vertical (Crews / Departments / Sections / Lines).
    final labels = ref.watch(verticalLabelsProvider);
    final theBuilder = q.isEmpty
        ? _buildIdleSections(
            context: context,
            catalog: catalog,
            byId: byId,
            recentIds: recentIds,
            pinnedIds: pinnedIds,
            labels: labels,
          )
        : _buildSearchSections(
            catalog: catalog,
            query: q,
            labels: labels,
          );

    if (theBuilder.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            q.isEmpty
                ? 'Type anything you want to do.'
                : 'No matches for "$query".',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: theBuilder.length,
      itemBuilder: (_, i) {
        final node = theBuilder[i];
        if (node is _SectionHeader) {
          return _SectionHeaderWidget(label: node.label);
        }
        if (node is _Entry) {
          return _EntryTile(
            entry: node.entry,
            onTap: () => onSelected(node.entry),
            isPinned: pinnedIds.contains(node.entry.id),
            onTogglePin: () => ref
                .read(pinnedOmniboxIdsProvider.notifier)
                .toggle(node.entry.id),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Idle state (empty query): pinned → recent → for-you-now →
  /// jump-to category headers.
  List<_Node> _buildIdleSections({
    required BuildContext context,
    required List<OmniboxEntry> catalog,
    required Map<String, OmniboxEntry> byId,
    required List<String> recentIds,
    required List<String> pinnedIds,
    required VerticalLabels labels,
  }) {
    final nodes = <_Node>[];

    // Pinned.
    final pinnedEntries = pinnedIds
        .map((id) => byId[id])
        .whereType<OmniboxEntry>()
        .toList();
    if (pinnedEntries.isNotEmpty) {
      nodes.add(const _SectionHeader('Pinned'));
      nodes.addAll(pinnedEntries.map(_Entry.new));
    }

    // Recent (de-duped against pinned).
    final pinnedSet = pinnedEntries.map((e) => e.id).toSet();
    final recentEntries = recentIds
        .map((id) => byId[id])
        .whereType<OmniboxEntry>()
        .where((e) => !pinnedSet.contains(e.id))
        .toList();
    if (recentEntries.isNotEmpty) {
      nodes.add(const _SectionHeader('Recent'));
      nodes.addAll(recentEntries.take(6).map(_Entry.new));
    }

    // For you now — context tag boosted defaults.
    final tag = currentContextTag(DateTime.now());
    final contextHits = catalog
        .where((e) => e.contextTags.contains(tag))
        .where((e) => !pinnedSet.contains(e.id))
        .where((e) => !recentEntries.map((r) => r.id).contains(e.id))
        .take(5)
        .toList();
    if (contextHits.isNotEmpty) {
      nodes.add(_SectionHeader('For you now · $tag'));
      nodes.addAll(contextHits.map(_Entry.new));
    }

    // Jump-to: top of each remaining category. Keeps the empty-query
    // view useful as a browsable index for new users.
    final seenIds = <String>{
      ...pinnedSet,
      ...recentEntries.map((r) => r.id),
      ...contextHits.map((c) => c.id),
    };
    final byCategory = <OmniboxCategory, List<OmniboxEntry>>{};
    for (final e in catalog) {
      if (seenIds.contains(e.id)) continue;
      byCategory.putIfAbsent(e.category, () => []).add(e);
    }
    for (final cat in OmniboxCategory.values) {
      final list = byCategory[cat];
      if (list == null || list.isEmpty) continue;
      nodes.add(_SectionHeader(cat.pluralLabel(labels)));
      nodes.addAll(list.take(5).map(_Entry.new));
    }

    return nodes;
  }

  /// As-you-type: score everything, group by category, take top-N
  /// per category.
  List<_Node> _buildSearchSections({
    required List<OmniboxEntry> catalog,
    required String query,
    required VerticalLabels labels,
  }) {
    final scored = <(OmniboxEntry, int)>[];
    for (final e in catalog) {
      final s = e.score(query);
      if (s > 0) scored.add((e, s));
    }

    // Verb-on-noun composition: when the query also contains a known
    // person/place/activity name, boost any entries grouped with that
    // noun. So "owen" surfaces all kid-owen entries; "owen mark"
    // boosts "Mark Owen present"; "pool" surfaces every block /
    // activity tied to the Pool location.
    final groupBoost = <String, int>{};
    for (final e in catalog) {
      if (e.groupId == null) continue;
      if (e.label.toLowerCase().contains(query)) {
        groupBoost[e.groupId!] =
            (groupBoost[e.groupId!] ?? 0) + 60;
      }
    }
    if (groupBoost.isNotEmpty) {
      for (final e in catalog) {
        if (e.groupId == null) continue;
        final boost = groupBoost[e.groupId!];
        if (boost == null) continue;
        // Already scored from the query — add a boost so the
        // siblings outrank generic matches.
        final existing = scored.indexWhere((p) => p.$1.id == e.id);
        if (existing >= 0) {
          scored[existing] =
              (e, scored[existing].$2 + boost);
        } else {
          scored.add((e, boost));
        }
      }
    }

    if (scored.isEmpty) return const <_Node>[];

    scored.sort((a, b) => b.$2.compareTo(a.$2));

    final byCategory = <OmniboxCategory, List<(OmniboxEntry, int)>>{};
    for (final p in scored) {
      byCategory.putIfAbsent(p.$1.category, () => []).add(p);
    }

    final nodes = <_Node>[];
    for (final cat in OmniboxCategory.values) {
      final list = byCategory[cat];
      if (list == null || list.isEmpty) continue;
      nodes.add(_SectionHeader(cat.pluralLabel(labels)));
      // Cap per-section to keep the list scannable.
      for (final p in list.take(8)) {
        nodes.add(_Entry(p.$1));
      }
    }
    return nodes;
  }

  // _pluralLabel moved into OmniboxCategoryX.pluralLabel — see
  // lib/features/omnibox/omnibox_entries.dart. The extension reads
  // VerticalLabels so the "Classrooms" header swaps per vertical.
}

sealed class _Node {
  const _Node();
}

class _SectionHeader extends _Node {
  const _SectionHeader(this.label);
  final String label;
}

class _Entry extends _Node {
  const _Entry(this.entry);
  final OmniboxEntry entry;
}

class _SectionHeaderWidget extends StatelessWidget {
  const _SectionHeaderWidget({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.isPinned,
    required this.onTogglePin,
  });

  final OmniboxEntry entry;
  final VoidCallback onTap;
  final bool isPinned;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: entry.heroColor ?? scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          entry.icon,
          color: entry.heroColor == null
              ? scheme.onSurface
              : scheme.onPrimaryContainer,
          size: 18,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              entry.category.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
      subtitle: entry.subtitle == null
          ? null
          : Text(
              entry.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
      trailing: IconButton(
        tooltip: isPinned ? 'Unpin' : 'Pin',
        icon: Icon(
          isPinned
              ? Icons.push_pin
              : Icons.push_pin_outlined,
          size: 18,
          color: isPinned ? scheme.primary : scheme.onSurfaceVariant,
        ),
        onPressed: onTogglePin,
      ),
      onTap: onTap,
    );
  }
}

/// Convenience — bind Cmd+K (and Ctrl+K elsewhere) to opening the
/// omnibox. Wraps `child` in a Shortcuts + Actions pair the app shell
/// can install once at the root.
class OmniboxShortcuts extends StatelessWidget {
  const OmniboxShortcuts({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.keyK,
        ): const _OpenOmniboxIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyK,
        ): const _OpenOmniboxIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenOmniboxIntent: CallbackAction<_OpenOmniboxIntent>(
            onInvoke: (_) {
              // Use the root navigator context so the omnibox opens
              // above every nested screen.
              unawaited(showOmnibox(context));
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _OpenOmniboxIntent extends Intent {
  const _OpenOmniboxIntent();
}
