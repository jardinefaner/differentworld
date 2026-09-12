import 'package:flutter/foundation.dart';

/// Where we are in the thing we are doing — the facilitation engine's second
/// facet (docs/FACILITATION.md).
///
/// One idea, previously spelled three ways: a grid game keeps `i`/`n` in its
/// wire-state, a session script counts beats, an activity counts slides. Every
/// surface that wanted to show progress — the control bar, the cast screen, the
/// day strip — had to know all three. This is the one shape they can share.
///
/// Deliberately a **value type with no behaviour beyond arithmetic**: it is a
/// reading of where we are, not a controller. Whatever owns the activity still
/// owns advancing it.
@immutable
class Steps {
  const Steps({required this.index, required this.total, this.label});

  /// 0-based, so it indexes a list without arithmetic at the call site.
  final int index;

  final int total;

  /// What this step IS, when the activity knows — "the demo", "Ask the room".
  /// Null for activities whose steps are just a count.
  final String? label;

  /// 1-based, for reading aloud. The room says "three of eight", never
  /// "two of eight" for the third thing.
  int get human => index + 1;

  bool get isFirst => index <= 0;

  /// True on the LAST step, not past it — "are we finished" is a question for
  /// the activity (a game's `done`, a script's end), because finishing usually
  /// means something happened, not merely that a counter ran out.
  bool get isLast => index >= total - 1;

  double get fraction =>
      total <= 0 ? 0 : (human / total).clamp(0, 1).toDouble();

  /// "3 / 8" — the compact form for a control bar.
  String get counter => '$human / $total';

  /// "Step 3 of 8" or "the demo · 3 of 8" — the spoken form.
  String get spoken =>
      label == null ? 'Step $human of $total' : '$label · $human of $total';

  Steps at(int next) =>
      Steps(index: next.clamp(0, total - 1), total: total, label: label);

  Steps get forward => at(index + 1);
  Steps get back => at(index - 1);

  /// Read a grid game's wire-state, which stores the index as `i` and the
  /// count as `n`. An adapter rather than a dependency: this file must not
  /// import the games layer, or the engine ends up owned by one of its
  /// consumers.
  static Steps? fromWire(Map<String, dynamic> wire, {String? label}) {
    final n = (wire['n'] as num?)?.toInt();
    if (n == null || n <= 0) return null;
    return Steps(
      index: (wire['i'] as num?)?.toInt() ?? 0,
      total: n,
      label: label,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Steps &&
      other.index == index &&
      other.total == total &&
      other.label == label;

  @override
  int get hashCode => Object.hash(index, total, label);

  @override
  String toString() => 'Steps($counter${label == null ? '' : ' — $label'})';
}
