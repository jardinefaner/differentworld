import 'package:differentworld/features/live_session/live_session.dart';

/// Charades state over the generic [LiveSession] (docs/GAMES.md, the
/// two-device showcase): which prompt, how many the room has got, and
/// whether the round is done. The WORD itself lives in the content bank
/// (same on every device); only the actor's/teacher's screens render it.
class CharadesState {
  const CharadesState({this.index = 0, this.found = 0, this.done = false});

  factory CharadesState.fromMap(Map<String, dynamic> m) => CharadesState(
    index: (m['i'] as num?)?.toInt() ?? 0,
    found: (m['f'] as num?)?.toInt() ?? 0,
    done: m['d'] == true,
  );

  final int index;
  final int found;
  final bool done;

  CharadesState copyWith({int? index, int? found, bool? done}) => CharadesState(
    index: index ?? this.index,
    found: found ?? this.found,
    done: done ?? this.done,
  );

  Map<String, dynamic> toMap() => {'i': index, 'f': found, 'd': done};

  /// The seam's [LiveReducer] for Charades, curried with the prompt [total].
  static LiveReducer reducer(int total) =>
      (state, intent, args) =>
          reduce(CharadesState.fromMap(state), intent, total).toMap();

  /// Pure reducer. `got` = guessed (count + advance); `skip` = pass (advance,
  /// no count); `restart` = fresh. (A transform, not a constructor.)
  // ignore: prefer_constructors_over_static_methods
  static CharadesState reduce(CharadesState s, String intent, int total) {
    switch (intent) {
      case 'got':
        if (s.done) return s;
        final f = s.found + 1;
        if (s.index >= total - 1) return s.copyWith(found: f, done: true);
        return s.copyWith(found: f, index: s.index + 1);
      case 'skip':
      case 'next':
        if (s.done) return s;
        if (s.index >= total - 1) return s.copyWith(done: true);
        return s.copyWith(index: s.index + 1);
      case 'restart':
        return const CharadesState();
      default:
        return s; // 'hello' / unknown — no-op (triggers a rebroadcast)
    }
  }
}
