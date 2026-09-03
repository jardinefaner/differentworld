// Role preview is a LENS, never a promotion. A director looking through a
// counselor's eyes must LOSE capabilities, and nobody below director may
// set the lens at all — otherwise "see what they see" becomes a way to
// grant yourself things.

import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/core/viewer/viewer_override.dart';
import 'package:differentworld/features/roles/preview_banner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const now = '2026-08-27T08:00:00Z';

  Viewer person(String role) => Viewer(
    member: Member(
      id: 'm1',
      displayName: 'Dee',
      role: role,
      capabilities: '{}',
      createdAt: now,
      updatedAt: now,
      spaceId: 'sp1',
    ),
    space: null,
  );

  group('who may look', () {
    test('a director may', () {
      expect(canPreviewRoles(person('director')), isTrue);
    });

    test('nobody else may — preview is not a way to grant yourself access', () {
      for (final r in ['lead_teacher', 'teacher', 'specialist', 'substitute']) {
        expect(canPreviewRoles(person(r)), isFalse, reason: r);
      }
    });
  });

  group('the lens only ever narrows', () {
    test('previewing as a counselor LOSES the director capabilities', () {
      final swapped = buildOverrideViewer(person('director'), 'teacher');
      expect(swapped, isNotNull);
      expect(swapped!.canViewBilling, isFalse);
      expect(swapped.canInviteStaff, isFalse);
      expect(swapped.canManageStructure, isFalse);
      // And keeps what a counselor really has.
      expect(swapped.canTakeAttendance, isTrue);
      expect(swapped.canManageSchedule, isTrue);
    });

    test('previewing as a substitute is narrower still', () {
      final swapped = buildOverrideViewer(person('director'), 'substitute');
      expect(swapped!.canManageSchedule, isFalse);
      expect(swapped.canAuthorizePickup, isFalse);
      expect(swapped.canTakeAttendance, isTrue);
    });
  });

  group('what the lens does NOT change', () {
    test('the member id flows through — so YOUR data stays yours', () {
      // The honest limit. Room assignments, certifications and authored
      // observations are all keyed on member.id, which is unchanged, so
      // preview simulates PERMISSIONS and not MEMBERSHIP.
      final swapped = buildOverrideViewer(person('director'), 'teacher');
      expect(swapped!.memberId, 'm1');
      expect(swapped.displayName, 'Dee');
    });

    test('seesAllClassrooms goes FALSE, which is the visible consequence', () {
      // groupsProvider falls back to `group_members` for this member when
      // seesAllClassrooms is false — and a director is usually staffed to
      // no room, so previewing often shows an EMPTY room list. Pinned so
      // nobody later "fixes" it by faking an assignment, which would mean
      // drawing conclusions from a room nobody is really in.
      expect(person('director').seesAllClassrooms, isTrue);
      final swapped = buildOverrideViewer(person('director'), 'teacher');
      expect(swapped!.seesAllClassrooms, isFalse);
    });
  });

  group('the previewable list', () {
    test('offers the roles a real person on this team could be', () {
      expect(
        RoleBundlesPreview.previewable,
        containsAll(['lead_teacher', 'teacher', 'specialist', 'substitute']),
      );
    });

    test('does not offer director — that is a no-op for the only user', () {
      expect(RoleBundlesPreview.previewable, isNot(contains('director')));
    });

    test('every previewable role has a human label', () {
      // A picker row reading "lead_teacher" would be the raw key leaking
      // into the UI.
      for (final r in RoleBundlesPreview.previewable) {
        final label = RoleLabels.of(r);
        expect(label, isNotEmpty);
        expect(label, isNot(contains('_')));
      }
    });
  });
}
