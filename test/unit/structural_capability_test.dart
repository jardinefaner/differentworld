// Who may declare the building's structural facts.
//
// `canManageSpace` was never a capability — it is `=> isDirector`, with no
// key behind it, so there was no middle setting a director could grant. The
// only way to let a Group Leader add a location was `can_act_as_director`,
// which also hands over billing and the audit log. These pin the new tier
// and, more importantly, pin that NOBODY LOSES ANYTHING by it existing.

import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const now = '2026-08-26T08:00:00Z';

  Viewer staff({String role = 'teacher', String caps = '{}'}) => Viewer(
    member: Member(
      id: 'm1',
      displayName: 'Jordan',
      role: role,
      capabilities: caps,
      createdAt: now,
      updatedAt: now,
      spaceId: 'sp1',
    ),
    space: null,
  );

  group('canManageStructure', () {
    test('a director has it without the key — nobody loses access', () {
      // The migration-free promise: existing members carry no such key, so
      // the getter must fall through to isDirector or every director is
      // locked out of their own program on upgrade.
      expect(staff(role: 'director').canManageStructure, isTrue);
    });

    test('a counselor does not have it by default', () {
      expect(staff().canManageStructure, isFalse);
    });

    test('and CAN be granted it, which is the whole point', () {
      final granted = staff(caps: '{"can_manage_structure":true}');
      expect(granted.canManageStructure, isTrue);
      // Without handing over the business.
      expect(granted.canViewBilling, isFalse);
      expect(granted.canInviteStaff, isFalse);
    });

    test('granting it does NOT make someone a director', () {
      final granted = staff(caps: '{"can_manage_structure":true}');
      expect(granted.isDirector, isFalse);
      expect(granted.canManageSpace, isFalse);
    });

    test('a guardian never has it', () {
      expect(const Viewer.empty().canManageStructure, isFalse);
    });
  });

  group('the seeded bundles', () {
    Map<String, dynamic> bundle(String role) => RoleBundles.defaultsFor(role);

    test('Program Manager and Group Leader declare structure', () {
      // The lead is the person who discovers the back field is usable this
      // term, and they already author the schedule — a block cannot point
      // at a place that does not exist.
      expect(bundle('director')[CoreCaps.canManageStructure], isTrue);
      expect(bundle('lead_teacher')[CoreCaps.canManageStructure], isTrue);
      for (final r in ['teacher', 'substitute', 'specialist']) {
        expect(
          bundle(r)[CoreCaps.canManageStructure],
          isNot(true),
          reason: '$r must not get structure by default',
        );
      }
    });

    test('structure is NOT the same as running the business', () {
      // The whole reason the key exists: a lead can add a room without
      // seeing billing or inviting staff.
      final lead = bundle('lead_teacher');
      expect(lead[CoreCaps.canViewBilling], isNot(true));
      expect(lead[CoreCaps.canInviteStaff], isNot(true));
      expect(lead[CoreCaps.canActAsDirector], isNot(true));
    });

    test('Counselors keep schedule authoring — this was already shipped', () {
      // Guard against a "leads only" model quietly regressing the bundle
      // that is already live on real devices.
      expect(bundle('teacher')[CoreCaps.canManageSchedule], isTrue);
    });

    test('a Specialist authors their own block', () {
      // Changed 2026-08-26 on the user's call. Leaving this false made the
      // program manager a scheduling clerk for the staff who knew the
      // activity best.
      expect(bundle('specialist')[CoreCaps.canManageSchedule], isTrue);
    });

    test('a Specialist can release a child they have been with', () {
      // The journey decided this: a specialist running the last block IS
      // the adult in the room when the parent arrives.
      expect(bundle('specialist')[ChildcareCaps.canAuthorizePickup], isTrue);
    });

    test('but a Specialist still does not declare structure', () {
      // Running your own block is not the same as deciding what rooms and
      // places the program has.
      expect(bundle('specialist')[CoreCaps.canManageStructure], isNot(true));
    });
  });
}
