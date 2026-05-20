import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/photo_source_sheet.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings index — list of sections (Account / Program / About).
/// Each row navigates to a focused detail screen.
///
/// Sections are rendered inside grouped containers so they read as
/// iOS-style grouped lists — clearer hierarchy than a flat stack of
/// `ListTile`s with dividers.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final member = viewer.member;

    return EdgeScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(title: 'Settings', bottomGap: 8),
          ),

          // Account
          _SettingsGroup(
            label: 'Signed in as',
            children: [
              ListTile(
                leading: PersonAvatar(
                  name: member?.displayName ?? '?',
                  photoUrl: member?.avatarUrl,
                  onTap: member == null
                      ? null
                      : () => PhotoSourceSheet.show(
                            context,
                            entity: PhotoEntity.member,
                            entityId: member.id,
                            hasExisting: member.avatarUrl != null,
                            displayName: member.displayName,
                          ),
                ),
                title: Text(member?.displayName ?? '—'),
                subtitle: Text(
                  _roleLabel(member?.role),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: TextButton.icon(
                  onPressed: () async {
                    final ok = await _confirmSignOut(context);
                    if (!ok) return;
                    await ref.read(authActionsProvider).signOut();
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),

          // Program
          _SettingsGroup(
            label: 'Program',
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Program settings'),
                subtitle: const Text(
                  "What's tracked program-wide, pickup window, defaults",
                ),
                trailing: const Icon(Icons.chevron_right),
                enabled: viewer.canManageProgram,
                onTap: viewer.canManageProgram
                    ? () => context.push('/settings/program')
                    : null,
              ),
              const _SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Team'),
                subtitle: const Text('Members and their abilities'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/team'),
              ),
              const _SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.directions_bus_outlined),
                title: const Text('Vehicles'),
                subtitle: const Text(
                  'Fleet vehicles, pre-trip checks, check-in/out',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/vehicles'),
              ),
            ],
          ),

          // Preferences — appearance / language stubs. These don't
          // yet have detail screens; the rows are visible so the user
          // knows the affordance is coming and what's planned.
          _SettingsGroup(
            label: 'Preferences',
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Appearance'),
                subtitle: const Text(
                  'Light / Dark / Match the system — coming soon',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Appearance settings are coming soon.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          // About — version + privacy commitment. The privacy row is
          // non-negotiable for v1; childcare regulators read this.
          _SettingsGroup(
            label: 'About',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Different World'),
                subtitle: Text('v0.1 · offline-first classroom logging'),
              ),
              const _SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy & data'),
                subtitle: const Text(
                  "How we handle children's information",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Different World',
                    applicationVersion: 'v0.1',
                    children: const [
                      SizedBox(height: 8),
                      Text(
                        "Children's data lives on this device first. "
                        'It syncs to a private Supabase project under '
                        'your program. We never sell or share it.',
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Parents or directors can request a full data '
                        'export or deletion at any time — email your '
                        'program director.',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _roleLabel(String? role) => switch (role) {
    'director' => 'Director',
    'lead_teacher' => 'Lead teacher',
    'teacher' => 'Teacher',
    'assistant' => 'Assistant',
    _ => '—',
  };

  /// Sign-out is a one-way action that wipes the user's view; a small
  /// confirm step prevents fat-finger accidents on the avatar row.
  Future<bool> _confirmSignOut(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              'Your local data stays on this device. You can sign in '
              'again anytime.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Grouped settings container — iOS-style label above, soft-tinted
/// rounded box around the children. Replaces the flat stream of
/// `ListTile`s + dividers that read as a checkbox list.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.4,
          ),
    );
  }
}
