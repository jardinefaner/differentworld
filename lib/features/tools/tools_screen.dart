import 'dart:async';

import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/tools/thinking_tool.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/tools` — the Thinking Tools library (docs/THINKING_TOOLS.md, Phase 1).
/// One searchable shelf over [buildToolLibrary]: the runnable activities (run
/// with the room) and the editorial reference cards, unified. Runnable tools
/// launch their activity; reference tools open a reading sheet.
///
/// Two layouts over the SAME filtered list: the default one-per-row shelf, and
/// a BENTO grid (opt-in via the global "Bento everywhere" switch) that re-lays
/// the same short launchers 2-up on a phone. Same search / open behaviour.
class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ThinkingTool> get _filtered {
    final q = _query.trim().toLowerCase();
    final all = buildToolLibrary();
    if (q.isEmpty) return all;
    return all.where((t) => t.searchHaystack.contains(q)).toList();
  }

  void _open(ThinkingTool tool) {
    if (tool.isRunnable && tool.route != null) {
      unawaited(context.push(tool.route!));
    } else {
      unawaited(_showReference(tool));
    }
  }

  Future<void> _showReference(ThinkingTool tool) {
    return showGlassSheet<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tool.name, style: theme.textTheme.titleLarge),
                    if (tool.whenToUse != null) ...[
                      const SizedBox(height: 14),
                      _RefSection(
                        label: 'When to reach for it',
                        body: tool.whenToUse!,
                      ),
                    ],
                    if (tool.why != null) ...[
                      const SizedBox(height: 14),
                      _RefSection(label: 'Why it works', body: tool.why!),
                    ],
                    if (tool.script != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Say it',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tool.script!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = _filtered;
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the same filtered launchers re-lay as a
    // dense 2-up grid instead of the one-per-row shelf.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      body: SafeArea(
        bottom: false,
        // Cap the width so the shelf doesn't stretch sparse on desktop.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Tools',
                    subtitle:
                        'Thinking tools — run one with the room, or read the '
                        'move',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search tools',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Clear',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: tools.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off,
                          title: 'No tools match',
                          message:
                              'Try a different word — like "story", '
                              '"discuss", or "celebrate".',
                        )
                      : bento
                      ? _bentoGrid(tools)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: tools.length,
                          itemBuilder: (context, i) => _ToolTile(
                            tool: tools[i],
                            onTap: () => _open(tools[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The bento variant — SAME filtered list, re-laid as a dense lazy grid. The
  /// short launchers are uniform 2-up cells on a phone (≈180dp wide), more
  /// across wider screens — a hub of equal-weight destinations reads as a
  /// uniform grid (docs/GRID.md). The `GridView.builder` stays lazy, so a long
  /// library still constructs cells on demand. Each cell is a compact vertical
  /// card (the one-line `FeatureCard` row doesn't pack into a square), keeping
  /// the same kind glyph + Run/Read affordance and the same `_open` tap.
  Widget _bentoGrid(List<ThinkingTool> tools) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // A generous min so the title (≤3 lines) + blurb + kind chip don't
        // clip the 2-up phone cells as text scale grows.
        mainAxisExtent: 158,
      ),
      itemCount: tools.length,
      itemBuilder: (context, i) => _ToolGridCard(
        key: ValueKey('tool-${tools[i].id}'),
        tool: tools[i],
        onTap: () => _open(tools[i]),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.onTap});

  final ThinkingTool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runnable = tool.isRunnable;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FeatureCard(
        leading: CircleAvatar(
          backgroundColor:
              (runnable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary)
                  .withValues(alpha: 0.14),
          child: Icon(
            runnable ? Icons.play_circle_outline : Icons.menu_book_outlined,
            color: runnable
                ? theme.colorScheme.primary
                : theme.colorScheme.secondary,
          ),
        ),
        title: tool.name,
        subtitle: tool.blurb,
        // Kind shown by icon + word (never color alone): a "Run" pill for
        // runnable, a chevron for the reference reading sheet.
        trailing: runnable
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Run',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Semantics(
                label: 'Open reference',
                child: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}

/// Compact vertical card used in the bento 2-up grid — the same content as
/// [_ToolTile] (kind glyph, name, blurb, Run/Read affordance) re-shaped to fit
/// a fixed-height square cell. `mainAxisSize.min` + a `Spacer`-free column keep
/// it within the bounded cell without overflow.
class _ToolGridCard extends StatelessWidget {
  const _ToolGridCard({required this.tool, required this.onTap, super.key});

  final ThinkingTool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final runnable = tool.isRunnable;
    final accent = runnable ? scheme.primary : scheme.secondary;
    return Semantics(
      label: '${tool.name}, ${runnable ? 'run with the room' : 'reference'}',
      button: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    runnable
                        ? Icons.play_circle_outline
                        : Icons.menu_book_outlined,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tool.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    tool.blurb,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                // Kind shown by icon + word (never color alone) — matches the
                // row variant's trailing affordance.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      runnable ? Icons.play_arrow_rounded : Icons.chevron_right,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      runnable ? 'Run' : 'Read',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
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

class _RefSection extends StatelessWidget {
  const _RefSection({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(body, style: theme.textTheme.bodyLarge?.copyWith(height: 1.35)),
      ],
    );
  }
}
