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

/// Settings index — list of sections (Program / Team / About).
/// Each row navigates to a focused detail screen.
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
          const _SectionLabel(
            label: 'Signed in as',
          ),
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
                  await ref.read(authActionsProvider).signOut();
                },
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Sign out'),
              ),
            ),
            const Divider(),
            const _SectionLabel(label: 'Program'),
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
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Team'),
              subtitle: const Text('Members and their abilities'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/team'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_bus_outlined),
              title: const Text('Vehicles'),
              subtitle: const Text(
                'Fleet vehicles, pre-trip checks, check-in/out',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/vehicles'),
            ),
            const Divider(),
            const _SectionLabel(label: 'About'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Different World'),
              subtitle: Text('v0.1 · offline-first classroom logging'),
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
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
