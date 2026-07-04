import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/certifications.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/features/groups/group_assignments_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Midnight today in local time, used by [MemberCertificationsSection]
/// to decide whether a cert's expiry is in the past.
DateTime _todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Vertical-aware role picker chips with last-director protection.
///
/// Reads the role-key list from `RoleBundles.rolesFor(vertical)` and
/// labels each chip via `RoleLabels.of`. Construction sees PM / foreman /
/// etc.; childcare sees director / lead_teacher / etc.; no hardcoded
/// role list anywhere in this widget.
///
/// Selecting a chip flips the member's role AND re-applies the per-
/// vertical default cap bundle on top of their existing caps (via
/// `MemberCapActions.setRole`, which the caller wires through
/// [onChanged]).
///
/// **Last-director protection**: if THIS member is the only person in
/// the space with director-level privilege (by role OR by
/// `canActAsDirector` cap), the non-director chips are disabled with
/// an inline explanation. Without this gate, a single director could
/// demote themselves and orphan the space.
class MemberRoleSelector extends ConsumerWidget {
  const MemberRoleSelector({
    required this.memberId,
    required this.vertical,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String memberId;
  final String vertical;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labels = ref.watch(verticalLabelsProvider);
    final roles = RoleBundles.rolesFor(vertical);
    final directorRole = RoleBundles.directorRoleFor(vertical);

    final members = ref.watch(membersInSpaceProvider).value ?? const <Member>[];
    final admins = members
        .where((m) {
          if (m.role == directorRole) return true;
          return m.caps.getBool(CoreCaps.canActAsDirector);
        })
        .toList(growable: false);
    final iAmLastDirector =
        selected == directorRole &&
        admins.length == 1 &&
        admins.first.id == memberId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final key in roles)
                ChoiceChip(
                  label: Text(RoleLabels.of(key, vertical: vertical)),
                  selected: selected == key,
                  onSelected: (iAmLastDirector && key != directorRole)
                      ? null
                      : (s) {
                          if (s) onChanged(key);
                        },
                ),
            ],
          ),
          if (iAmLastDirector)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "You're the only "
                      '${RoleLabels.of(directorRole, vertical: vertical).toLowerCase()} '
                      'in this ${labels.space.toLowerCase()}. Promote '
                      'another teammate first, then come back here to '
                      'change your own role.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Specialty picker for `role: specialist` members (afterschool 4-12).
/// Reads / writes `member.capabilities.specialty`. The 7 catalog
/// values come from [SpecialtyKeys.all]; null means "no specialty
/// chosen yet" — the picker shows nothing selected and the team-list
/// row reads "Specialist" without a suffix.
class MemberSpecialtySelector extends StatelessWidget {
  const MemberSpecialtySelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// Current specialty key (null if unset).
  final String? selected;

  /// Receives the new key, or null when the user re-taps the
  /// currently-selected chip to clear it.
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final key in SpecialtyKeys.all)
            ChoiceChip(
              label: Text(SpecialtyKeys.labelOf(key)),
              selected: selected == key,
              onSelected: (s) => onChanged(s ? key : null),
            ),
        ],
      ),
    );
  }
}

/// Small all-caps section label used between groups of rows on the
/// member detail tabs.
class MemberSectionLabel extends StatelessWidget {
  const MemberSectionLabel({required this.label, super.key});

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

/// Per-classroom assignment list. Renders one row per classroom in
/// the space; the trailing widget is a Switch when [canEdit] is true
/// (director editing someone else) or a static check / dash when read-
/// only (anyone else viewing their own / others' assignments).
class MemberAssignmentsList extends ConsumerWidget {
  const MemberAssignmentsList({
    required this.member,
    required this.canEdit,
    super.key,
  });

  final Member member;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(allGroupsInSpaceProvider);
    final assignmentsAsync = ref.watch(assignmentsForMemberProvider(member.id));

