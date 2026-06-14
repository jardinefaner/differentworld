import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/identity/archetypes.dart';
import 'package:differentworld/features/today/role_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Your tools" — a compact, role-tailored shortcut strip on Today (role-as-
/// home; docs/VISION.md). Role picks the order (Role-1); the self-authored
/// archetype gently re-orders it so the tools that express how you show up lead
/// (Role-3, `tunedToolsFor`). Each tile still gates on capability. One
/// horizontal row so it adds signal without re-noising the (deliberately calm)
/// Today screen.
///
/// Distinct from `QuickActions` (state-driven: pending captures/tasks, return
/// a vehicle) — this is identity-driven: the tools THIS person reaches for.
class YourToolsStrip extends ConsumerWidget {
  const YourToolsStrip({required this.viewer, super.key});

  final Viewer viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Role-3: the archetype re-orders the role palette (no archetype → the
    // Role-1 order, untouched).
    final tools = tunedToolsFor(viewer);
    if (tools.isEmpty) return const SizedBox.shrink();
    // The glyph in the header is the affordance that EXPLAINS the re-order —
    // without it, "why is Insights first?" reads as random. Self-hides when no
    // archetype is set, leaving the plain Role-1 strip.
    final archetype = archetypeById(viewer.archetypeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            archetype == null ? 'Your tools' : 'Your tools  ${archetype.glyph}',
            style: theme.textTheme.labelMedium,
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tools.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _ToolTile(
              tool: tools[i],
              // Subtle accent on the tools your archetype draws forward — marks
              // the front cluster as "tuned to you" without shouting.
              emphasized: isAffinityTool(viewer, tools[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, this.emphasized = false});

  final RoleTool tool;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = emphasized
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final fg = emphasized ? scheme.onPrimaryContainer : scheme.primary;
    return SizedBox(
      width: 84,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push(tool.route));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.icon, color: fg),
                const SizedBox(height: 8),
                Text(
                  tool.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: emphasized ? scheme.onPrimaryContainer : null,
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
