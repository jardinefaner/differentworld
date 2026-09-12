import 'dart:math';

import 'package:differentworld/features/picker/picker_logic.dart';
import 'package:flutter/foundation.dart';

/// Whose turn it is — the facilitation engine's third facet
/// (docs/FACILITATION.md).
///
/// **One role, several algorithms.** FIVE things in this app already answer
/// "who is up", and they are NOT duplicates: two sides flipping on a move (a
/// grid game); a fair bag where everyone is picked before anyone repeats (the
/// name picker); everyone once with the ADULT choosing the order (photo
/// turns); pair-history-aware grouping (the rotation engine); and
/// least-turns-first across a whole term, read from the `room_events` log
/// (`rooms/fair_turns.dart`). Their correctness conditions are genuinely
/// different and merging them would destroy what each is good at.
///
/// **Who decides differs too**, which is the thing that shaped this interface:
/// some rules pick for you ([FairDraw] draws, [AlternatingSides] flips), and
/// some only track who is left while a person chooses ([EveryoneOnce]). Both
/// are real facilitation, so `advance` takes an optional `chosen` and
/// `choices` is non-empty exactly when the adult is the one deciding.
///
/// What they share is a ROLE: *something that names who is up, and advances*.
/// This is that role. An activity asks for a turn and gets the whose-go line,
/// the label and the advance rule without writing one — which is what makes a
/// fifth hand-rolled implementation unnecessary rather than merely discouraged.
///
/// Every implementation is **pure**: `advance()` returns the next state rather
/// than mutating, so a turn can ride the wire to a cast screen and survive a
/// rebuild the same way a game's board does.
///
/// **The precise immutability guarantee**, because the earlier version of this
/// comment over-promised: a state produced by `advance()` holds *unmodifiable*
/// collections and cannot be corrupted by whoever built the previous one. A
/// state you construct DIRECTLY holds the collections you passed — a literal
/// at the call site is fine, a list you keep and mutate is not.
@immutable
class TurnHolder {
  const TurnHolder({required this.label, this.subjectId, this.side});

  /// What the room reads — "Team 1", "Amara".
  final String label;

  /// Set when the holder is a PERSON, so a surface can link to them.
  final String? subjectId;

  /// Set when the holder is a SIDE rather than a person (0 or 1).
  final int? side;

  @override
  bool operator ==(Object other) =>
      other is TurnHolder &&
      other.label == label &&
      other.subjectId == subjectId &&
      other.side == side;

  @override
  int get hashCode => Object.hash(label, subjectId, side);

  @override
  String toString() => 'TurnHolder($label)';
}

/// Something that knows who is up.
@immutable
abstract class TurnSource {
  const TurnSource();

  /// Who is up, or null when nobody is — the room acts as one, play is over,
  /// or the rule leaves the choice to a person and they have not made it.
  TurnHolder? get current;

  /// Who COULD go next. Empty when the RULE decides; non-empty exactly when a
  /// person does, which is how a surface knows whether to render a picker.
  List<TurnHolder> get choices => const [];

  /// The next state. Pure — never mutates, always returns. `chosen` is the id
  /// a person picked; rules that decide for themselves ignore it.
  TurnSource advance({String? chosen});

  /// The line to show under the board. Null when there is no turn to announce;
  /// a surface showing "null to play" is worse than showing nothing.
  String? get line => current == null ? null : '${current!.label} to play';
}

/// The room acts as one. The honest default — most activities are not
/// turn-based, and pretending otherwise puts a meaningless line on a screen.
@immutable
class NoTurn extends TurnSource {
  const NoTurn();

  @override
  TurnHolder? get current => null;

  @override
  TurnSource advance({String? chosen}) => this;

  @override
  String? get line => null;
}

/// Two (or more) sides, flipping on each accepted move. Wraps what
/// `GridGame.alternates` + `GridBoard.turn` already do, so a game keeps its
/// existing API while the ENGINE gains a shape it can read.
@immutable
class AlternatingSides extends TurnSource {
  const AlternatingSides({required this.sides, this.at = 0});

  /// Side names, in order. Two is the common case; more is allowed.
  final List<String> sides;

  /// Whose go it is, as an index into [sides].
  final int at;

  @override
  TurnHolder? get current => sides.isEmpty
      ? null
      : TurnHolder(label: sides[at % sides.length], side: at % sides.length);

  @override
  TurnSource advance({String? chosen}) => sides.isEmpty
      ? this
      // Unmodifiable, not the caller's list: a DERIVED state is the one that
      // rides the wire and outlives the call, so it must not share a
      // collection someone else can still mutate.
      : AlternatingSides(
          sides: List.unmodifiable(sides),
          at: (at + 1) % sides.length,
        );
}

