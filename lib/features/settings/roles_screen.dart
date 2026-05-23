import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Roles & Permissions reference — a read-only directory of every
/// role offered in the active vertical + the default capabilities each
/// one ships with. Lives at `/settings/roles`.
///
/// **Why this exists**: directors don't know what each role can do
/// until they assign someone and watch what works. This screen makes
/// the bundle visible at a glance — "Group Leader gets observe +
/// attendance + meals + open/close + authorize-pickup + manage
/// schedule" — so the right role can be picked before invite.
///
/// Reads the per-vertical role list from `RoleBundles.rolesFor(vertical)`
/// and the per-role bundle via `RoleBundles.defaultsFor(role, vertical:)`,
/// then maps each capability key to a human label. No DB reads — the
/// catalog is a code constant, by design.
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labels = ref.watch(verticalLabelsProvider);
    final vertical = labels.vertical;
    final roles = RoleBundles.rolesFor(vertical);

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const ContentHeader(
            title: 'Roles & permissions',
            subtitle: 'What each role can do by default. Directors can '
                'fine-tune individual permissions on the Member detail '
                'screen.',
          ),
          for (final key in roles) ...[
            _RoleCard(roleKey: key, vertical: vertical),
            const SizedBox(height: 12),
          ],
          // Cert-gated reminder — these caps stay off until a
          // certification is added to the member, regardless of role.
          const SizedBox(height: 8),
          _CertGatedNote(theme: theme),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.roleKey, required this.vertical});

  final String roleKey;
  final String vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = RoleLabels.of(roleKey, vertical: vertical);
    final bundle = RoleBundles.defaultsFor(roleKey, vertical: vertical);
    final cans = <_CapRow>[];
    final certGated = <_CapRow>[];

    bundle.forEach((capKey, value) {
      if (value is! bool) return;
      final row = _CapRow(
        key: capKey,
        label: _capLabel(capKey),
        granted: value,
      );
      // Two caps are cert-gated and ship false on every role — surface
      // them in the bundle but in a separate group so directors don't
      // think "the bundle says false; I'll flip it" without realizing
      // the cert is the actual gate.
      if (capKey == CoreCaps.canDrive ||
          capKey == ChildcareCaps.canAdministerMedication) {
        certGated.add(row);
      } else if (value) {
        cans.add(row);
      }
    });

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconFor(roleKey),
                  size: 22,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    roleKey,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _summaryFor(roleKey),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (cans.isEmpty)
              Text(
                'No default permissions — assign manually on the Member '
                'detail screen.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              ...cans.map(
                (r) => _CapRowTile(label: r.label, granted: true),
              ),
            if (certGated.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Cert-gated (off until a certification is added)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              ...certGated.map(
                (r) => _CapRowTile(label: r.label, granted: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One-line summary of what this role IS — context the cap-bundle
  /// doesn't capture (responsibility, trust level, target persona).
  static String _summaryFor(String role) {
    return switch (role) {
      'director' => 'Full administrative access. Invites staff, edits '
          'roles, generates reports, manages the program.',
      'lead_teacher' => 'Owns a cohort full-time. Direct-care + '
          'authorizes pickup + plans the day for their kids.',
      'teacher' => 'Direct-care frontline. Observes, takes attendance, '
          'and records meals.',
      'substitute' => 'Temporary coverage. Low default trust — '
          'observes and takes attendance, but no pickup authorization '
          'or schedule edits until the director grants them.',
      'specialist' => 'Subject-matter staff (coach, tutor, health aide, '
          'and others). Cohort scope is controlled by group '
          'assignments; specialty is set on the Member detail screen.',
      'kitchen' => 'Meals only. Doesn’t observe, doesn’t take '
          'attendance, doesn’t see family contacts.',
      'guardian' => 'Family lens — read access to their linked '
          'children and messaging with staff.',
      _ => 'Custom role — caps come from the per-vertical bundle.',
    };
  }

  static IconData _iconFor(String role) {
    return switch (role) {
      'director' => Icons.shield_outlined,
      'lead_teacher' => Icons.group_work_outlined,
      'teacher' => Icons.person_outline,
      'substitute' => Icons.event_busy_outlined,
      'specialist' => Icons.school_outlined,
      'kitchen' => Icons.restaurant_outlined,
      'guardian' => Icons.family_restroom_outlined,
      _ => Icons.badge_outlined,
    };
  }
}

class _CapRow {
  const _CapRow({
    required this.key,
    required this.label,
    required this.granted,
  });

  final String key;
  final String label;
  final bool granted;
}

class _CapRowTile extends StatelessWidget {
  const _CapRowTile({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = granted ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.lock_outline,
            size: 16,
            color: tint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: granted ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertGatedNote extends StatelessWidget {
  const _CertGatedNote({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 20,
            color: scheme.tertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cert-gated permissions (driving, medication) stay off '
              'for everyone until the certification is added to their '
              'profile. Role alone is never enough — that’s a '
              'state-compliance safeguard, not a UI quirk.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Human label for a capability key. Falls back to a title-cased
/// echo of the key for unknowns so unrecognized values still render.
String _capLabel(String key) {
  return switch (key) {
    CoreCaps.canObserve => 'Log observations + write to families',
    CoreCaps.canTakeAttendance => 'Take attendance',
    CoreCaps.canDrive => 'Drive program vehicles',
    CoreCaps.canOpenBuilding => 'Open the building',
    CoreCaps.canCloseBuilding => 'Close the building',
    CoreCaps.canViewBilling => 'View billing',
    CoreCaps.canInviteStaff => 'Invite teammates',
    CoreCaps.canViewAuditLog => 'View audit log',
    CoreCaps.canActAsDirector => 'Act as a director',
    CoreCaps.canManageSchedule => 'Plan and edit the schedule',
    CoreCaps.isSpecialist => 'Marked as a specialist',
    ChildcareCaps.canRecordMeal => 'Log meals',
    ChildcareCaps.canRecordNap => 'Log naps',
    ChildcareCaps.canRecordDiaper => 'Log diaper changes',
    ChildcareCaps.canAdministerMedication => 'Administer medication',
    ChildcareCaps.canAuthorizePickup => 'Authorize pickup',
    _ => key
        .replaceAll('can_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' '),
  };
}
