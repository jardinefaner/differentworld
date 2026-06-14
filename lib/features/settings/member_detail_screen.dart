import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/certifications.dart';
import 'package:differentworld/core/capabilities/role_keys.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/certifications/certifications_providers.dart';
import 'package:differentworld/features/identity/widgets/archetype_card.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/photo_source_sheet.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:differentworld/features/settings/widgets/member_detail_sections.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/cap_switch.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/route_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      await ref.read(memberCapActionsProvider).setRole(widget.memberId, role);
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
      await ref
          .read(certActionsProvider)
          .setExpiry(
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

    // Wave 113: dynamic tab title — the teammate's name. Falls
    // back to "Team member" while loading or for an unknown id.
    final memberName = memberAsync.value?.displayName.trim().isNotEmpty == true
        ? memberAsync.value!.displayName
        : 'Team member';

    // No save action — toggles auto-save (UX_DECISIONS §1).
    return RouteTitle(
      title: memberName,
      child: EdgeScaffold(
      backFallbackRoute: '/settings/team',
      body: memberAsync.when(
        loading: () => const LoadingSlot(),
        error: (e, _) => const ErrorState(title: 'Could not load member'),
        data: (member) {
          if (member == null) {
            return const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'Member not found',
            );
          }
          final currentRole = member.role;
          final caps = member.caps;
          // Wave 102 (Red Team #5): the role-selector chip guards
          // against the last director changing their own role, but
          // the `canActAsDirector` CapSwitch had no equivalent
          // protection. A member acting AS director (role: teacher,
          // cap: canActAsDirector = true) who was the only admin
          // could toggle off the cap on their own profile and brick
          // the space — no recovery without DB access. Mirror the
          // role-selector's "admin count" check here.
          final directorRole = RoleBundles.directorRoleFor(vertical);
          final allMembers = ref.watch(membersInSpaceProvider).value ??
              const <Member>[];
          final admins = allMembers.where((m) {
            if (m.role == directorRole) return true;
            return m.caps.getBool(CoreCaps.canActAsDirector);
          }).toList(growable: false);
          final isCurrentAdmin = currentRole == directorRole ||
              caps.getBool(CoreCaps.canActAsDirector);
          final iAmLastAdmin = isCurrentAdmin &&
              admins.length == 1 &&
              admins.first.id == widget.memberId;
          // Certs are now their own table; the cap-gating UI reads
          // from that stream so an expired MAT immediately disables
          // "Administer medication" without manual refresh.
          final certsAsync = ref.watch(certsForMemberProvider(widget.memberId));
          final activeCerts = certsAsync.value ?? const <MemberCertification>[];
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // "How you show up" — the self-authored archetype (decorates,
                // never gates). Editable only on your OWN profile.
                ArchetypeCard(
                  memberId: member.id,
                  archetypeId: caps.getString(MemberCaps.archetype),
                  editable: me?.id == member.id,
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
                          const MemberSectionLabel(label: 'Role'),
                          if (canManage)
                            MemberRoleSelector(
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
                            const MemberSectionLabel(label: 'Specialty'),
                            if (canManage)
                              MemberSpecialtySelector(
                                selected: member.caps.getString(
                                  ChildcareCaps.specialty,
                                ),
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
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          const MemberSectionLabel(label: 'Certifications'),
                          MemberCertificationsSection(
                            active: activeCerts,
                            onToggle: canManage ? _toggleCert : null,
                            onSetExpiry: canManage ? _setCertExpiry : null,
                          ),
                          const SizedBox(height: 24),
                          const MemberSectionLabel(label: 'Core abilities'),
                          CapSwitch(
                            label: 'Observe',
                            subtitle: 'Record developmental observations',
                            enabled: canManage,
                            value: caps.getBool(CoreCaps.canObserve),
                            onChanged: (v) => _setCap(CoreCaps.canObserve, v),
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
                                : (activeCerts.holds(Certifications.driver.key)
                                      ? 'Driver certification has expired'
                                      : 'Add the Driver certification below to enable'),
                            enabled: canManage && hasDriverCert,
                            value: caps.getBool(CoreCaps.canDrive),
                            onChanged: (v) => _setCap(CoreCaps.canDrive, v),
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
                            // Wave 102: if this is the only admin in
                            // the space, surface why it's locked.
                            subtitle: iAmLastAdmin
                                ? "Can't turn off — you're the only "
                                    'admin in this program. Promote '
                                    'a teammate first.'
                                : 'Full admin when the director is offsite',
                            enabled: canManage && !iAmLastAdmin,
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
                            const MemberSectionLabel(label: 'Childcare verbs'),
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
                                  : (activeCerts.holds(Certifications.mat.key)
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
                              subtitle: 'Add or remove guardians for a child',
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          if (member.role != RoleKey.director) ...[
                            MemberSectionLabel(
                              label:
                                  'Assigned ${labels.groupPlural.toLowerCase()}',
                            ),
                            MemberAssignmentsList(
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
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          if (canManage && me?.id != member.id) ...[
                            const SizedBox(height: 32),
                            const Divider(),
                            const MemberSectionLabel(label: 'Danger zone'),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: DestructiveButton(
                                label: 'Remove from team',
                                icon: Icons.person_remove_alt_1_outlined,
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