/// Each person once, in the order given — the photo-turns shape. Ends rather
/// than wrapping: when everyone has had a go, [current] is null and the
/// activity is over, which is the thing that makes "whose turn" and "are we
/// done" the same question.
@immutable
class RosterOrder extends TurnSource {
  const RosterOrder({required this.ids, required this.names, this.at = 0});

  final List<String> ids;

  /// Display name per id. A missing name falls back to the id rather than
  /// throwing — a roster that is mid-sync must not break the turn.
  final Map<String, String> names;

  final int at;

  /// Whether everyone has had a go.
  bool get isDone => at >= ids.length;

  @override
  TurnHolder? get current {
    if (isDone) return null;
    final id = ids[at];
    return TurnHolder(label: names[id] ?? id, subjectId: id);
  }

  @override
  TurnSource advance({String? chosen}) => RosterOrder(
    ids: List.unmodifiable(ids),
    names: Map.unmodifiable(names),
    at: at + 1,
  );

  @override
  String? get line {
    final c = current;
    return c == null ? null : "${c.label}'s turn";
  }
}

/// **Everyone gets picked before anyone repeats.** Wraps [FairBag] — the
/// picker's existing, tested, persisted fair-draw core — rather than
/// reimplementing it. That wrapping is the point: the engine's job is
/// assembly, and a second fair-draw would be a second thing to get wrong.
@immutable
class FairDraw extends TurnSource {
  const FairDraw({
    required this.bag,
    required this.eligible,
    required this.names,
    required this.rng,
    this.drawn,
  });

  /// A fresh bag over [eligible], nobody drawn yet.
  factory FairDraw.fresh({
    required List<String> eligible,
    required Map<String, String> names,
    required Random rng,
  }) => FairDraw(
    bag: FairBag.fresh(eligible, rng),
    eligible: eligible,
    names: names,
    rng: rng,
  );

  final FairBag bag;
  final List<String> eligible;
  final Map<String, String> names;

  /// Carried, not re-created per call. `FairBag.draw` only reaches the rng
  /// when the bag REFILLS — so a `Random()` made fresh inside `advance` was
  /// harmless for correctness and made the one interesting case (the draw
  /// order of a new round) impossible to pin in a test.
  final Random rng;

  /// Who the last [advance] drew. Null before the first draw — the engine
  /// announces nobody rather than guessing.
  final String? drawn;

  @override
  TurnHolder? get current => drawn == null
      ? null
      : TurnHolder(label: names[drawn!] ?? drawn!, subjectId: drawn);

  @override
  TurnSource advance({String? chosen}) {
    if (eligible.isEmpty) return this;
    // FairBag owns the fairness; this only threads the state forward.
    final r = bag.draw(1, eligible, rng);
    return FairDraw(
      bag: r.bag,
      eligible: List.unmodifiable(eligible),
      names: Map.unmodifiable(names),
      rng: rng,
      drawn: r.drawn.isEmpty ? null : r.drawn.first,
    );
  }

  @override
  String? get line {
    final c = current;
    return c == null ? null : "${c.label}'s turn";
  }
}

/// **Everyone once — and the ADULT picks the order.** The photo-turns rule:
/// a roster, a set of who has already had a go, and a counselor who chooses
/// whoever is ready rather than whoever is next alphabetically.
///
/// Distinct from [RosterOrder], which imposes an order, and from [FairDraw],
/// which picks for you. Taking that choice away would be the "rewrite a
/// working feature to fit a diagram" move docs/FACILITATION.md forbids — the
/// counselor picking the child who is actually ready IS the feature.
///
/// [done] is supplied by the caller each build rather than accumulated here,
/// because the real set is a MERGE: who has gone in this session, plus who
/// already shot according to the data layer (so a process-kill mid-session
/// does not show everyone still to go).
@immutable
class EveryoneOnce extends TurnSource {
  const EveryoneOnce({
    required this.ids,
    required this.names,
    this.done = const {},
  });

  final List<String> ids;
  final Map<String, String> names;
  final Set<String> done;

  List<String> get remainingIds => [
    for (final id in ids)
      if (!done.contains(id)) id,
  ];

  int get remaining => remainingIds.length;

  bool get isDone => ids.isNotEmpty && remainingIds.isEmpty;

  /// Whether [id] has already had their go.
  bool hasGone(String id) => done.contains(id);

  /// Nobody is automatically up — that is the whole point of this rule.
  @override
  TurnHolder? get current => null;

  @override
  List<TurnHolder> get choices => [
    for (final id in remainingIds)
      TurnHolder(label: names[id] ?? id, subjectId: id),
  ];

  @override
  TurnSource advance({String? chosen}) => chosen == null
      ? this
      : EveryoneOnce(
          ids: List.unmodifiable(ids),
          names: Map.unmodifiable(names),
          done: Set.unmodifiable({...done, chosen}),
        );

  /// What the room needs to know here is not a name but a COUNT.
  @override
  String? get line => isDone ? null : '$remaining still to go';
}
