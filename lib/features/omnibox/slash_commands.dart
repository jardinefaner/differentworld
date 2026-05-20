import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A power-user command invokable from the omnibox by typing
/// `/{name} {args}`. Each command knows how to:
///
///   - Recognize its name as the user types (matches a prefix of
///     [name] or any [aliases]).
///   - Render a preview line for the panel: the command's label +
///     a hint of what the args do (e.g. "/attendance {group}").
///   - Execute itself given the typed args and a route context.
///
/// Commands are a flat list resolved by [matchSlashCommands]; there's
/// no command "registry" provider yet because the set is small and
/// the args resolution (e.g. matching `robins` to a Group row) needs
/// live Drift data anyway.
class SlashCommand {
  const SlashCommand({
    required this.name,
    required this.label,
    required this.hint,
    required this.icon,
    required this.exec,
    this.aliases = const <String>[],
    this.visibleTo,
  });

  /// Canonical name. The user types `/{name} ...` to invoke.
  final String name;

  /// Display label shown in the panel — title-case version of [name].
  final String label;

  /// One-line hint shown under the label. Use `{placeholders}` to
  /// indicate args (e.g. "/log {kid}").
  final String hint;

  final IconData icon;

  /// Alternative names that ALSO match. Lets a typo-friendly few
  /// variants ("/atd" for "/attendance") land on the right command
  /// without bloating the visible list.
  final List<String> aliases;

  /// Execute the command. `args` is everything after the command name
  /// in the typed query (e.g. "robins" from "/attendance robins").
  /// `args` is null when the user just hit enter on the name alone.
  final void Function(BuildContext ctx, WidgetRef ref, String? args) exec;

  /// Optional capability gate. Called with the current Viewer; the
  /// command is hidden from the panel + rejected on exec when it
  /// returns false. Null means "available to anyone signed in."
  /// Filtering at LIST time (instead of relying on the exec to
  /// snackbar a denial) matches the omnibox catalog pattern — a
  /// command the viewer can't run shouldn't even show up.
  final bool Function(Viewer)? visibleTo;

  /// Whether `typed` matches this command's name or any alias as a
  /// prefix.
  bool matches(String typed) {
    final t = typed.toLowerCase();
    if (name.startsWith(t)) return true;
    for (final a in aliases) {
      if (a.startsWith(t)) return true;
    }
    return false;
  }
}

/// Parse the current query into (commandName, args). Strips the
/// leading `/` and splits on the first whitespace.
///
/// Returns `(null, null)` when there's no slash yet (the caller
/// shouldn't reach this then — `detectMode` only returns `slash`
/// when there is one — but defensive against an off-by-one).
({String? name, String? args}) parseSlashQuery(String query) {
  final trimmed = query.trimLeft();
  if (!trimmed.startsWith('/')) return (name: null, args: null);
  final rest = trimmed.substring(1);
  final space = rest.indexOf(RegExp(r'\s+'));
  if (space < 0) {
    return (name: rest, args: null);
  }
  final n = rest.substring(0, space);
  final a = rest.substring(space).trim();
  return (name: n, args: a.isEmpty ? null : a);
}

/// Filter [allSlashCommands] by what the user has typed so far AND
/// by the [viewer]'s capabilities. Empty `typedName` returns
/// everything the viewer can run; otherwise prefix-match name +
/// aliases.
///
/// Filtering by capability at LIST time keeps the panel honest —
/// a non-driver typing `/` doesn't see `/checkout` light up and
/// then get rejected on Enter. Same pattern as the catalog's
/// capability-gated entries.
List<SlashCommand> matchSlashCommands(String? typedName, {Viewer? viewer}) {
  final allowed = allSlashCommands.where((c) {
    final gate = c.visibleTo;
    if (gate == null || viewer == null) return true;
    return gate(viewer);
  });
  if (typedName == null || typedName.isEmpty) {
    return allowed.toList();
  }
  return allowed.where((c) => c.matches(typedName)).toList();
}

