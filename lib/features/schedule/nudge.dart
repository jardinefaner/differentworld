import 'package:flutter/foundation.dart';

/// "Nudge the run" — the middle-UI move where the host says what's happening in
/// plain language and the app RECOMPOSES the rest of the day, showing the change
/// as a diff to confirm (docs/VISION.md "you nudge it… shown as a structured
/// change to confirm, never a chat reply"). Rules-based + pure: no LLM, no
/// network — deterministic recomposition of the REMAINING blocks.

enum NudgeIntent {
  /// Running behind — tighten the remaining blocks to still finish on time.
  behind,

  /// Kids are wired — bring the next calm block forward for a reset.
  wired,

  /// Ahead of schedule — stretch the next block into the extra time.
  ahead,
}

/// The minimal shape the recomposer needs from a remaining block.
typedef NudgeSlot = ({
  String id,
  String title,
  String emoji,
  int minutes,
  double energy, // 0..1
  bool fixed, // pickup / closed — never shrink these
});

/// One block's change under a nudge.
@immutable
class NudgeChange {
  const NudgeChange({
    required this.slot,
    required this.oldMinutes,
    required this.newMinutes,
    required this.wasIndex,
    required this.nowIndex,
  });

  final NudgeSlot slot;
  final int oldMinutes;
  final int newMinutes;
  final int wasIndex;
  final int nowIndex;

  bool get shrank => newMinutes < oldMinutes;
  bool get grew => newMinutes > oldMinutes;
  bool get moved => nowIndex != wasIndex;
  bool get changed => shrank || grew || moved;
}

/// The result of a nudge — the new order + new durations, the per-block diff,
/// and a one-line summary. [isNoop] when nothing actually changed (so the caller
/// can say "you're on track" instead of showing an empty diff).
@immutable
class NudgePlan {
  const NudgePlan({
    required this.ordered,
    required this.changes,
    required this.summary,
  });

  /// Remaining blocks in their NEW order, with their NEW minutes.
  final List<NudgeSlot> ordered;

  /// One entry per input slot (original order), for the before→after diff.
  final List<NudgeChange> changes;

  /// The plain-language explanation of what changed.
  final String summary;

  bool get isNoop => changes.every((c) => !c.changed);
}

/// Recompose the [remaining] blocks (in run order) for a nudge. [availableMin]
/// is the minutes from NOW to the day's end (the last block's end); [endLabel]
/// is that clock time for the summary ("finish by 6:00"). Pure.
NudgePlan recomposeNudge(
  List<NudgeSlot> remaining,
  int availableMin,
  NudgeIntent intent, {
  String endLabel = 'the end',
}) {
  if (remaining.isEmpty) {
    return const NudgePlan(
      ordered: [],
      changes: [],
      summary: 'Nothing left to nudge.',
    );
  }
  return switch (intent) {
    NudgeIntent.behind => _behind(remaining, availableMin, endLabel),
    NudgeIntent.ahead => _ahead(remaining, availableMin),
    NudgeIntent.wired => _wired(remaining),
  };
}

int _sum(Iterable<NudgeSlot> s) => s.fold(0, (a, b) => a + b.minutes);

NudgePlan _noop(List<NudgeSlot> remaining, String summary) => NudgePlan(
  ordered: remaining,
  changes: [
    for (var i = 0; i < remaining.length; i++)
      NudgeChange(
        slot: remaining[i],
        oldMinutes: remaining[i].minutes,
        newMinutes: remaining[i].minutes,
        wasIndex: i,
        nowIndex: i,
      ),
  ],
  summary: summary,
);

