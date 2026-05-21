// Many `nodes.add(...)` runs build the section list; cascades there
// hurt readability more than they help.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/omnibox/omnibox_history.dart';
import 'package:differentworld/features/omnibox/omnibox_mode.dart';
import 'package:differentworld/features/omnibox/omnibox_state.dart';
import 'package:differentworld/features/omnibox/slash_commands.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The omnibox suggestion list, promoted to a real go_router route
/// (`/search`) in Wave 17.
///
/// Architecture before: inline `_OmniboxResultsPanel` overlay inside
/// `AppShell`'s Stack — special-cased show/hide, scrim, PopScope
/// intercept, double padding logic, the works. ~600 lines of shell
/// state managing one transient surface.
///
/// Architecture now: this screen is a normal `EdgeScaffold`. The
/// shell's layout law (Wave 16) handles top + bottom insets. The
/// chrome `[☰] [←]` renders automatically via the route chrome
/// stack — back button means "leave search" without any custom
/// intercept. The omnibox BAR continues to live in `AppShell` so it
/// persists across the route push (composer stays put across page
/// transitions — the LLM-shell pattern).
///
/// The bar's [TextEditingController] (still in `AppShell`) mirrors
/// every keystroke into [omniboxQueryProvider]; this screen reads
/// it and re-renders. Selecting a result pops `/search` first, then
/// fires the entry's `onSelect` so the destination route lands on a
/// clean shell, not on top of the search route.
class OmniboxSearchScreen extends ConsumerWidget {
  const OmniboxSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = ref.watch(omniboxQueryProvider);
    final catalog = ref.watch(omniboxCatalogProvider);
    final mode = detectMode(query: query, catalog: catalog);
    final byId = {for (final e in catalog) e.id: e};
    final recentIds =
        ref.watch(recentOmniboxIdsProvider).value ?? const <String>[];
    final pinnedIds =
        ref.watch(pinnedOmniboxIdsProvider).value ?? const <String>[];

    final q = query.trim().toLowerCase();
    final isSlash = mode == OmniboxMode.slash;
    final isCapture = mode == OmniboxMode.capture;

    final parsedSlash = isSlash ? parseSlashQuery(query) : null;
    final viewer = ref.watch(viewerProvider);
    final slashMatches = isSlash
        ? matchSlashCommands(parsedSlash?.name, viewer: viewer)
        : const <SlashCommand>[];

    final labels = ref.watch(verticalLabelsProvider);

    final nodes = (q.isEmpty || isSlash)
        ? <_Node>[]
        : _buildSearchSections(
            catalog: catalog,
            query: q,
            labels: labels,
          );
    final idleNodes = q.isEmpty && !isSlash
        ? _buildIdleSections(
            catalog: catalog,
            byId: byId,
            recentIds: recentIds,
            pinnedIds: pinnedIds,
            labels: labels,
          )
        : const <_Node>[];

    final showRecentCaptures = q.isEmpty && !isCapture && !isSlash;
    final recentCaptures = showRecentCaptures
        ? (ref.watch(openCapturesProvider).value ?? const <Capture>[])
            .take(5)
            .toList()
        : const <Capture>[];

    final activeNodes = q.isEmpty ? idleNodes : nodes;

