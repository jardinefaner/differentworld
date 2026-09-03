import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/roles/preview_banner.dart';
import 'package:differentworld/features/roles/your_work.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Your place — what you can do, and where (docs/CAPABILITIES.md).
///
/// Every other permission surface in the app is about SOMEBODY ELSE: the
/// roles reference describes roles in general, the member editor is a
/// director configuring a teammate. Nobody could see their own.
///
/// Three states, not two, and the third is the point: **can**, **needs a
/// certificate** (yours to fix — add a licence and it opens), and **needs
/// someone** (a decision another person makes, so it names who to ask). A
/// wall and a next step should not look the same.
class YourWorkScreen extends ConsumerWidget {
  const YourWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    // The room a route needs to be concrete. First cohort is a reasonable
    // default; a person with no room still gets the program-wide routes.
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final work = workFor(
      viewer,
      primaryGroupId: groups.isEmpty ? null : groups.first.id,
    );

    return EdgeScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const ContentHeader(title: 'What you can do'),
                Row(
                  children: [
                    PersonAvatar(
                      name: viewer.displayName,
                      photoUrl: viewer.member?.avatarUrl,
                      radius: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viewer.displayName,
                            style: theme.textTheme.bodyLarge,
                          ),
                          Text(
                            viewer.roleLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  workSummary(work),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                // Directors only. The gate that MATTERS is in viewerProvider
                // — preview swaps in a role's DEFAULT bundle and only a
                // director may set it, so a counselor cannot preview their
                // way to more access. Hiding the affordance as well just
                // stops it being a discoverable dead end for everyone else.
                if (canPreviewRoles(viewer)) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(pickPreviewRole(context, ref)),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('See the app as someone else'),
                  ),
                ],
                const SizedBox(height: 20),
                for (final g in work)
                  _WorkBand(key: ValueKey('band-${g.title}'), group: g),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkBand extends StatelessWidget {
  const _WorkBand({required this.group, super.key});

  final WorkGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
          ),
        ),
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final item in group.items)
              _WorkRow(key: ValueKey('work-${item.label}'), item: item),
          ],
        ),
      ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  const _WorkRow({required this.item, super.key});

  final WorkItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = switch (item.kind) {
      WorkKind.can => scheme.primary,
      // Amber-ish: a thing to go and do, not a refusal.
      WorkKind.needsCert => scheme.tertiary,
      WorkKind.needsSomeone => scheme.onSurfaceVariant,
    };
    final route = item.route;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconFor(item.kind), size: 18, color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: item.open ? null : scheme.onSurfaceVariant,
                  ),
                ),
                // The journey, not the feature name. An open row explains
                // WHY you would land there; a blocked one still shows the
                // moment, then who to ask — so you know what you are
                // missing, not just that something is missing.
                if (item.journey != null)
                  Text(
                    item.journey!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (item.note != null)
                  Text(
                    item.note!,
                    style: theme.textTheme.bodySmall?.copyWith(color: colour),
                  ),
              ],
            ),
          ),
          if (item.open && route != null)
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
    );

    // Only OPEN items are tappable. Routing someone into a screen that will
    // refuse them is the dead-end this whole surface exists to remove.
    if (!item.open || route == null) return row;
    return InkWell(onTap: () => unawaited(context.push(route)), child: row);
  }
}
