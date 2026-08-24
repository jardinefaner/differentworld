/// Year rollover — planning, and the receipt (docs/ROLLOVER.md).
///
/// The rule the whole feature exists to hold: **a new intake never costs an
/// old child anything.** Before this, clearing last year's roster meant
/// pressing a delete that cascaded through seven tables and took a child's
/// observations, photo tags, family messages, survey answers, character
/// sheet and book with it — behind a dialog that said their history would
/// be kept.
///
/// So the plan is additive by construction: every child either carries
/// forward into a room, or becomes an alumnus. There is no third option and
/// no code path here that removes anything.
library;

/// What happens to one child when the year turns.
enum Fate {
  /// Continues into the new period, in [RolloverChoice.groupId].
  carriesForward,

  /// Leaves the active roster and keeps every record they ever had. They
  /// stop appearing in attendance, pickers and today's rosters — that is
  /// the ONLY thing that changes for them.
  becomesAlumni,
}

class RolloverChoice {
  const RolloverChoice({required this.fate, this.groupId});

  final Fate fate;

  /// The room they join. Null with [Fate.carriesForward] means "enrolled but
  /// not placed yet" — a real state on the first day, when the rooms are set
  /// but the children haven't been sorted into them.
  final String? groupId;

  bool get carries => fate == Fate.carriesForward;
}

/// A child as the rollover screen needs to see them.
class RolloverCandidate {
  const RolloverCandidate({
    required this.subjectId,
    required this.name,
    this.currentGroupId,
  });

  final String subjectId;
  final String name;
  final String? currentGroupId;
}

/// The receipt. Shown before you commit and after — because "did I just lose
/// a year of work?" deserves a number, not a reassurance.
class RolloverSummary {
  const RolloverSummary({
    required this.carriedForward,
    required this.becameAlumni,
    required this.movedRoom,
  });

  final int carriedForward;
  final int becameAlumni;

  /// Of those carried forward, how many changed room.
  final int movedRoom;

  /// Always zero, and stated rather than assumed. If this ever needs to be
  /// anything else, the feature has been broken.
  int get recordsDeleted => 0;

  int get total => carriedForward + becameAlumni;
}

/// The default plan: **everyone carries forward, in the room they're already
/// in.** Deliberately the safest possible starting point — a director who
/// taps straight through changes nothing but the period, and has to opt each
/// child OUT rather than remember to opt them in.
Map<String, RolloverChoice> defaultPlan(List<RolloverCandidate> roster) => {
  for (final c in roster)
    c.subjectId: RolloverChoice(
      fate: Fate.carriesForward,
      groupId: c.currentGroupId,
    ),
};

/// Summarise a plan without applying it.
RolloverSummary summarise(
  List<RolloverCandidate> roster,
  Map<String, RolloverChoice> plan,
) {
  var carried = 0;
  var alumni = 0;
  var moved = 0;
  for (final c in roster) {
    final choice = plan[c.subjectId];
    // An unlisted child is treated as carrying forward unchanged — the safe
    // reading, matching defaultPlan. Silence must never mean removal.
    if (choice == null || choice.carries) {
      carried++;
      final to = choice?.groupId ?? c.currentGroupId;
      if (to != c.currentGroupId) moved++;
    } else {
      alumni++;
    }
  }
  return RolloverSummary(
    carriedForward: carried,
    becameAlumni: alumni,
    movedRoom: moved,
  );
}

/// The map `EnrollmentsDao.applyRollover` consumes: subject id → new room,
/// containing ONLY the children who carry forward. Absence from this map is
/// what makes a child an alumnus, so it is built here rather than inferred
/// at the call site.
Map<String, String?> returningRooms(
  List<RolloverCandidate> roster,
  Map<String, RolloverChoice> plan,
) {
  final out = <String, String?>{};
  for (final c in roster) {
    final choice = plan[c.subjectId];
    if (choice == null) {
      out[c.subjectId] = c.currentGroupId;
    } else if (choice.carries) {
      out[c.subjectId] = choice.groupId ?? c.currentGroupId;
    }
  }
  return out;
}

/// Suggest a name for the next period from [previous], so the common case is
/// one tap: '2025–26' → '2026–27', 'Summer 2025' → 'Summer 2026'. Falls back
/// to the calendar year when it can't parse one.
String suggestTermName(String? previous, DateTime now) {
  final startYear = now.month >= 7 ? now.year : now.year - 1;
  final tailYear = ((startYear + 1) % 100).toString().padLeft(2, '0');
  final fallback = '$startYear–$tailYear';
  if (previous == null || previous.trim().isEmpty) return fallback;
  final years = RegExp(r'(\d{4})').allMatches(previous).toList();
  if (years.isEmpty) return fallback;
  final first = int.parse(years.first.group(1)!);
  var next = previous.replaceFirst('$first', '${first + 1}');
  if (years.length > 1) {
    final second = int.parse(years[1].group(1)!);
    next = next.replaceFirst('$second', '${second + 1}');
  } else {
    // '2025–26' style: bump the two-digit tail too.
    final tail = RegExp(r'[–-](\d{2})\b').firstMatch(previous);
    if (tail != null) {
      final t = int.parse(tail.group(1)!);
      next = next.replaceFirst(
        '${tail.group(0)}',
        '${tail.group(0)![0]}${(t + 1).toString().padLeft(2, '0')}',
      );
    }
  }
  return next;
}
