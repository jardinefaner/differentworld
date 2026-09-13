import 'package:flutter/foundation.dart';

/// **How the room learns what it is about to play** — the run-script.
///
/// The deck's stance until now was a comment in `brain_breaks_screen.dart`:
/// *"The classics. Nothing to teach — four generations already know the
/// rules."* That is true of the adult who grew up with Connect Four. It is
/// false of the person the app most needs to carry: a SUBSTITUTE, handed a
/// room and a screen, who does not know this game, does not know this
/// program's version of it, and cannot stop to read a manual with twenty
/// children waiting.
///
/// So the instructions are not a manual for the adult. They are **beats the
/// ROOM sees**, advanced one tap at a time, in the children's own words. The
/// sub taps Next; the children are told what to do. The adult needs to know
/// nothing beyond where Next is.
///
/// This is deliberately the SAME shape the curriculum already proved:
/// `SessionScript` → `SessionBeat` → `sessionRoomSlides` runs six sessions and
/// seventy beats this way, and the casting law it obeys — the room sees only
/// structured, kid-facing fields, never the adult's script — is the reason a
/// teacher's private cue has never reached a TV. A run-script is that idea
/// made small enough to sit on every game.
@immutable
class RoomBeat {
  const RoomBeat(this.line, {this.detail});

  /// The one line the room reads, in the children's words. Short enough to be
  /// read across a floor, so it is a sentence, not a paragraph.
  final String line;

  /// An optional second line — the qualifier that would otherwise force the
  /// first line to grow. "Across, up, or slanted" belongs here; it is the
  /// detail a child needs only after they have the main idea.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is RoomBeat && other.line == line && other.detail == detail;

  @override
  int get hashCode => Object.hash(line, detail);
}

/// The three questions a run-script answers, in order. Named because the
/// ORDER is the teaching, and a script that skips one leaves the room stuck
/// in a way the adult cannot rescue:
///
/// 1. **What are we playing** — so a child who arrives late can orient.
/// 2. **How it ends** — the goal, which is what makes the middle make sense.
/// 3. **Who starts** — the single question that stalls a room longest, and
///    the one a substitute has no basis to answer.
///
/// Three is a floor, not a cap. A game with a rule the room cannot guess
/// (Charades: no words, no sounds) earns a fourth beat; nothing earns a
/// seventh, because a room stops listening.
typedef RunScript = List<RoomBeat>;
