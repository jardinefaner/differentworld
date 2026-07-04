import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:flutter/material.dart';

/// Spotlight — a DATA-driven presentable (docs/VISION.md #18). Fair turns:
/// the screen lands on a kid's name, the teacher taps Spin from the phone.
/// Names come from the roster (seeded by the wrapper, not the content bank),
/// and ride in the wire-state so the controller shows the same pick. The
/// random index is generated in the control and passed in `args` → the
/// reducer stays pure.
class PickerState {
  const PickerState({
    required this.names,
    required this.index,
    required this.spun,
  });

  factory PickerState.fromMap(Map<String, dynamic> m) => PickerState(
    names: [for (final n in (m['names'] as List? ?? const [])) n as String],
    index: (m['i'] as num?)?.toInt() ?? 0,
    spun: m['spun'] == true,
  );

  final List<String> names;
  final int index;
  final bool spun;

  String get current => names.isEmpty ? '' : names[index % names.length];
}

class PickerGame extends GameDefinition<PickerState> {
  const PickerGame();

  // Seeds from the roster (Drift), not the content bank — so it's hidden from
  // the cast launcher until cast can pass it a seed.
  @override
  bool get seedsFromContentBank => false;

  @override
  String get id => 'picker';

  @override
  String get title => 'Spotlight';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.amber);

  @override
  String? get liveRoute => '/live/picker';

  @override
  Map<String, dynamic> initialState(ContentSource content) => {
    'names': const <String>[],
    'i': 0,
    'spun': false,
  };

  @override
  PickerState decode(Map<String, dynamic> state) => PickerState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final names = s['names'] as List? ?? const [];
    final i = (s['i'] as num?)?.toInt() ?? 0;
    switch (intent) {
      case GameIntent.next:
        if (names.isEmpty) break;
        final pick = (args['pick'] as num?)?.toInt();
        s['i'] = pick ?? (i + 1) % names.length;
        s['spun'] = true;
      case GameIntent.reset:
        s['spun'] = false;
        s['i'] = 0;
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
  Set<GameIntent> activeIntents(PickerState s) => {GameIntent.next};

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
      eyebrow: s.spun ? "You're up!" : "Who's next?",
      hero: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          s.spun ? s.current : 'Tap Spin',
          key: ValueKey(s.spun ? s.current : '_prompt'),
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            color: s.spun ? vibe.accent : Colors.white24,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    PickerState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    final n = state.names.length;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: n == 0
                ? null
                : () {
                    var r = Random().nextInt(n);
                    // Avoid landing on the same name twice in a row.
                    if (n > 1 && state.spun && r == state.index) {
                      r = (r + 1) % n;
                    }
                    send(GameIntent.next, {'pick': r});
                  },
            icon: const Icon(Icons.casino),
            label: Text(state.spun ? 'Spin again' : 'Spin'),
          ),
        ),
        if (state.spun) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => send(GameIntent.reset),
            icon: const Icon(Icons.replay),
            tooltip: 'Clear',
          ),
        ],
      ],
    );
  }
}