/// The canonical slash command set. Keep small and tight — power
/// users will memorize these, so churn is expensive. Adding a new
/// one should add a real capability the omnibox catalog can't
/// already do via typed search.
final List<SlashCommand> allSlashCommands = <SlashCommand>[
  SlashCommand(
    name: 'today',
    label: '/today',
    hint: "Jump to today's launchpad",
    icon: Icons.today_outlined,
    aliases: const ['home'],
    // Home lives at `/` (see router); the navigator's already there
    // most of the time. `go` rather than `push` so we don't stack
    // home on top of home.
    exec: (ctx, _, _) => ctx.go('/'),
  ),
  SlashCommand(
    name: 'captures',
    label: '/captures',
    hint: 'Open the capture inbox',
    icon: Icons.inbox_outlined,
    aliases: const ['inbox'],
    exec: (ctx, _, _) => unawaited(ctx.push('/captures')),
  ),
  SlashCommand(
    name: 'tasks',
    label: '/tasks',
    hint: 'Open the task list',
    icon: Icons.checklist_outlined,
    exec: (ctx, _, _) => unawaited(ctx.push('/tasks')),
  ),
  SlashCommand(
    name: 'insights',
    label: '/insights',
    hint: 'See what the system is asking',
    icon: Icons.lightbulb_outline,
    exec: (ctx, _, _) => unawaited(ctx.push('/insights')),
  ),
  SlashCommand(
    name: 'review',
    label: '/review',
    hint: 'Start the walk-me-through review',
    icon: Icons.play_circle_outline,
    exec: (ctx, _, _) => unawaited(ctx.push('/review')),
  ),
  const SlashCommand(
    name: 'attendance',
    label: '/attendance {group}',
    hint: 'Open attendance for a cohort by name',
    icon: Icons.how_to_reg_outlined,
    aliases: ['atd'],
    exec: _execAttendance,
  ),
  const SlashCommand(
    name: 'log',
    label: '/log {kid}',
    hint: 'Start an observation for a kid by name',
    icon: Icons.edit_note_outlined,
    aliases: ['observe', 'obs'],
    exec: _execLog,
  ),
  SlashCommand(
    name: 'schedule',
    label: '/schedule',
    hint: 'Open the week schedule',
    icon: Icons.calendar_view_week_outlined,
    exec: (ctx, _, _) => unawaited(ctx.push('/schedule')),
  ),
  const SlashCommand(
    name: 'checkout',
    label: '/checkout {vehicle}',
    hint: 'Check out a vehicle by name (or jump to the fleet list)',
    icon: Icons.key_outlined,
    aliases: ['co'],
    visibleTo: _canTouchVehicles,
    exec: _execCheckout,
  ),
  const SlashCommand(
    name: 'checkin',
    label: '/checkin {vehicle}',
    hint: 'Check in a vehicle by name (or jump to the fleet list)',
    icon: Icons.assignment_turned_in_outlined,
    aliases: ['ci', 'return'],
    visibleTo: _canTouchVehicles,
    exec: _execCheckin,
  ),
];

bool _canTouchVehicles(Viewer v) => v.canDrive || v.canManageProgram;

void _execAttendance(BuildContext ctx, WidgetRef ref, String? args) {
  if (args == null || args.isEmpty) {
    // No group specified — open the schedule landing, which lists
    // groups and lets the user pick.
    unawaited(ctx.push('/schedule'));
    return;
  }
  final groups = ref.read(groupsProvider).value ?? const <Group>[];
  final q = args.toLowerCase();
  Group? hit;
  // Best-match: prefer prefix on name, then substring.
  for (final g in groups) {
    if (g.name.toLowerCase().startsWith(q)) {
      hit = g;
      break;
    }
  }
  hit ??= groups.firstWhereOrNull(
    (g) => g.name.toLowerCase().contains(q),
  );
  if (hit == null) {
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      SnackBar(content: Text('No cohort matches "$args".')),
    );
    return;
  }
  unawaited(ctx.push('/groups/${hit.id}/attendance'));
}

