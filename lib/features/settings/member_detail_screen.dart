import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/photo_source_sheet.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  subtitle: 'Requires state certification (MAT)',
                  enabled: canManage,
                  value: caps.getBool(MemberCaps.canAdministerMedication),
                  onChanged: (v) => _set(MemberCaps.canAdministerMedication, v),
                ),
                _CapSwitch(
                  label: 'Drive (field trips)',
                  enabled: canManage,
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
