import 'dart:async';

import 'package:differentworld/features/tools/thinking_tool.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `/tools` — the Thinking Tools library (docs/THINKING_TOOLS.md, Phase 1).
/// One searchable shelf over [buildToolLibrary]: the runnable activities (run
/// with the room) and the editorial reference cards, unified. Runnable tools
/// launch their activity; reference tools open a reading sheet.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
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
