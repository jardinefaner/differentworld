import 'package:differentworld/core/capabilities/role_keys.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter/material.dart';

/// Role-as-home, Role-1 (docs/VISION.md "role reshapes the screen — different
/// tools for different roles"). Each staff role reaches for a different set of
/// tools; this maps the viewer's role → an ordered "Your tools" palette,
/// surfaced on Today. It is the FIRST layer of the layered role vision
/// (staff-job → home+tools; archetype → tuning; kid-job → kid-mode).
///
/// Two filters compose: the role picks the ORDER + emphasis (below), and each
/// tool still gates on the viewer's actual CAPABILITY ([RoleTool.allowed]) —
/// so the palette never offers a tool the person can't use, and a role with an
/// unusual cap set degrades gracefully. The per-role ordering is a tuneable
/// default, not law — adjust the lists as the product learns each role.
///
/// Proposed defaults (grounded in each role's real day):
/// - **Director** — the pulse + program: Insights · Program · Team · Schedule
/// - **Lead teacher** — run the room: Present · Observations · Live Board · Schedule
/// - **Teacher** — capture the kids: Capture · Observations · Brain Breaks · Live Board
/// - **Specialist** — run a session: Runbook · Present · Live Board · Activities
/// - **Substitute** — orient fast: Runbook · Checklist · Capture · Pickup
/// - **Kitchen / other** — the basics: Checklist · Capture · Today
class RoleTool {
  const RoleTool({
    required this.label,
    required this.icon,
    required this.route,
    required this.allowed,
  });

  final String label;
  final IconData icon;
  final String route;

  /// Capability gate — the palette drops a tool the viewer can't use.
  final bool Function(Viewer) allowed;
}

// ── The tool catalog (label · icon · route · capability gate) ───────────────
const _capture = RoleTool(
  label: 'Capture',
  icon: Icons.bolt_outlined,
  route: '/captures/new',
  allowed: _always,
);
const _observe = RoleTool(
  label: 'Observations',
  icon: Icons.menu_book_outlined,
  route: '/observations',
  allowed: _canObserve,
);
const _checklist = RoleTool(
  label: 'Checklist',
  icon: Icons.checklist_outlined,
  route: '/checklist',
  allowed: _always,
);
const _present = RoleTool(
  label: 'Present',
  icon: Icons.co_present_outlined,
  route: '/present',
  allowed: _always,
);
const _liveBoard = RoleTool(
  label: 'Live Board',
  icon: Icons.draw_outlined,
  route: '/live-board',
  allowed: _always,
);
const _breaks = RoleTool(
  label: 'Brain Breaks',
  icon: Icons.bubble_chart_outlined,
  route: '/breaks',
  allowed: _always,
);
const _schedule = RoleTool(
  label: 'Schedule',
  icon: Icons.calendar_month_outlined,
  route: '/schedule',
  allowed: _always,
);
const _insights = RoleTool(
  label: 'Insights',
  icon: Icons.insights_outlined,
  route: '/insights',
  allowed: _always,
);
const _team = RoleTool(
  label: 'Team',
  icon: Icons.group_outlined,
  route: '/settings/team',
  allowed: _always,
);
const _program = RoleTool(
  label: 'Program',
  icon: Icons.tune,
  route: '/settings/program',
  allowed: _canManageSpace,
);
const _runbook = RoleTool(
  label: 'Runbook',
  icon: Icons.menu_book_outlined,
  route: '/runbook',
  allowed: _always,
);
const _pickup = RoleTool(
  label: 'Pickup',
  icon: Icons.directions_walk_outlined,
  route: '/pickup',
  allowed: _always,
);
const _activities = RoleTool(
  label: 'Activities',
  icon: Icons.local_activity_outlined,
  route: '/activities',
  allowed: _always,
);

bool _always(Viewer v) => true;
bool _canObserve(Viewer v) => v.canObserve;
bool _canManageSpace(Viewer v) => v.canManageSpace;

