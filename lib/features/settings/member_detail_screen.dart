import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/certifications.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/certifications/certifications_providers.dart';
import 'package:differentworld/features/groups/group_assignments_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/photo_source_sheet.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/cap_switch.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
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

/// Per-member detail screen: role + capability toggles + certs.
///
/// Per `docs/UX_DECISIONS.md §1`, capability toggles **auto-save** —
/// no draft state, no Save button. Each `onChanged` writes through
/// [MemberCapActions]. The Switch's `value:` reads from the live
/// Drift stream, so the displayed state always matches the DB.
class MemberDetailScreen extends ConsumerStatefulWidget {
  const MemberDetailScreen({required this.memberId, super.key});

  final String memberId;

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  /// Only used by the destructive "Remove from team" action — disables
  /// it while the delete is in flight.
  bool _removing = false;
  String? _error;

  Future<void> _setCap(String key, bool value) async {
    try {
      await ref
          .read(memberCapActionsProvider)
          .setCap(widget.memberId, key, value);
    } on Exception catch (e, st) {
      _onSaveError(e, st);
    }
  }

  Future<void> _setRole(String role) async {
    try {
      await ref
          .read(memberCapActionsProvider)
          .setRole(widget.memberId, role);
    } on Exception catch (e, st) {
      _onSaveError(e, st);
    }
  }

  Future<void> _setSpecialty(String? specialty) async {
    try {
      await ref
          .read(memberCapActionsProvider)
          .setSpecialty(widget.memberId, specialty);
    } on Exception catch (e, st) {
      _onSaveError(e, st);
    }
  }

  Future<void> _toggleCert(String certKey, bool add) async {
    try {
      final actions = ref.read(certActionsProvider);
      if (add) {
        await actions.add(memberId: widget.memberId, certKey: certKey);
      } else {
        await actions.remove(
          memberId: widget.memberId,
          certKey: certKey,
        );
      }
    } on Exception catch (e, st) {
      _onSaveError(e, st);
    }
  }

  Future<void> _setCertExpiry(String certKey, DateTime? date) async {
    try {
      await ref.read(certActionsProvider).setExpiry(
            memberId: widget.memberId,
            certKey: certKey,
            expiresAt: date,
          );
    } on Exception catch (e, st) {
      _onSaveError(e, st);
    }
  }