/// Compress the flexible remaining blocks to fit [availableMin]; fixed blocks
/// (pickup / closed) keep their minutes. No-op when already inside the window.
NudgePlan _behind(
  List<NudgeSlot> remaining,
  int availableMin,
  String endLabel,
) {
  final total = _sum(remaining);
  if (total <= availableMin) {
    return _noop(remaining, "You're inside the window — nothing to tighten.");
  }
  final fixedMin = _sum(remaining.where((s) => s.fixed));
  final flexMin = total - fixedMin;
  // Target for the flexible blocks so the whole day fits.
  final flexTarget = (availableMin - fixedMin).clamp(0, flexMin);
  final scale = flexMin == 0 ? 1.0 : flexTarget / flexMin;

  final out = <NudgeSlot>[];
  final changes = <NudgeChange>[];
  for (var i = 0; i < remaining.length; i++) {
    final s = remaining[i];
    final int newMin;
    if (s.fixed) {
      newMin = s.minutes;
    } else {
      // The low bound never exceeds the high bound — a sub-5-minute block would
      // throw RangeError on clamp(5, 3), so floor at its own duration instead.
      final lo = s.minutes < 5 ? s.minutes : 5;
      newMin = (s.minutes * scale).round().clamp(lo, s.minutes);
    }
    out.add((
      id: s.id,
      title: s.title,
      emoji: s.emoji,
      minutes: newMin,
      energy: s.energy,
      fixed: s.fixed,
    ));
    changes.add(
      NudgeChange(
        slot: s,
        oldMinutes: s.minutes,
        newMinutes: newMin,
        wasIndex: i,
        nowIndex: i,
      ),
    );
  }
  final saved = total - _sum(out);
  return NudgePlan(
    ordered: out,
    changes: changes,
    summary: saved > 0
        ? 'Tightened the rest by $saved min so you still finish by $endLabel.'
        : 'Trimmed to finish by $endLabel.',
  );
}

/// Give the surplus time to the first non-fixed block — stretch the next thing.
NudgePlan _ahead(List<NudgeSlot> remaining, int availableMin) {
  final total = _sum(remaining);
  final surplus = availableMin - total;
  if (surplus <= 0) {
    return _noop(remaining, "You're on schedule — no extra time to spend yet.");
  }
  final firstFlex = remaining.indexWhere((s) => !s.fixed);
  if (firstFlex < 0) {
    return _noop(
      remaining,
      'The rest is fixed — nowhere to add the extra time.',
    );
  }
  final out = <NudgeSlot>[];
  final changes = <NudgeChange>[];
  for (var i = 0; i < remaining.length; i++) {
    final s = remaining[i];
    final newMin = i == firstFlex ? s.minutes + surplus : s.minutes;
    out.add((
      id: s.id,
      title: s.title,
      emoji: s.emoji,
      minutes: newMin,
      energy: s.energy,
      fixed: s.fixed,
    ));
    changes.add(
      NudgeChange(
        slot: s,
        oldMinutes: s.minutes,
        newMinutes: newMin,
        wasIndex: i,
        nowIndex: i,
      ),
    );
  }
  return NudgePlan(
    ordered: out,
    changes: changes,
    summary:
        'Stretched ${remaining[firstFlex].title} by $surplus min — you have the time.',
  );
}

/// Bring the next CALM block (energy ≤ 0.35) forward to be next — a reset.
NudgePlan _wired(List<NudgeSlot> remaining) {
  // Already calm next → nothing to do.
  if (remaining.first.energy <= 0.35 && !remaining.first.fixed) {
    return _noop(remaining, "The next block's already a calm one.");
  }
  // Otherwise look past the next block for a calm one to bring forward.
  final calmIndex = remaining.indexWhere(
    (s) => s.energy <= 0.35 && !s.fixed,
    1,
  );
  if (calmIndex < 0) {
    return _noop(
      remaining,
      'No calm block left to bring forward — add a breather?',
    );
  }
  final reordered = List<NudgeSlot>.of(remaining);
  final calm = reordered.removeAt(calmIndex);
  reordered.insert(0, calm);

  // Build the diff against the original order (durations unchanged).
  final newIndexOf = {
    for (var i = 0; i < reordered.length; i++) reordered[i].id: i,
  };
  final changes = [
    for (var i = 0; i < remaining.length; i++)
      NudgeChange(
        slot: remaining[i],
        oldMinutes: remaining[i].minutes,
        newMinutes: remaining[i].minutes,
        wasIndex: i,
        nowIndex: newIndexOf[remaining[i].id]!,
      ),
  ];
  return NudgePlan(
    ordered: reordered,
    changes: changes,
    summary: 'Brought ${calm.title} forward — a calm reset, right now.',
  );
}
