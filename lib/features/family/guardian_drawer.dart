import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/family/family_providers.dart';
import 'package:differentworld/features/settings/widgets/text_size_tile.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The guardian-side hamburger drawer — the family equivalent of `MainDrawer`.
///
/// Guardians live on a tiny set of surfaces (Today, each child, Messages), and
/// before this they had no navigation at all: every move meant tapping back to
/// the Family Today card list, and the shell's hamburger opened the *staff*
/// drawer (full of capability-gated destinations a guardian can't use). This
/// gives them their own drawer in the same glass-chrome language — only the
/// surfaces a parent actually has.
class GuardianDrawer extends ConsumerWidget {
  const GuardianDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final viewer = ref.watch(viewerProvider);
    final space = viewer.space;
    final children =
        ref.watch(familyChildrenProvider).value ?? const <Subject>[];
    final atHome = GoRouterState.of(context).uri.path == '/';

    // Mirror MainDrawer: close the drawer, then navigate on the same context
    // synchronously (no await gap → no dead-context).
    void closeThen(VoidCallback go) {
      Navigator.of(context).pop();
      go();
    }

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: GlassPanel(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (space != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          space.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Row(
                      children: [
                        PersonAvatar(name: viewer.displayName, radius: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                viewer.displayName,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Parent',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sign out',
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            final ok = await confirmDestructive(
                              context,
                              title: 'Sign out?',
                              message:
                                  "You'll need to sign in again to see "
                                  "your child's day.",
                            );
                            if (!ok || !context.mounted) return;
                            // Pre-capture before the await; signOut flips auth
                            // state → the router redirects to /login and
                            // disposes this tree, so nothing touches context
                            // or ref after it.
                            final auth = ref.read(authActionsProvider);
                            Navigator.of(context).pop();
                            await auth.signOut();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('Today'),
                      selected: atHome,
                      onTap: () => closeThen(() => context.go('/')),
                    ),
                    if (children.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                        child: Text(
                          'Your children',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    for (final c in children)
                      ListTile(
                        leading: PersonAvatar(
                          name: '${c.firstName} ${c.lastName}'.trim(),
                          photoUrl: c.photoUrl,
                          radius: 16,
                        ),
                        title: Text('${c.firstName} ${c.lastName}'.trim()),
                        onTap: () =>
                            closeThen(() => context.push('/children/${c.id}')),
                      ),
                    const Divider(height: 16, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.forum_outlined),
                      title: const Text('Messages'),
                      onTap: () => closeThen(() => context.push('/messages')),
                    ),
                    ListTile(
                      leading: const Icon(Icons.live_tv_outlined),
                      title: const Text('Share from home'),
                      onTap: () => closeThen(() => context.push('/share-home')),
                    ),
                    ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('Display & text size'),
                      onTap: () {
                        // Capture the root navigator's context so the sheet
                        // keeps a live ancestor after the drawer pops.
                        final rootCtx = Navigator.of(
                          context,
                          rootNavigator: true,
                        ).context;
                        Navigator.of(context).pop();
                        unawaited(showTextSizePicker(rootCtx, ref));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