    void selectEntry(OmniboxEntry entry) {
      // Bump recent, leave the route, THEN fire the entry's action.
      // Pop first so the destination lands on a clean shell.
      bumpRecent(ref, entry.id);
      // Clear the query so reopening search starts fresh next time.
      ref.read(omniboxQueryProvider.notifier).clear();
      context.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        entry.onSelect(context, ref);
      });
    }

    Future<void> saveAsCapture() async {
      final body = query.trim();
      if (body.isEmpty) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final actions = ref.read(captureActionsProvider);
      ref.read(omniboxQueryProvider.notifier).clear();
      context.pop();
      await runReported(
        library: 'captures',
        messenger: messenger,
        onSuccess: 'Saved as a capture.',
        onError: 'Could not save the capture.',
        action: () => actions.start(body: body),
      );
    }

    void runSlash(SlashCommand cmd) {
      ref.read(omniboxQueryProvider.notifier).clear();
      context.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        cmd.exec(context, ref, parsedSlash?.args);
      });
    }

    return EdgeScaffold(
      // The chrome [☰] [←] is rendered by AppShell — back pops this
      // route and the user lands back on whichever page they were on.
      // No custom dismiss handling needed: that's the whole point of
      // turning search into a route.
      body: Center(
        child: ConstrainedBox(
          // Same max width the bar uses — keeps the line lengths
          // readable on tablet / desktop.
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isCapture)
                _CaptureHeroCard(text: query, onSave: saveAsCapture),
              if (recentCaptures.isNotEmpty)
                _RecentCapturesStrip(
                  captures: recentCaptures,
                  onOpenInbox: () {
                    ref.read(omniboxQueryProvider.notifier).clear();
                    context.pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      unawaited(context.push('/captures'));
                    });
                  },
                ),
              if (isSlash)
                Expanded(
                  child: _SlashCommandList(
                    matches: slashMatches,
                    parsedArgs: parsedSlash?.args,
                    onPick: runSlash,
                  ),
                )
              else if (activeNodes.isEmpty && !isCapture)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
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
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: activeNodes.length,
                    itemBuilder: (_, i) {
                      final n = activeNodes[i];
                      if (n is _SectionHeader) {
                        return _SectionHeaderWidget(label: n.label);
                      }
                      if (n is _Entry) {
                        return _EntryTile(
                          entry: n.entry,
                          isPinned: pinnedIds.contains(n.entry.id),
                          onTap: () => selectEntry(n.entry),
                          onTogglePin: () => ref
                              .read(pinnedOmniboxIdsProvider.notifier)
                              .toggle(n.entry.id),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section builders — moved here verbatim from app_shell.dart's
// `_OmniboxResultsPanel`. Same algorithm: idle (pinned + recent +
// for-you-now + by-category) and matched (sorted by score, grouped
// by category with group-id boost). Lives here so the search screen
// is self-contained.
// ---------------------------------------------------------------------------

List<_Node> _buildIdleSections({
  required List<OmniboxEntry> catalog,
  required Map<String, OmniboxEntry> byId,
  required List<String> recentIds,
  required List<String> pinnedIds,
  required VerticalLabels labels,
}) {
  final nodes = <_Node>[];
  final pinnedEntries = pinnedIds
      .map((id) => byId[id])
      .whereType<OmniboxEntry>()
      .toList();
  if (pinnedEntries.isNotEmpty) {
    nodes.add(const _SectionHeader('Pinned'));
    nodes.addAll(pinnedEntries.map(_Entry.new));
  }
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
  final seen = <String>{
    ...pinnedSet,
    ...recentEntries.map((r) => r.id),
    ...contextHits.map((c) => c.id),
  };
  final byCategory = <OmniboxCategory, List<OmniboxEntry>>{};
  for (final e in catalog) {
    if (seen.contains(e.id)) continue;
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
  final groupBoost = <String, int>{};
  for (final e in catalog) {
    if (e.groupId == null) continue;
    if (e.label.toLowerCase().contains(query)) {
      groupBoost[e.groupId!] = (groupBoost[e.groupId!] ?? 0) + 60;
    }
  }
  if (groupBoost.isNotEmpty) {
    for (final e in catalog) {
      if (e.groupId == null) continue;
      final boost = groupBoost[e.groupId!];
      if (boost == null) continue;
      final existing = scored.indexWhere((p) => p.$1.id == e.id);
      if (existing >= 0) {
        scored[existing] = (e, scored[existing].$2 + boost);
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
    for (final p in list.take(8)) {
      nodes.add(_Entry(p.$1));
    }
  }
  return nodes;
}

// ---------------------------------------------------------------------------
// Visual building blocks — moved here from the old `_OmniboxResultsPanel`.
// ---------------------------------------------------------------------------

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
        child: Icon(entry.icon, size: 18, color: scheme.onSurface),
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
          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          size: 18,
          color: isPinned ? scheme.primary : scheme.onSurfaceVariant,
        ),
        onPressed: onTogglePin,
      ),
      onTap: onTap,
    );
  }
}

class _CaptureHeroCard extends StatelessWidget {
  const _CaptureHeroCard({required this.text, required this.onSave});

  final String text;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trimmed = text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(onSave()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bolt_outlined,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SAVE AS A CAPTURE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  trimmed.isEmpty
                      ? 'Start typing a thought…'
                      : trimmed,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Press return — or tap Save',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => unawaited(onSave()),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentCapturesStrip extends StatelessWidget {
  const _RecentCapturesStrip({
    required this.captures,
    required this.onOpenInbox,
  });

  final List<Capture> captures;
  final VoidCallback onOpenInbox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'RECENT CAPTURES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onOpenInbox,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: captures.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = captures[i];
                return _CapturePeekChip(
                  body: c.body,
                  onTap: onOpenInbox,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SlashCommandList extends StatelessWidget {
  const _SlashCommandList({
    required this.matches,
    required this.parsedArgs,
    required this.onPick,
  });

  final List<SlashCommand> matches;
  final String? parsedArgs;
  final void Function(SlashCommand) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            'No commands match that prefix.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: matches.length,
      itemBuilder: (_, i) {
        final c = matches[i];
        return ListTile(
          dense: true,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              c.icon,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            c.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          subtitle: Text(
            parsedArgs == null
                ? c.hint
                : '${c.hint} — args: $parsedArgs',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          onTap: () => onPick(c),
        );
      },
    );
  }
}

class _CapturePeekChip extends StatelessWidget {
  const _CapturePeekChip({required this.body, required this.onTap});

  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = body.trim().isEmpty ? '(empty)' : body.trim();
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 160,
            maxWidth: 220,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Text(
              preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
