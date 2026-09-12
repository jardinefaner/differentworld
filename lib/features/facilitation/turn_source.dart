import 'dart:math';

import 'package:differentworld/features/picker/picker_logic.dart';
import 'package:flutter/foundation.dart';

/// Whose turn it is — the facilitation engine's third facet
/// (docs/FACILITATION.md).
///
/// **One role, several algorithms.** Four things in this app already answer
/// "who is up", and they are NOT duplicates: two sides flipping on a move
/// (a grid game), a fair bag where everyone is picked before anyone repeats
/// (the name picker), each child once in order (photo turns), and
/// pair-history-aware grouping (the rotation engine). Their correctness
/// conditions are genuinely different and merging them would destroy what
/// each is good at.
///
/// What they share is a ROLE: *something that names who is up, and advances*.
/// This is that role. An activity asks for a turn and gets the whose-go line,
/// the label and the advance rule without writing one — which is what makes a
/// fifth hand-rolled implementation unnecessary rather than merely discouraged.
///
/// Every implementation is **immutable and pure**: `advance()` returns the next
/// state rather than mutating, so a turn can ride the wire to a cast screen and
/// survive a rebuild the same way a game's board does.
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

  /// Who is up, or null when nobody is (the room acts as one, or play is over).
  TurnHolder? get current;

  /// The next state. Pure — never mutates, always returns.
  TurnSource advance();

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
  TurnSource advance() => this;

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
  TurnSource advance() => sides.isEmpty
      ? this
      : AlternatingSides(sides: sides, at: (at + 1) % sides.length);
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
  TurnSource advance() => RosterOrder(ids: ids, names: names, at: at + 1);

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
  );

  final FairBag bag;
  final List<String> eligible;
  final Map<String, String> names;

  /// Who the last [advance] drew. Null before the first draw — the engine
  /// announces nobody rather than guessing.
  final String? drawn;

  @override
  TurnHolder? get current => drawn == null
      ? null
      : TurnHolder(label: names[drawn!] ?? drawn!, subjectId: drawn);

  @override
  TurnSource advance() {
    if (eligible.isEmpty) return this;
    // `rng` is only reached when the bag refills; FairBag owns the fairness.
    final r = bag.draw(1, eligible, Random());
    return FairDraw(
      bag: r.bag,
      eligible: eligible,
      names: names,
      drawn: r.drawn.isEmpty ? null : r.drawn.first,
    );
  }

  @override
  String? get line {
    final c = current;
    return c == null ? null : "${c.label}'s turn";
  }
}
