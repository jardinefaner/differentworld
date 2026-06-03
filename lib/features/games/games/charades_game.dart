import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// Charades on the unified game framework (docs/GAMES.md, the three-device
/// showcase). The first game with a SECRET role: the **room** (presenter) sees
/// only the category, the **actor** (a phone that joins as secret) sees the
/// word, and the **teacher** (controller) sees the word + marks Got it / Skip.
///
/// The words ride in the wire-state (the presenter builds + broadcasts it);
/// secrecy is by RENDERING — `buildStage` (the room) never draws the word.
class CharadesState {
  const CharadesState({
    this.index = 0,
    this.found = 0,
    this.done = false,
    this.items = const [],
  });

  factory CharadesState.fromMap(Map<String, dynamic> m) => CharadesState(
        index: (m['i'] as num?)?.toInt() ?? 0,
        found: (m['f'] as num?)?.toInt() ?? 0,
        done: m['d'] == true,
        items: [
          for (final it in (m['items'] as List? ?? const []))
            [for (final x in (it as List)) x.toString()],
        ],
      );

  final int index;
  final int found;
  final bool done;

  /// `[word, category]` per prompt.
  final List<List<String>> items;

  int get total => items.length;
  String get word => index < items.length ? items[index][0] : '';
  String get category => index < items.length ? items[index][1] : '';
}

class CharadesGame extends GameDefinition<CharadesState> {
  const CharadesGame();

  @override
  String get id => 'charades';

  @override
  String get title => 'Charades';

  @override
  GameVibe get vibe =>
      const GameVibe(accent: Color(0xFFB388FF), surface: Color(0xFF15101F));

  @override
  String? get liveRoute => '/live/charades';

  @override
  bool get hasSecretRole => true;

  @override
  Map<String, dynamic> initialState(ContentSource content) {
    // The engine returns up to 16 fresh, shuffled prompts (skipping ones
    // recently served); the items ride in the broadcast wire-state, so every
    // device maps index → the same word.
    final picked = content.take(ContentKind.charades, 16);
    final items = [
      for (final c in picked)
        [c.payload['word']! as String, c.payload['category']! as String],
    ];
    return {'i': 0, 'f': 0, 'd': false, 'n': items.length, 'items': items};
  }

  @override
  CharadesState decode(Map<String, dynamic> state) =>
      CharadesState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final i = (s['i'] as num?)?.toInt() ?? 0;
    final f = (s['f'] as num?)?.toInt() ?? 0;
    final n = (s['n'] as num?)?.toInt() ?? 0;
    final done = s['d'] == true;
    switch (intent) {
      case GameIntent.tally: // Got it — count + advance.
        if (done) break;
        s['f'] = f + 1;
        if (i >= n - 1) {
          s['d'] = true;
        } else {
          s['i'] = i + 1;
        }
      case GameIntent.next: // Skip — advance, no count.
        if (done) break;
        if (i >= n - 1) {
          s['d'] = true;
        } else {
          s['i'] = i + 1;
        }
      case GameIntent.reset: // Play again — keep the items, reset progress.
        s['i'] = 0;
        s['f'] = 0;
        s['d'] = false;
      case GameIntent.back:
      case GameIntent.reveal:
      case GameIntent.pick:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(CharadesState s) =>
      s.done ? {GameIntent.reset} : {GameIntent.tally, GameIntent.next};

  // The ROOM (presenter) — category + score, never the word.
  @override
  Widget buildStage(BuildContext context, CharadesState s) {
    final theme = Theme.of(context);
    if (s.done) return _wrap(context, s);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ACT IT OUT — NO WORDS!',
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.category,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              color: vibe.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${s.found} guessed',
            style: const TextStyle(color: Colors.white70, fontSize: 20),
          ),
        ],
      ),
    );
  }

  // The ACTOR + the TEACHER — the secret word.
  @override
  Widget buildSecretStage(BuildContext context, CharadesState state) {
    final theme = Theme.of(context);
    if (state.done) return _wrap(context, state);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ACT THIS OUT — NO TALKING!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.word,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "(${state.category} · the room can't see this)",
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    CharadesState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    if (state.done) {
      return Row(
        children: [
          const Spacer(),
          FilledButton.icon(
            onPressed: () => send(GameIntent.reset),
            icon: const Icon(Icons.replay),
            label: const Text('Play again'),
          ),
        ],
      );
    }
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () => send(GameIntent.next),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
          ),
          icon: const Icon(Icons.skip_next),
          label: const Text('Skip'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => send(GameIntent.tally),
            icon: const Icon(Icons.check),
            label: const Text(
              'Got it!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wrap(BuildContext context, CharadesState s) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎭', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            'Great round!',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${s.found} guessed, together.',
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
