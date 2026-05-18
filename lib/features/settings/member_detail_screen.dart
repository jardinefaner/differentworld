import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/certifications.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/group_assignments_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/photo_source_sheet.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

DateTime get _todayDate {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Per-member detail screen: shows role + capability checkboxes. Editing
/// is gated on the signed-in member being a director.
class MemberDetailScreen extends ConsumerStatefulWidget {
  const MemberDetailScreen({required this.memberId, super.key});

  final String memberId;

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  Capabilities? _draft;
  String? _draftRole;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final me = viewer.member;
    // Editing this screen requires Manage Program rights — director,
    // or a member with canActAsDirector. Renamed from `canManage` for
    // semantic clarity; the gate is the cap, not the role string.
    final canManage = viewer.canManageProgram;
    final memberAsync = ref.watch(_memberProvider(widget.memberId));

    return EdgeScaffold(
      backFallbackRoute: '/settings/team',
      actions: [
        if ((_draft != null || _draftRole != null) &&
            memberAsync.value != null)
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : () => _save(memberAsync.value!),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
      ],
      body: memberAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load member.')),
        data: (member) {
          if (member == null) {
            return const Center(child: Text('Member not found.'));
          }
          final currentRole = _draftRole ?? member.role;
          final caps = _draft ?? member.caps;
          final activeCerts = caps.getStringList(MemberCaps.certifications);
          final expiryMap =
              caps.getStringMap(MemberCaps.certificationExpirations);

          // A cert "counts" only if it's on file AND not expired.
          bool isValid(String key) {
            if (!activeCerts.contains(key)) return false;
            final iso = expiryMap[key];
            if (iso == null) return true; // no expiry = valid indefinitely
            final dt = DateTime.tryParse(iso);
            if (dt == null) return true;
            return !dt.isBefore(_todayDate);
          }

          final hasMatCert = isValid(Certifications.mat.key);
          final hasDriverCert = isValid(Certifications.driver.key);

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 56),
              Center(
                  child: PersonAvatar(
                    name: member.displayName,
                    photoUrl: member.avatarUrl,
                    radius: 40,
                    // Director can change anyone's photo; everyone else
                    // can change their own.
                    onTap: (canManage || me?.id == member.id)
                        ? () => PhotoSourceSheet.show(
                              context,
                              entity: PhotoEntity.member,
                              entityId: member.id,
                              hasExisting: member.avatarUrl != null,
                              displayName: member.displayName,
                            )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    member.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel(label: 'Role'),
                if (canManage)
                  _RoleSelector(
                    selected: currentRole,
                    onChanged: (next) {
                      setState(() {
                        _draftRole = next;
                        // Apply role defaults to caps draft so the toggles
                        // visually reflect the new bundle. Director can
                        // still override individual toggles after.
                        _draft = caps.mergedWith(
                          RoleBundles.defaultsFor(next),
                        );
                      });
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(_roleLabel(currentRole)),
                    subtitle: const Text(
                      'Only a director can change roles.',
                    ),
                  ),
                const Divider(),
                const _SectionLabel(label: 'Abilities'),
                _CapSwitch(
                  label: 'Observe',
                  subtitle: 'Record developmental observations',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canObserve),
                  onChanged: (v) => _set(MemberCaps.canObserve, v),
                ),
                _CapSwitch(
                  label: 'Take attendance',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canTakeAttendance),
                  onChanged: (v) => _set(MemberCaps.canTakeAttendance, v),
                ),
                _CapSwitch(
                  label: 'Record meals',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canRecordMeal),
                  onChanged: (v) => _set(MemberCaps.canRecordMeal, v),
                ),
                _CapSwitch(
                  label: 'Record naps',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canRecordNap),
                  onChanged: (v) => _set(MemberCaps.canRecordNap, v),
                ),
                _CapSwitch(
                  label: 'Record diaper changes',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canRecordDiaper),
                  onChanged: (v) => _set(MemberCaps.canRecordDiaper, v),
                ),
                _CapSwitch(
                  label: 'Administer medication',
                  subtitle: hasMatCert
                      ? 'MAT certification on file'
                      : (activeCerts.contains(Certifications.mat.key)
                          ? 'MAT certification has expired'
                          : 'Add the MAT certification below to enable'),
                  enabled: canManage && hasMatCert,
                  value: caps.getBool(MemberCaps.canAdministerMedication),
                  onChanged: (v) => _set(MemberCaps.canAdministerMedication, v),
                ),
                _CapSwitch(
                  label: 'Drive (field trips)',
                  subtitle: hasDriverCert
                      ? 'Driver record on file'
                      : (activeCerts.contains(Certifications.driver.key)
                          ? 'Driver certification has expired'
                          : 'Add the Driver certification below to enable'),
                  enabled: canManage && hasDriverCert,
                  value: caps.getBool(MemberCaps.canDrive),
                  onChanged: (v) => _set(MemberCaps.canDrive, v),
                ),
                _CapSwitch(
                  label: 'Open the building',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canOpenBuilding),
                  onChanged: (v) => _set(MemberCaps.canOpenBuilding, v),
                ),
                _CapSwitch(
                  label: 'Close the building',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canCloseBuilding),
                  onChanged: (v) => _set(MemberCaps.canCloseBuilding, v),
                ),
                _CapSwitch(
                  label: 'Authorize pickup changes',
                  subtitle: 'Add or remove guardians for a child',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canAuthorizePickup),
                  onChanged: (v) => _set(MemberCaps.canAuthorizePickup, v),
                ),
                _CapSwitch(
                  label: 'Invite staff',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canInviteStaff),
                  onChanged: (v) => _set(MemberCaps.canInviteStaff, v),
                ),
                _CapSwitch(
                  label: 'View billing',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canViewBilling),
                  onChanged: (v) => _set(MemberCaps.canViewBilling, v),
                ),
                _CapSwitch(
                  label: 'Act as director',
                  subtitle: 'Full admin when the director is offsite',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canActAsDirector),
                  onChanged: (v) => _set(MemberCaps.canActAsDirector, v),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),

                // Certifications — list of credentials on file. Some
                // (MAT, Driver) gate specific capabilities above; an
                // expired cert auto-disables its gated capability.
                const SizedBox(height: 24),
                const _SectionLabel(label: 'Certifications'),
                _CertificationsSection(
                  active: activeCerts,
                  expiries: expiryMap,
                  onToggle: canManage ? _toggleCert : null,
                  onSetExpiry: canManage ? _setCertExpiry : null,
                ),

                // Classroom assignments — director assigns this member
                // to specific rooms. Director themselves doesn't need
                // assignments (they see all rooms).
                if (member.role != 'director') ...[
                  const SizedBox(height: 24),
                  const _SectionLabel(label: 'Assigned classrooms'),
                  _AssignmentsList(
                    member: member,
                    canEdit: canManage,
                  ),
                ],

                const SizedBox(height: 24),
                // Director-only "Remove from team" — can't remove yourself.
                if (canManage && me?.id != member.id) ...[
                  const Divider(),
                  const _SectionLabel(label: 'Danger zone'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DestructiveButton(
                      label: 'Remove from team',
                      icon: Icons.person_remove_alt_1_outlined,
                      onPressed: _saving ? null : () => _removeFromTeam(member),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            );
        },
      ),
    );
  }

  Future<void> _removeFromTeam(Member member) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove ${member.displayName}?',
      message:
          'They will lose access to this program immediately. Their past '
          'attendance and notes stay attributed to them. You can re-invite '
          'them by email later.',
      confirmLabel: 'Remove from team',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = await ref.read(appDatabaseProvider.future);
      await db.removeMemberFromSpace(member.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'members'),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not remove. Please try again.';
      });
    }
  }

  void _set(String key, bool value) {
    setState(() {
      final base =
          _draft ??
          ref.read(_memberProvider(widget.memberId)).value?.caps ??
          const Capabilities.empty();
      _draft = base.setting(key, value);
    });
  }

  /// Add / remove a certification from the member's caps list. When
  /// removing a cert that gates a capability, also clears the gated
  /// cap to avoid the silent-mismatch where a switch was on but the
  /// cert was revoked. Removing also clears the cert's expiry entry.
  void _toggleCert(String certKey, bool add) {
    setState(() {
      final base =
          _draft ??
          ref.read(_memberProvider(widget.memberId)).value?.caps ??
          const Capabilities.empty();
      final existing = base.getStringList(MemberCaps.certifications);
      final next = {...existing};
      if (add) {
        next.add(certKey);
      } else {
        next.remove(certKey);
      }
      var updated = base.setting(MemberCaps.certifications, next.toList());
      if (!add) {
        // Cascade off gated caps + drop the expiry entry.
        for (final cert in Certifications.all) {
          if (cert.key != certKey) continue;
          for (final gated in cert.gatesCaps) {
            updated = updated.setting(gated, false);
          }
        }
        final expiries = Map<String, String>.from(
          base.getStringMap(MemberCaps.certificationExpirations),
        )..remove(certKey);
        updated = updated.setting(
          MemberCaps.certificationExpirations,
          expiries,
        );
      }
      _draft = updated;
    });
  }

  /// Set or clear the expiry date for a specific cert. Pass null to
  /// remove the expiry (cert becomes "valid indefinitely").
  void _setCertExpiry(String certKey, DateTime? date) {
    setState(() {
      final base =
          _draft ??
          ref.read(_memberProvider(widget.memberId)).value?.caps ??
          const Capabilities.empty();
      final expiries = Map<String, String>.from(
        base.getStringMap(MemberCaps.certificationExpirations),
      );
      if (date == null) {
        expiries.remove(certKey);
      } else {
        expiries[certKey] = '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
      }
      var updated = base.setting(
        MemberCaps.certificationExpirations,
        expiries,
      );
      // If we just set an expiry in the past, the cert effectively
      // expired — cascade off any caps it gates.
      if (date != null && date.isBefore(_todayDate)) {
        for (final cert in Certifications.all) {
          if (cert.key != certKey) continue;
          for (final gated in cert.gatesCaps) {
            updated = updated.setting(gated, false);
          }
        }
      }
      _draft = updated;
    });
  }

  Future<void> _save(Member member) async {
    // Runtime guard — the UI gates editing on canManage, but defence-
    // in-depth: refuse to write if the caller can't manage the program
    // regardless of how this method gets reached.
    final viewer = ref.read(viewerProvider);
    if (!viewer.canManageProgram) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = await ref.read(appDatabaseProvider.future);
      if (_draft != null) {
        await db.updateMemberCapabilities(
          member.id,
          _draft!.toJson(),
        );
      }
      if (_draftRole != null && _draftRole != member.role) {
        await db.updateMemberRole(member.id, _draftRole!);
      }
      if (!mounted) return;
      setState(() {
        _draft = null;
        _draftRole = null;
      });
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'members'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _roleLabel(String role) => switch (role) {
    'director' => 'Director',
    'lead_teacher' => 'Lead teacher',
    'teacher' => 'Teacher',
    'assistant' => 'Assistant',
    _ => role,
  };
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _memberProvider = StreamProvider.autoDispose.family<Member?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchMember(id);
  },
);

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const roles = [
      ('director', 'Director'),
      ('lead_teacher', 'Lead teacher'),
      ('teacher', 'Teacher'),
      ('assistant', 'Assistant'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          for (final (value, label) in roles)
            ChoiceChip(
              label: Text(label),
              selected: selected == value,
              onSelected: (s) {
                if (s) onChanged(value);
              },
            ),
        ],
      ),
    );
  }
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

