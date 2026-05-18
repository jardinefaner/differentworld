import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/drift_provider.dart';
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
    final member = ref.watch(currentMemberProvider).value;
    final isDirector = member?.role == 'director';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            const _SectionLabel(
              label: 'Signed in as',
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
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
              enabled: isDirector,
              onTap:
                  isDirector ? () => context.push('/settings/program') : null,
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Team'),
              subtitle: const Text('Members and their abilities'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/team'),
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
