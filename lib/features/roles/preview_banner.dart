import 'dart:async';

import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/core/viewer/viewer_override.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// You are looking through somebody else's eyes.
///
/// Role preview is genuinely useful — each role's home differs, and the only
/// honest way to know whether a new counselor can reach their own work is to
/// look. But a lens you can forget you are wearing is a trap: a director who
/// stops seeing Billing would conclude the app broke, and every observation
/// they made about "the app" from then on would be about a role they are not.
///
/// So the preview announces itself continuously and exits in one tap. No
/// timeout, no subtlety — this is the one place where a permanent banner is
/// correct, because the state it describes is permanent until dismissed and
/// silently wrong the whole time it is not.
class PreviewBanner extends ConsumerWidget {
  const PreviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(viewerKindOverrideProvider);
    if (override == null || override.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.tertiaryContainer,
      child: InkWell(
        onTap: () => ref.read(viewerKindOverrideProvider.notifier).clear(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Seeing the app as ${RoleLabels.of(override)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              Text(
                'Back to mine',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Open the role picker. Directors only — the gate is in `viewerProvider`,
/// but hiding the affordance too keeps it from being a discoverable
/// dead end for everyone else.
Future<void> pickPreviewRole(BuildContext context, WidgetRef ref) async {
  const roles = RoleBundlesPreview.previewable;
  final chosen = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('See the app as…'),
            ),
          ),
          for (final r in roles)
            ListTile(
              title: Text(RoleLabels.of(r)),
              onTap: () => Navigator.of(ctx).pop(r),
            ),
          ListTile(
            leading: const Icon(Icons.undo),
            title: const Text('Back to mine'),
            onTap: () => Navigator.of(ctx).pop(''),
          ),
        ],
      ),
    ),
  );
  if (chosen == null) return;
  ref
      .read(viewerKindOverrideProvider.notifier)
      .set(
        chosen.isEmpty ? null : chosen,
      );
}

/// The roles worth previewing — everything a real person on this team could
/// be. Excludes the viewer's own, which would be a no-op.
abstract class RoleBundlesPreview {
  static const previewable = <String>[
    'lead_teacher',
    'teacher',
    'specialist',
    'substitute',
  ];
}

/// Convenience for callers that only want to know whether to show the entry
/// point at all.
bool canPreviewRoles(Viewer viewer) => viewer.isDirector;