    return groupsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          'Could not load classrooms.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'No classrooms exist yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return assignmentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Could not load assignments.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          data: (assignments) {
            final assignedIds = assignments.map((a) => a.groupId).toSet();
            return Column(
              children: [
                for (final g in groups)
                  SwitchListTile(
                    title: Text(g.name),
                    subtitle: g.ageRange == null ? null : Text(g.ageRange!),
                    value: assignedIds.contains(g.id),
                    onChanged: canEdit
                        ? (next) async {
                            final actions = ref.read(
                              groupAssignmentActionsProvider,
                            );
                            if (next) {
                              await actions.assign(
                                groupId: g.id,
                                memberId: member.id,
                              );
                            } else {
                              await actions.unassign(
                                groupId: g.id,
                                memberId: member.id,
                              );
                            }
                          }
                        : null,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Certifications section. Active certs render as full rows with
/// their expiry date (tap to edit, or "Set expiry" if none); inactive
/// certs render as add-chips. Expired certs render with an error tint
/// and an "Expired" badge.
class MemberCertificationsSection extends StatelessWidget {
  const MemberCertificationsSection({
    required this.active,
    required this.onToggle,
    required this.onSetExpiry,
    super.key,
  });

  /// Live list of certs the member holds, from `certsForMemberProvider`.
  final List<MemberCertification> active;

  /// Positional bool: the callback is tiny and `add` reads naturally
  /// as the second arg.
  // ignore: avoid_positional_boolean_parameters
  final void Function(String certKey, bool add)? onToggle;
  final void Function(String certKey, DateTime? date)? onSetExpiry;

  bool _expired(MemberCertification row) {
    final iso = row.expiresAt;
    if (iso == null || iso.isEmpty) return false;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return false;
    return dt.isBefore(_todayDate());
  }

  Future<void> _editExpiry(
    BuildContext context,
    Certification cert,
    MemberCertification? row,
  ) async {
    if (onSetExpiry == null) return;
    final current = row?.expiresAt;
    final currentDt = current == null ? null : DateTime.tryParse(current);
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDt ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 10),
      helpText: '${cert.label} valid until',
    );
    if (picked != null) {
      onSetExpiry!(cert.key, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final heldKeys = active.map((c) => c.certKey).toSet();
    final activeCerts = Certifications.all.where(
      (c) => heldKeys.contains(c.key),
    );
    final inactiveCerts = Certifications.all.where(
      (c) => !heldKeys.contains(c.key),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final cert in activeCerts) ...[
            Builder(
              builder: (rowContext) {
                final row = active.firstWhere((c) => c.certKey == cert.key);
                return _ActiveCertRow(
                  cert: cert,
                  expiryIso: row.expiresAt,
                  expired: _expired(row),
                  onEditExpiry: onSetExpiry == null
                      ? null
                      : () => _editExpiry(rowContext, cert, row),
                  onRemove: onToggle == null
                      ? null
                      : () => onToggle!(cert.key, false),
                );
              },
            ),
            const SizedBox(height: 4),
          ],
          if (activeCerts.isNotEmpty && inactiveCerts.isNotEmpty)
            const SizedBox(height: 8),
          if (inactiveCerts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final cert in inactiveCerts)
                  ActionChip(
                    avatar: Icon(Icons.add, size: 16, color: scheme.primary),
                    label: Text(cert.label),
                    tooltip: cert.description,
                    onPressed: onToggle == null
                        ? null
                        : () => onToggle!(cert.key, true),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActiveCertRow extends StatelessWidget {
  const _ActiveCertRow({
    required this.cert,
    required this.expiryIso,
    required this.expired,
    required this.onEditExpiry,
    required this.onRemove,
  });

  final Certification cert;
  final String? expiryIso;
  final bool expired;
  final VoidCallback? onEditExpiry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final expiryDt = expiryIso == null ? null : DateTime.tryParse(expiryIso!);
    final expirySubtitle = expiryDt == null
        ? 'No expiry set · tap to add'
        : 'Valid until ${DateFormat.yMMMd().format(expiryDt)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: expired
            ? scheme.errorContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            expired ? Icons.error_outline : Icons.verified_outlined,
            color: expired ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cert.label, style: theme.textTheme.titleMedium),
                    if (expired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Expired',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onError,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                InkWell(
                  onTap: onEditExpiry,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      expirySubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: expired ? scheme.error : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
