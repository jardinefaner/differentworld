import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:differentworld/features/picker/picker_logic.dart';
import 'package:flutter/material.dart';

/// Spotlight — a DATA-driven presentable (docs/VISION.md #18). The screen
/// lands on a kid's name; the teacher taps Spin from the phone.
///
/// **It draws from a [FairBag]: everyone before anyone repeats.** It used to
/// call `Random().nextInt(n)` in its control widget and merely avoid landing
/// on the same name twice running, which in a room of twelve lets one child
/// go three times before another goes once. That mattered more than a bug
/// usually does, because Room tools offered this instrument under the words
/// "Fair turns — everyone before anyone repeats" and routed here. The tool
/// whose entire selling point is fairness was the unfair one, while the fair
/// implementation sat in a different screen a counselor had to leave the
/// activity to reach.
///
/// The bag rides IN the wire-state, so a room screen and the phone driving it
/// agree about who is left — and the draw moved into the reducer, which is
/// where a rule belongs. The bag is keyed by INDEX, not by name: two children
/// called Emma are two entries, and a name-keyed bag would treat them as one.
class PickerState {
  const PickerState({
    required this.names,
    required this.index,
    required this.spun,
    this.bag = '',
    this.fresh = false,
  });

  factory PickerState.fromMap(Map<String, dynamic> m) => PickerState(
    names: [for (final n in (m['names'] as List? ?? const [])) n as String],
    index: (m['i'] as num?)?.toInt() ?? 0,
    spun: m['spun'] == true,
    bag: m['bag'] as String? ?? '',
    fresh: m['fresh'] == true,
  );

  final List<String> names;
  final int index;
  final bool spun;

  /// The fair bag, as its own JSON — the exact string [FairBag] already reads
  /// and writes, so the round reuses the tested serialization rather than
  /// growing a second one.
  final String bag;

  /// True on the draw that started a NEW round: everybody has now had a turn.
  /// Worth saying out loud, because a room notices a repeat and a room that
  /// is told why stops arguing about it.
  final bool fresh;

  String get current => names.isEmpty ? '' : names[index % names.length];

  /// How many are still to come this round — the honest state of the bag.
  int get left {
    if (bag.isEmpty) return 0;
    try {
      return FairBag.fromJson(bag).remaining.length;
    } on Object {
      return 0;
    }
  }
}

class PickerGame extends GameDefinition<PickerState> {
  const PickerGame();

  // Seeds from the roster (Drift), not the content bank — so it is absent
  // from the launcher's content-bank loop and reaches the cockpit through its
  // own seeded tile, the way Now & Next does.
  @override
  bool get seedsFromContentBank => false;

  @override
  String get id => 'picker';

  @override
  String get title => 'Spotlight';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.amber);

  @override
  Map<String, dynamic> initialState(ContentSource content) =>
      seedFor(const <String>[]);

  /// The wire-state for a roster — used by the screen wrapper AND by the cast
  /// cockpit, so a spotlight on a TV is the same round as one in a hand.
  static Map<String, dynamic> seedFor(List<String> names) => {
    'names': names,
    'i': 0,
    'spun': false,
    'fresh': false,
    'bag': FairBag.fresh(_indices(names.length), Random()).toJson(),
  };

  static List<String> _indices(int n) => [for (var i = 0; i < n; i++) '$i'];

  @override
  PickerState decode(Map<String, dynamic> state) => PickerState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final names = [for (final n in (s['names'] as List? ?? const [])) '$n'];
    switch (intent) {
      case GameIntent.next:
        if (names.isEmpty) break;
        final eligible = _indices(names.length);
        final raw = s['bag'] as String? ?? '';
        final bag = raw.isEmpty
            ? FairBag.fresh(eligible, Random())
            : FairBag.fromJson(raw).syncedWith(eligible, Random());
        final result = bag.draw(1, eligible, Random());
        if (result.drawn.isEmpty) break;
        s['i'] = int.tryParse(result.drawn.first) ?? 0;
        s['spun'] = true;
        s['fresh'] = result.refilled;
        s['bag'] = result.bag.toJson();
      case GameIntent.reset:
        s['spun'] = false;
        s['fresh'] = false;
        s['i'] = 0;
        s['bag'] = FairBag.fresh(_indices(names.length), Random()).toJson();
      case GameIntent.tick:
      case GameIntent.back:
      case GameIntent.reveal:
      case GameIntent.pick:
      case GameIntent.tally:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(PickerState s) => {
    GameIntent.next,
    if (s.spun) GameIntent.reset,
  };

  @override
  Widget buildStage(BuildContext context, PickerState s) {
    final theme = Theme.of(context);
    if (s.names.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Add children to your roster to spin the Spotlight.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 18),
          ),
        ),
      );
    }
    return GameStage.frame(
      context,
      // No `turn:` ON PURPOSE — the reveal below is this game's whole point and
      // is deliberately slower than the shared arrival. Two switchers on one
      // hero would fight, and the fair-feeling one would lose.
      eyebrow: s.spun ? _eyebrow(s) : "Who's next?",
      hero: AnimatedSwitcher(
        // Deliberately slow. Instant results feel rigged and a room says so;
        // a reveal that takes a beat feels fair (CLAUDE.md, the half-second
        // rule — this surface is the example it is written about).
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: Text(
          s.spun ? s.current : 'Tap Spin',
          key: ValueKey(s.spun ? '${s.index}-${s.current}' : '_prompt'),
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            color: s.spun ? vibe.accent : Colors.white24,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: s.spun ? _left(context, s) : null,
    );
  }

  /// What the room is told, and never a warning: a repeat is only surprising
  /// if nobody says the round started again.
  String _eyebrow(PickerState s) =>
      s.fresh ? 'Everyone has had a turn' : "You're up!";

  Widget _left(BuildContext context, PickerState s) {
    if (s.names.length < 2) return const SizedBox.shrink();
    final left = s.left;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: GameStage.counter(
        context,
        value: '$left',
        caption: 'still to come',
        accent: vibe.accent,
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    PickerState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    final empty = state.names.isEmpty;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            // No Random here any more: the draw is the RULE, so it lives in
            // the reducer, which is the thing both devices run.
            onPressed: empty ? null : () => send(GameIntent.next),
            icon: const Icon(Icons.casino),
            label: Text(state.spun ? 'Spin again' : 'Spin'),
          ),
        ),
        if (state.spun) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => send(GameIntent.reset),
            icon: const Icon(Icons.replay),
            tooltip: 'Start a fresh round',
          ),
        ],
      ],
    );
  }
}
