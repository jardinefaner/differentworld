import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How much a thing wants you. Ordering, not decoration — the list is ranked
/// by this and the top of it is the next thing to do.
enum Urgency {
  /// A child is unaccounted for. Nothing else outranks it.
  child,

  /// Something is off but nobody is missing.
  attention,

  /// Worth knowing, not worth interrupting for.
  note,
}

/// One line on the what-needs-you list.
///
/// Every field is required for a reason: a priority with no ROOM sends a
/// staffer hunting, and one with no PEOPLE is an alarm with no referent —
/// "3 unmarked" versus "Ava, Mateo, Sofia" is the difference between a
/// warning and a thing you can go and do.
class Priority {
  const Priority({
    required this.urgency,
    required this.what,
    required this.where,
    required this.who,
    required this.route,
  });

  final Urgency urgency;

  /// The claim, in one line — "3 children not marked in".
  final String what;

  /// Which room it is about.
  final String where;

  /// The names. Empty only when the thing genuinely is not about people.
  final List<String> who;

  /// Where a tap goes to deal with it.
  final String route;

  /// The second line: room, then names.
  String get detail => who.isEmpty
      ? where
      : '$where · ${who.take(4).join(', ')}'
            '${who.length > 4 ? ' +${who.length - 4}' : ''}';
}

/// What needs a staffer right now, ranked, across every room.
///
/// Capped at three by design. This is a calm-host app, not an alert panel: a
/// list that can grow without limit becomes something you scroll past, and a
/// staffer glancing for half a second can hold three things. When there is
/// nothing, the list is EMPTY and the view spends the space on the room
/// instead of on a tile saying nothing is wrong.
final needsYouListProvider = Provider<AsyncValue<List<Priority>>>((ref) {
  final groups = ref.watch(groupsProvider);
  if (groups.isLoading) return const AsyncValue.loading();
  if (groups.hasError) {
    return AsyncValue.error(groups.error!, groups.stackTrace!);
  }

  final out = <Priority>[];
  for (final g in groups.value ?? const <Group>[]) {
    final day = ref.watch(groupDayStateProvider(g));
    final state = day.value;
    if (state == null) continue;
    final subjects = ref.watch(subjectsInGroupProvider(g.id)).value;

    // A child nobody has marked either way is the one thing that outranks
    // everything else on this screen.
    if (state.unmarked > 0) {
      out.add(
        Priority(
          urgency: Urgency.child,
          what: state.unmarked == 1
              ? '1 child not marked in'
              : '${state.unmarked} children not marked in',
          where: g.name,
          // Naming them is the whole point — a count sends you hunting.
          who: _unmarkedNames(ref, g, subjects),
          route: '/groups/${g.id}/attendance',
        ),
      );
    }

    if (state.flagCount > 0) {
      final late = state.counts[AttendanceStatus.late] ?? 0;
      final absent = state.counts[AttendanceStatus.absent] ?? 0;
      out.add(
        Priority(
          urgency: Urgency.attention,
          what: [
            if (late > 0) '$late late',
            if (absent > 0) '$absent away',
          ].join(' · '),
          where: g.name,
          who: const [],
          route: '/groups/${g.id}/attendance',
        ),
      );
    }
  }

  out.sort((a, b) => a.urgency.index.compareTo(b.urgency.index));
  return AsyncValue.data(out.take(3).toList());
});

/// The children in [g] with no attendance record today.
///
/// Read from the same stream `groupDayStateProvider` counts, so the names and
/// the number can never disagree — a list that says three and names two is
/// worse than either.
List<String> _unmarkedNames(Ref ref, Group g, List<Subject>? subjects) {
  if (subjects == null) return const [];
  final records = ref
      .watch(attendanceForDayProvider((groupId: g.id, date: todayKey())))
      .value;
  if (records == null) return const [];
  final marked = {for (final r in records) r.subjectId};
  return [
    for (final s in subjects)
      if (!marked.contains(s.id)) s.firstName,
  ];
}