void _execLog(BuildContext ctx, WidgetRef ref, String? args) {
  if (args == null || args.isEmpty) {
    // No name → open the all-observations feed, from which the user
    // can pick a kid to log against. (There's no top-level kid
    // index; subjects live under their group.)
    unawaited(ctx.push('/observations'));
    return;
  }
  final subjects =
      ref.read(subjectsInSpaceProvider).value ?? const <Subject>[];
  final q = args.toLowerCase();
  Subject? hit;
  for (final s in subjects) {
    final full = '${s.firstName} ${s.lastName}'.toLowerCase();
    if (full.startsWith(q) || s.firstName.toLowerCase().startsWith(q)) {
      hit = s;
      break;
    }
  }
  hit ??= subjects.firstWhereOrNull((s) {
    final full = '${s.firstName} ${s.lastName}'.toLowerCase();
    return full.contains(q);
  });
  if (hit == null) {
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      SnackBar(content: Text('No kid matches "$args".')),
    );
    return;
  }
  // Route through the kid's detail page (path mirrors the omnibox
  // catalog's subject-entry destination); from there the "log a
  // note" affordance is one tap.
  final gid = hit.groupId;
  if (gid == null) {
    // Unparented subject — fall back to the all-observations feed.
    unawaited(ctx.push('/observations'));
    return;
  }
  unawaited(ctx.push('/groups/$gid/students/${hit.id}'));
}

void _execCheckout(BuildContext ctx, WidgetRef ref, String? args) {
  _execVehicleAction(ctx, ref, args, kind: 'checkout');
}

void _execCheckin(BuildContext ctx, WidgetRef ref, String? args) {
  _execVehicleAction(ctx, ref, args, kind: 'checkin');
}

/// Shared resolver for `/checkout {name}` and `/checkin {name}`.
/// Empty args opens the fleet list; a typed name fuzzy-matches a
/// vehicle and routes directly to the checkout / checkin form. If
/// no match, a snackbar names what was typed so the user can fix it.
void _execVehicleAction(
  BuildContext ctx,
  WidgetRef ref,
  String? args, {
  required String kind,
}) {
  final viewer = ref.read(viewerProvider);
  // Defense in depth — the command is now hidden from the panel via
  // `visibleTo`, but a savvy user could still type it directly and
  // hit return. Reject with a copy that doesn't leak internal
  // capability-key vocabulary: a user shouldn't see "you need the
  // canDrive cap" — they should see what to DO ("ask a director").
  if (!_canTouchVehicles(viewer)) {
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Only drivers can check vehicles in or out. Ask a director.',
        ),
      ),
    );
    return;
  }
  if (args == null || args.isEmpty) {
    unawaited(ctx.push('/settings/vehicles'));
    return;
  }
  final fleet =
      ref.read(fleetStatusProvider).value ?? const <VehicleWithStatus>[];
  final q = args.toLowerCase();
  // Prefer prefix matches on name, then licence plate, then substring.
  VehicleWithStatus? hit;
  for (final v in fleet) {
    if (v.vehicle.name.toLowerCase().startsWith(q)) {
      hit = v;
      break;
    }
  }
  hit ??= fleet.firstWhereOrNull((v) {
    final plate = v.vehicle.licensePlate?.toLowerCase() ?? '';
    return plate.startsWith(q);
  });
  hit ??= fleet.firstWhereOrNull(
    (v) => v.vehicle.name.toLowerCase().contains(q),
  );
  if (hit == null) {
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      SnackBar(content: Text('No vehicle matches "$args".')),
    );
    return;
  }
  unawaited(ctx.push('/settings/vehicles/${hit.vehicle.id}/$kind'));
}

extension _ListFirstWhereOrNullX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