  void _onSaveError(Exception e, StackTrace st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: 'members'),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(content: Text("Couldn't save that change. Try again.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final me = viewer.member;
    // Editing this screen requires Manage Program rights — director,
    // or a member with canActAsDirector. Renamed from `canManage` for
    // semantic clarity; the gate is the cap, not the role string.
    final canManage = viewer.canManageSpace;
    final memberAsync = ref.watch(_memberProvider(widget.memberId));
    // Pull the active vertical so the role picker + labels render
    // per-vertical options (childcare's director vs construction's pm
    // vs healthcare's physician, etc.).
    final labels = ref.watch(verticalLabelsProvider);
    final vertical = labels.vertical;

    // No save action — toggles auto-save (UX_DECISIONS §1).
    return EdgeScaffold(
      backFallbackRoute: '/settings/team',
      body: memberAsync.when(
        loading: () => const LoadingSlot(),
        error: (e, _) => const Center(child: Text('Could not load member.')),
        data: (member) {
          if (member == null) {
            return const Center(child: Text('Member not found.'));
          }
          final currentRole = member.role;
          final caps = member.caps;
          // Certs are now their own table; the cap-gating UI reads
          // from that stream so an expired MAT immediately disables
          // "Administer medication" without manual refresh.
          final certsAsync =
              ref.watch(certsForMemberProvider(widget.memberId));
          final activeCerts =
              certsAsync.value ?? const <MemberCertification>[];
          final hasMatCert = activeCerts.isValid(Certifications.mat.key);
          final hasDriverCert = activeCerts.isValid(Certifications.driver.key);

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                // ContentHeader reserves chrome height + status bar
                // inset so the avatar/identity row below sits clear
                // of the floating chrome pills (Wave 53 layout law,
                // wave 59 conformance).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: member.displayName,
                    bottomGap: 4,
                  ),
                ),
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
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    RoleLabels.of(currentRole, vertical: vertical),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: [
                    Tab(text: 'Profile'),
                    // "Certs & access" rather than "Permissions" — the
                    // primary reason most directors open this screen
                    // is adding/renewing a certification (Wave 64 UX
                    // rerank); the tab label leads with that.
                    Tab(text: 'Certs & access'),
                    Tab(text: 'Assignments'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // -- Tab 1: Profile ----------------------------
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          const _SectionLabel(label: 'Role'),
                          if (canManage)
                            _RoleSelector(
                              memberId: member.id,
                              vertical: vertical,
                              selected: currentRole,
                              onChanged: _setRole,
                            )
                          else
                            ListTile(
                              leading: const Icon(Icons.shield_outlined),
                              title: Text(
                                RoleLabels.of(currentRole, vertical: vertical),
                              ),
                              subtitle: const Text(
                                'Only a director can change roles.',
                              ),
                            ),
                          // Specialty picker — only relevant for
                          // `role: specialist`. Directors edit it;
                          // others see it as a read-only label inline
                          // with the role above.
                          if (currentRole == 'specialist') ...[
                            const SizedBox(height: 16),
                            const _SectionLabel(label: 'Specialty'),
                            if (canManage)
                              _SpecialtySelector(
                                selected:
                                    member.caps.getString(ChildcareCaps.specialty),
                                onChanged: _setSpecialty,
                              )
                            else
                              ListTile(
                                leading: const Icon(Icons.school_outlined),
                                title: Text(
                                  SpecialtyKeys.labelOf(
                                    member.caps.getString(
                                      ChildcareCaps.specialty,
                                    ),
                                  ),
                                ),
                                subtitle: const Text(
                                  'Only a director can change specialty.',
                                ),
                              ),
                          ],
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                0,
                              ),
                              child: Text(
                                _error!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                              ),
                            ),
                        ],
                      ),

                      // -- Tab 2: Certs & access ---------------------
                      // Certifications first (primary reason directors
                      // open Member Detail per Wave 64 UX rerank),
                      // then the per-cap toggles below: vertical-
                      // agnostic core verbs and vertical-specific
                      // extras.
                      ListView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          const _SectionLabel(label: 'Certifications'),
                          _CertificationsSection(
                            active: activeCerts,
                            onToggle: canManage ? _toggleCert : null,
                            onSetExpiry:
                                canManage ? _setCertExpiry : null,
                          ),
                          const SizedBox(height: 24),
                          const _SectionLabel(label: 'Core abilities'),
                          CapSwitch(
                            label: 'Observe',
                            subtitle:
                                'Record developmental observations',
                            enabled: canManage,
                            value: caps.getBool(CoreCaps.canObserve),
                            onChanged: (v) =>
                                _setCap(CoreCaps.canObserve, v),
                          ),
                          CapSwitch(
                            label: 'Take attendance',
                            enabled: canManage,
                            value: caps.getBool(
                              CoreCaps.canTakeAttendance,
                            ),
                            onChanged: (v) => _setCap(
                              CoreCaps.canTakeAttendance,
                              v,
                            ),
                          ),
                          CapSwitch(
                            label: 'Drive',
                            subtitle: hasDriverCert
                                ? 'Driver record on file'
                                : (activeCerts.holds(
                                        Certifications.driver.key)
                                    ? 'Driver certification has expired'
                                    : 'Add the Driver certification below to enable'),
                            enabled: canManage && hasDriverCert,
                            value: caps.getBool(CoreCaps.canDrive),
                            onChanged: (v) =>
                                _setCap(CoreCaps.canDrive, v),
                          ),
                          CapSwitch(
                            label: 'Open the building',
                            enabled: canManage,
                            value: caps.getBool(
                              CoreCaps.canOpenBuilding,
                            ),
                            onChanged: (v) => _setCap(
                              CoreCaps.canOpenBuilding,
                              v,
                            ),
                          ),
                          CapSwitch(
                            label: 'Close the building',
                            enabled: canManage,
                            value: caps.getBool(
                              CoreCaps.canCloseBuilding,
                            ),
                            onChanged: (v) => _setCap(
                              CoreCaps.canCloseBuilding,
                              v,
                            ),
                          ),
                          CapSwitch(
                            label: 'Manage schedule',
                            enabled: canManage,
                            value: caps.getBool(
                              CoreCaps.canManageSchedule,
                            ),
                            onChanged: (v) => _setCap(
                              CoreCaps.canManageSchedule,
                              v,
                            ),
                          ),
                          CapSwitch(
                            label: 'Invite staff',
                            enabled: canManage,
                            value: caps.getBool(
                              CoreCaps.canInviteStaff,
                            ),
                            onChanged: (v) => _setCap(
                              CoreCaps.canInviteStaff,
                              v,
                            ),
                          ),
                          CapSwitch(
                            label: 'View billing',
                            enabled: canManage,
                            value: caps.getBool(
                              CoreCaps.canViewBilling,
                            ),
                            onChanged: (v) => _setCap(
                              CoreCaps.canViewBilling,
                              v,
                            ),
                          ),
                          CapSwitch(
                            label: 'Act as director',
                            subtitle:
                                'Full admin when the director is offsite',
                            enabled: canManage,
                            value: caps.getBool(
                              CoreCaps.canActAsDirector,
                            ),
                            onChanged: (v) => _setCap(
                              CoreCaps.canActAsDirector,
                              v,
                            ),
                          ),
                          // Vertical-specific extras. Today only
                          // childcare has a hand-written set; future
                          // verticals add their own block here.
                          if (vertical == 'childcare') ...[
                            const SizedBox(height: 16),
                            const _SectionLabel(label: 'Childcare verbs'),
                            CapSwitch(
                              label: 'Record meals',
                              enabled: canManage,
                              value: caps.getBool(
                                ChildcareCaps.canRecordMeal,
                              ),
                              onChanged: (v) => _setCap(
                                ChildcareCaps.canRecordMeal,
                                v,
                              ),
                            ),
                            CapSwitch(
                              label: 'Record naps',
                              enabled: canManage,
                              value: caps.getBool(
                                ChildcareCaps.canRecordNap,
                              ),
                              onChanged: (v) =>
                                  _setCap(ChildcareCaps.canRecordNap, v),
                            ),
                            CapSwitch(
                              label: 'Record diaper changes',
                              enabled: canManage,
                              value: caps.getBool(
                                ChildcareCaps.canRecordDiaper,
                              ),
                              onChanged: (v) => _setCap(
                                ChildcareCaps.canRecordDiaper,
                                v,
                              ),
                            ),
                            CapSwitch(
                              label: 'Administer medication',
                              subtitle: hasMatCert
                                  ? 'MAT certification on file'
                                  : (activeCerts.holds(
                                          Certifications.mat.key)
                                      ? 'MAT certification has expired'
                                      : 'Add the MAT certification below to enable'),
                              enabled: canManage && hasMatCert,
                              value: caps.getBool(
                                ChildcareCaps.canAdministerMedication,
                              ),
                              onChanged: (v) => _setCap(
                                ChildcareCaps.canAdministerMedication,
                                v,
                              ),
                            ),
                            CapSwitch(
                              label: 'Authorize pickup changes',
                              subtitle:
                                  'Add or remove guardians for a child',
                              enabled: canManage,
                              value: caps.getBool(
                                ChildcareCaps.canAuthorizePickup,
                              ),
                              onChanged: (v) => _setCap(
                                ChildcareCaps.canAuthorizePickup,
                                v,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // -- Tab 3: Assignments ------------------------
                      ListView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          if (member.role != 'director') ...[
                            _SectionLabel(
                              label:
                                  'Assigned ${labels.groupPlural.toLowerCase()}',
                            ),
                            _AssignmentsList(
                              member: member,
                              canEdit: canManage,
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Directors see every '
                                '${labels.group.toLowerCase()} — no '
                                'specific assignments needed.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          if (canManage && me?.id != member.id) ...[
                            const SizedBox(height: 32),
                            const Divider(),
                            const _SectionLabel(label: 'Danger zone'),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: DestructiveButton(
                                label: 'Remove from team',
                                icon:
                                    Icons.person_remove_alt_1_outlined,
                                onPressed: _removing
                                    ? null
                                    : () => _removeFromTeam(member),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
      _removing = true;
      _error = null;
    });
    try {
      final db = await ref.read(appDatabaseProvider.future);
      await db.membersDao.removeFromSpace(member.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'members'),
      );
      if (!mounted) return;
      setState(() {
        _removing = false;
        _error = 'Could not remove. Please try again.';
      });
    }
  }

}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _memberProvider = StreamProvider.autoDispose.family<Member?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.membersDao.watchById(id);
  },
);

/// Vertical-aware role picker. Reads the role-key list from
/// `RoleBundles.rolesFor(vertical)` and labels each chip via
/// `RoleLabels.of`. Construction sees PM / foreman / etc.;
/// childcare sees director / lead_teacher / etc.; no hardcoded
/// role list anywhere in this widget.
///
/// Selecting a chip flips the member's role AND re-applies the
/// per-vertical default cap bundle on top of their existing caps
/// (`settings_actions.setRole`).
/// Role picker chips. **Last-director protection**: if THIS member is
/// the only person in the space with director-level privilege (by
/// role OR by `canActAsDirector` cap), the non-director chips are
/// disabled with an inline explanation. Without this gate, a single
/// director could demote themselves and orphan the space — no one
/// would be able to change anyone's role back.
///
/// (Recovery for spaces already orphaned by this bug lives in
/// migration 20260521000001_recover_orphan_director.sql.)
class _RoleSelector extends ConsumerWidget {
  const _RoleSelector({
    required this.memberId,
    required this.vertical,
    required this.selected,
    required this.onChanged,
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

    // Count members in the space who are admin-level right now —
    // either via the literal director-equivalent role OR via the
    // `canActAsDirector` cap (a non-director member who's been
    // explicitly promoted).
    final members =
        ref.watch(membersInSpaceProvider).value ?? const <Member>[];
    final admins = members.where((m) {
      if (m.role == directorRole) return true;
      return m.caps.getBool(CoreCaps.canActAsDirector);
    }).toList(growable: false);
    final iAmLastDirector = selected == directorRole &&
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
                  // Block demotion when this is the last admin: only
                  // the currently-selected (director) chip stays
                  // tappable so the user can re-confirm but can't
                  // switch away.
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
class _SpecialtySelector extends StatelessWidget {
  const _SpecialtySelector({
    required this.selected,
    required this.onChanged,
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
              onSelected: (s) {
                // Re-tapping the selected chip clears the choice; any
                // other tap sets that chip as the new specialty.
                onChanged(s ? key : null);
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
    required this.onToggle,
    required this.onSetExpiry,
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
    return dt.isBefore(_todayDate);
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
          // Active certs.
          for (final cert in activeCerts) ...[
            Builder(builder: (rowContext) {
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
            }),
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
