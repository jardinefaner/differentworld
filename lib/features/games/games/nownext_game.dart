import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// Now & Next — the highest daily-value presentable (docs/VISION.md #18). The
/// day's schedule on the wall: the CURRENT block big, what's NEXT below, the
/// teacher advancing from the phone as the day moves. Data-driven (the
/// schedule, seeded by the wrapper), so blocks ride in the wire-state. Custom
/// Back/Next controls — no Reveal noise.
class NowNextBlock {
  const NowNextBlock(this.title, this.time, this.kind);
  final String title;
  final String time;
  final String kind;
}

class NowNextState {
  const NowNextState({required this.blocks, required this.index});

  factory NowNextState.fromMap(Map<String, dynamic> m) => NowNextState(
    blocks: [
      for (final b in (m['blocks'] as List? ?? const []))
        NowNextBlock((b as List)[0] as String, b[1] as String, b[2] as String),
    ],
    index: (m['i'] as num?)?.toInt() ?? 0,
  );

  final List<NowNextBlock> blocks;
  final int index;

  NowNextBlock? get current =>
      (index >= 0 && index < blocks.length) ? blocks[index] : null;
  NowNextBlock? get upNext =>
      (index + 1 < blocks.length) ? blocks[index + 1] : null;
}

IconData kindIcon(String kind) => switch (kind) {
  'field_trip' => Icons.directions_bus,
  'break' => Icons.bakery_dining,
  'closed' => Icons.bedtime,
  _ => Icons.auto_awesome,
};

class NowNextGame extends GameDefinition<NowNextState> {
  const NowNextGame();

  // Seeds from the day's schedule (Drift), not the content bank — so it's
  // hidden from the cast launcher until cast can pass it a seed.
  @override
  bool get seedsFromContentBank => false;

  @override
  String get id => 'now-next';

  @override
  String get title => 'Now & Next';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.sage);

  @override
  Map<String, dynamic> initialState(ContentSource content) => {
    'blocks': const <List<String>>[],
    'i': 0,
  };

  @override
  NowNextState decode(Map<String, dynamic> state) =>
      NowNextState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final n = (s['blocks'] as List? ?? const []).length;
    final i = (s['i'] as num?)?.toInt() ?? 0;
    switch (intent) {
      case GameIntent.next:
        if (i < n - 1) s['i'] = i + 1;
      case GameIntent.back:
        if (i > 0) s['i'] = i - 1;
      case GameIntent.reset:
        s['i'] = 0;
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
  Set<GameIntent> activeIntents(NowNextState s) => {
    if (s.index > 0) GameIntent.back,
    if (s.index < s.blocks.length - 1) GameIntent.next,
  };

  @override
  Widget buildStage(BuildContext context, NowNextState s) {
    final theme = Theme.of(context);
    if (s.blocks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "No schedule for today yet.\nAdd blocks to the day to show what's now & next.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 18),
          ),
        ),
      );
    }
    final now = s.current;
    final next = s.upNext;
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Banner(
                  label: 'Now',
                  block: now,
                  accent: vibe.accent,
                  big: true,
                ),
                const SizedBox(height: 16),
                if (next != null)
                  _Banner(label: 'Up next', block: next, accent: Colors.white24)
                else
                  Text(
                    'Last one of the day 🎉',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    NowNextState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    final n = state.blocks.length;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: state.index > 0 ? () => send(GameIntent.back) : null,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Previous',
        ),
        const Spacer(),
        Text(
          n == 0 ? '—' : '${state.index + 1} of $n',
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: state.index < n - 1 ? () => send(GameIntent.next) : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next'),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.label,
    required this.block,
    required this.accent,
    this.big = false,
  });

  final String label;
  final NowNextBlock? block;
  final Color accent;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(big ? 28 : 18),
      decoration: BoxDecoration(
        color: big
            ? accent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: big ? accent : Colors.white24,
          width: big ? 2 : 1,
        ),
      ),
      // One column per card: the label, then the icon + title row, then the
      // time on its own line below — Col[label, Row[icon, title], time].
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: big ? accent : Colors.white54,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              fontSize: big ? 16 : 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                kindIcon(block?.kind ?? ''),
                color: Colors.white,
                size: big ? 40 : 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  block?.title ?? '',
                  style:
                      (big
                              ? theme.textTheme.displaySmall
                              : theme.textTheme.headlineSmall)
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                            height: 1.05,
                          ),
                ),
              ),
            ],
          ),
          if ((block?.time ?? '').isNotEmpty) ...[
            SizedBox(height: big ? 12 : 8),
            Padding(
              // Line up under the title — clear the icon (size) + its 14 gap.
              padding: EdgeInsets.only(left: big ? 54 : 40),
              child: Text(
                block!.time,
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: big ? 22 : 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
