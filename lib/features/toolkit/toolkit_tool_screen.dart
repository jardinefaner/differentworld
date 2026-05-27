import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/features/toolkit/toolkit_screen.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `/settings/toolkit/:slug` — full-screen detail for one tool.
///
/// On phone-width canvases, the catalog screen pushes here so each
/// tool gets the whole screen. On wider canvases the master-detail
/// scaffold on `/settings/toolkit` already shows the detail to the
/// right of the master list — but this screen still works there
/// (a user deep-linking to a tool slug lands here regardless of
/// width). To keep the desktop experience coherent, the screen
/// detects wider widths in `initState` and silently redirects to the
/// master-detail surface so the user sees the list alongside the
/// detail.
///
/// "Tool not found" path: if the slug doesn't match any catalog
/// entry (typo, deleted Wave-162 override, etc.) we render a small
/// error state with a back-to-toolkit affordance — not a hard 404.
class ToolkitToolScreen extends StatelessWidget {
  const ToolkitToolScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final tool = findToolBySlug(slug);
    if (tool == null) {
      return EdgeScaffold(
        backFallbackRoute: '/settings/toolkit',
        body: _UnknownTool(slug: slug),
      );
    }
    final category = categoryById(tool.categoryId);
    return EdgeScaffold(
      backFallbackRoute: '/settings/toolkit',
      body: ToolkitToolDetailView(tool: tool, category: category),
    );
  }
}

class _UnknownTool extends StatelessWidget {
  const _UnknownTool({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.help_outline,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              "We don't have a tool with that name.",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              slug,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/settings/toolkit'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to toolkit'),
            ),
          ],
        ),
      ),
    );
  }
}