class _CapSwitch extends StatelessWidget {
  const _CapSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// Per-classroom assignment list. Renders one row per classroom in
/// the space; the trailing widget is a Switch when [canEdit] is true
/// (director editing someone else) or a static check / dash when read-
/// only (anyone else viewing their own / others' assignments).
class _AssignmentsList extends ConsumerWidget {
  const _AssignmentsList({required this.member, required this.canEdit});

  final Member member;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(allGroupsInSpaceProvider);
    final assignmentsAsync =
        ref.watch(assignmentsForMemberProvider(member.id));

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
class _CertificationsSection extends StatelessWidget {
  const _CertificationsSection({
    required this.active,
    required this.expiries,
    required this.onToggle,
    required this.onSetExpiry,
  });

  final List<String> active;
  final Map<String, String> expiries;

  /// Positional bool: the callback is tiny and `add` reads naturally
  /// as the second arg.
  // ignore: avoid_positional_boolean_parameters
  final void Function(String certKey, bool add)? onToggle;
  final void Function(String certKey, DateTime? date)? onSetExpiry;

  bool _expired(String certKey) {
    final iso = expiries[certKey];
    if (iso == null) return false;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return false;
    return dt.isBefore(_todayDate);
  }

  Future<void> _editExpiry(BuildContext context, Certification cert) async {
    if (onSetExpiry == null) return;
    final current = expiries[cert.key];
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
    final activeCerts = Certifications.all.where(
      (c) => active.contains(c.key),
    );
    final inactiveCerts = Certifications.all.where(
      (c) => !active.contains(c.key),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active certs.
          for (final cert in activeCerts) ...[
            _ActiveCertRow(
              cert: cert,
              expiryIso: expiries[cert.key],
              expired: _expired(cert.key),
              onEditExpiry: onSetExpiry == null
                  ? null
                  : () => _editExpiry(context, cert),
              onRemove: onToggle == null
                  ? null
                  : () => onToggle!(cert.key, false),
            ),
            const SizedBox(height: 4),
          ],
          if (activeCerts.isNotEmpty && inactiveCerts.isNotEmpty)
            const SizedBox(height: 8),

          // Inactive — add chips.
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
                        color: expired
                            ? scheme.error
                            : scheme.onSurfaceVariant,
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