/// The ordered tools for a role, BEFORE the per-viewer capability filter.
/// Pure + testable; the widget applies [RoleTool.allowed] against the viewer.
List<RoleTool> toolsForRole(String roleKey) {
  switch (roleKey) {
    case RoleKey.director:
      return const [_insights, _program, _team, _schedule, _present, _capture];
    case RoleKey.leadTeacher:
      return const [
        _present,
        _observe,
        _liveBoard,
        _schedule,
        _breaks,
        _capture,
      ];
    case RoleKey.teacher:
      return const [_capture, _observe, _breaks, _liveBoard, _present];
    case RoleKey.specialist:
      return const [_runbook, _present, _liveBoard, _activities, _breaks];
    case RoleKey.substitute:
      return const [_runbook, _checklist, _capture, _pickup];
    default:
      return const [_checklist, _capture, _present, _breaks];
  }
}

/// The role's palette for THIS viewer — role order ∩ capability-allowed.
List<RoleTool> roleToolsFor(Viewer viewer) =>
    toolsForRole(viewer.roleKey).where((t) => t.allowed(viewer)).toList();

// ── Role-3: the archetype tunes the palette ─────────────────────────────────

/// Role-3 (docs/IDENTITY_SYSTEM.md §2 + docs/VISION.md "archetype tunes the
/// tools"): the self-authored archetype gently re-orders the role palette so the
/// tools that express *how you show up* lead. It **decorates, never gates** —
/// it only re-orders tools the role already has; an affinity for a tool the
/// role lacks is a silent no-op, and no archetype ever adds or removes a tool.
/// No archetype → the palette is exactly the Role-1 order (the floor).
///
/// Keyed by archetype id (the string on [Viewer.archetypeId] / the catalog's
/// `Archetype.id`) → the tool routes that resonate with that way of showing up.
/// `archetype_test.dart` asserts every catalog id has an entry and every route
/// here is a real tool route, so a rename can't silently break the tuning.
const Map<String, List<String>> archetypeToolAffinity = {
  'visionary': ['/insights', '/schedule'], // sees ahead, plans
  'doer': ['/captures/new', '/checklist'], // hands-on, gets it done
  'protector': ['/pickup', '/checklist'], // safety, accountability
  'anchor': ['/schedule', '/runbook'], // steady routine
  'connector': ['/observations', '/present'], // relational, shares
  'sage': ['/observations', '/insights'], // reflective, deep
  'seeker': ['/activities', '/breaks', '/live-board'], // explores, plays
  'beacon': ['/present', '/live-board'], // broadcasts, leads the room
};

/// Stable partition: float the [archetypeId]'s affinity tools to the front of
/// [base] in their existing relative order, leaving the rest in role order.
/// Pure + Viewer-free so it's exhaustively testable. Unknown/null archetype, or
/// no affinity, returns [base] untouched — the Role-1 floor.
List<RoleTool> tuneByAffinity(List<RoleTool> base, String? archetypeId) {
  final affinity = archetypeToolAffinity[archetypeId];
  if (affinity == null || affinity.isEmpty) return base;
  final wanted = affinity.toSet();
  final lead = <RoleTool>[];
  final rest = <RoleTool>[];
  for (final t in base) {
    (wanted.contains(t.route) ? lead : rest).add(t);
  }
  return [...lead, ...rest];
}

/// The viewer's palette, tuned by their archetype (Role-3). Role order ∩
/// capability (Role-1), then the archetype's gentle re-order on top.
List<RoleTool> tunedToolsFor(Viewer viewer) =>
    tuneByAffinity(roleToolsFor(viewer), viewer.archetypeId);

/// Whether the archetype draws [tool] forward — drives the subtle lead-tile
/// emphasis in the strip. False when no archetype is set.
bool isAffinityTool(Viewer viewer, RoleTool tool) =>
    archetypeToolAffinity[viewer.archetypeId]?.contains(tool.route) ?? false;
