import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/features/toolkit/toolkit_screen.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `/settings/toolkit/:slug` — standalone tool-detail screen used
/// when a phone canvas pushes from the catalog feed, when an omnibox
/// per-tool entry navigates here, or when a deep link lands directly
/// on a tool. The view itself is shared with the wide-pane right
/// column (see [ToolkitToolDetailView]); this widget only owns the
/// EdgeScaffold + back-stack behavior.
///
/// "Tool not found" path: if the slug doesn't match any catalog
/// entry (Wave 162 override hiding a built-in, typo, etc.) we render
/// a small error state with a back-to-toolkit affordance — not a
/// hard 404.
class ToolkitToolScreen extends StatelessWidget {
  const ToolkitToolScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final tool = findToolBySlug(slug);
    if (tool == null) {
      return const EdgeScaffold(
        backFallbackRoute: '/settings/toolkit',
        body: _UnknownTool(),
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
  const _UnknownTool();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                'It may have been renamed or hidden by your program.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/settings/toolkit');
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to toolkit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
