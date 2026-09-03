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
///
/// **What it does NOT simulate, and this matters when reading what you
/// see:** only `role` and `capabilities` are swapped. Your member id flows
/// through unchanged, so anything keyed to WHO YOU ARE rather than what you
/// may do stays yours — your room assignments, your certifications, your
/// own observations.
///
/// The visible consequence is worth knowing in advance:
/// `seesAllClassrooms` is `isDirector`, so the moment you preview as
/// anything else the room list stops showing everything and falls back to
/// the rooms YOU are personally assigned to via `group_members`. A director
/// is usually staffed to none, so previewing often shows an EMPTY room
/// list. That is not a bug in the preview and not what a real counselor
/// sees — it is you, with a counselor's permissions.
///
/// Faking an assignment would be worse: you would be looking at a room
/// nobody is really in and drawing conclusions from it. So the banner says
/// what the lens covers instead.
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seeing the app as ${RoleLabels.of(override)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    // Naming the limit is the difference between a useful
                    // lens and a misleading one.
                    Text(
                      'Their permissions, your rooms and data',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
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
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('See the app as…'),
                SizedBox(height: 2),
                Text(
                  'You get their permissions. Your own rooms, certificates '
                  'and notes stay yours — so the room list may look emptier '
                  'than a real teammate’s.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
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
