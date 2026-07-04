// Pins the role-as-home tool mapping (docs/VISION.md, role-1): each staff
// role gets a distinct, ordered "Your tools" palette, and the lists point at
// real routes. The capability filter (roleToolsFor) is applied in the widget
// against a live Viewer; here we pin the pure per-role ORDER.

import 'package:differentworld/core/capabilities/role_keys.dart';
import 'package:differentworld/features/today/role_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each staff role gets a non-empty, distinct lead tool', () {
    final director = toolsForRole(RoleKey.director);
    final lead = toolsForRole(RoleKey.leadTeacher);
    final teacher = toolsForRole(RoleKey.teacher);
    final specialist = toolsForRole(RoleKey.specialist);
    final sub = toolsForRole(RoleKey.substitute);

    for (final list in [director, lead, teacher, specialist, sub]) {
      expect(list, isNotEmpty);
    }
    // The lead tool reflects the role's real day — they differ.
    expect(director.first.label, 'Insights');
    expect(lead.first.label, 'Present');
    expect(teacher.first.label, 'Capture');
    expect(specialist.first.label, 'Runbook');
    expect(sub.first.label, 'Runbook');
  });

  test('director palette carries the director-only tools', () {
    final labels = toolsForRole(RoleKey.director).map((t) => t.label);
    expect(labels, containsAll(<String>['Program', 'Team', 'Insights']));
  });

  test('an unknown role falls back to the basics', () {
    final labels = toolsForRole('made_up_role').map((t) => t.label).toList();
    expect(labels, contains('Capture'));
    expect(labels, contains('Checklist'));
  });

  test('every tool points at an absolute route', () {
    for (final role in [
      RoleKey.director,
      RoleKey.leadTeacher,
      RoleKey.teacher,
      RoleKey.specialist,
      RoleKey.substitute,
      'fallback',
    ]) {
      for (final tool in toolsForRole(role)) {
        expect(
          tool.route.startsWith('/'),
          isTrue,
          reason: '${tool.label} route must be absolute',
        );
      }
    }
  });
}
