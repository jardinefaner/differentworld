import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/widgets/present_stage.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// **Cast a world to the room** as a first-class castable stage — so the
/// existing Cast receiver + join-code flow (docs/LIVE_SESSIONS.md) can show
/// the world slideshow, driven from the phone (Back / Next). The wire-state
/// is SELF-DESCRIBING — it carries the rendered slides — so the receiver
/// draws them with no curriculum-catalog access (the framework's content-
/// free-reducer rule). Seeded explicitly via `CastSession.castStage` (it is
/// NOT a content-bank game, so it's hidden from the standard launcher and
/// surfaced by the cockpit's "This week's world" tile).

/// Build the wire-state for casting [world] — its slides, laid out as plain
/// JSON maps (`k` = the slide kind). Index `i`, total `n`, accent hex.
Map<String, dynamic> worldCastSeed(CurriculumWorld world) {
  final slides = <Map<String, dynamic>>[
    {
      'k': 'title',
      'emoji': world.emoji,
      'week': world.week,
      'name': world.name,
      'tagline': world.tagline,
    },
    {'k': 'q', 'text': world.question},
    for (final v in world.videos)
      {'k': 'watch', 'title': v.title, 'min': v.minutes, 'after': v.after},
    {
      'k': 'verbs',
      'verbs': [
        for (final id in world.featuredVerbs)
          if (verbById(id) case final v?) '${v.emoji} ${v.label.toUpperCase()}',
      ],
    },
    {
      'k': 'acts',
      'acts': [for (final a in world.activities) a.split(':').first.trim()],
    },
  ];
  return {
    'i': 0,
    'n': slides.length,
    'slides': slides,
    'accent':
        '#${(world.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
  };
}

class WorldCastState {
  const WorldCastState({
    this.index = 0,
    this.slides = const [],
    this.accent = const Color(0xFF6B5B95),
  });

  factory WorldCastState.fromMap(Map<String, dynamic> m) {
    final raw = <Map<String, dynamic>>[
      for (final e in (m['slides'] as List? ?? const []))
        if (e is Map<String, dynamic>)
          e
        else if (e is Map)
          e.cast<String, dynamic>(),
    ];
    return WorldCastState(
      index: (m['i'] as num?)?.toInt() ?? 0,
      slides: raw,
      accent: _parseHex(m['accent'] as String?),
    );
  }

  final int index;
  final List<Map<String, dynamic>> slides;
  final Color accent;

  int get total => slides.length;
  Map<String, dynamic>? get current =>
      slides.isEmpty ? null : slides[index.clamp(0, slides.length - 1)];
}

Color _parseHex(String? hex) {
  if (hex == null) return const Color(0xFF6B5B95);
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? const Color(0xFF6B5B95) : Color(v);
}

class WorldCastGame extends GameDefinition<WorldCastState> {
  const WorldCastGame();

  static const String gameId = 'world_cast';

  @override
  String get id => gameId;

  @override
  String get title => 'This week’s world';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.plum);

  // Seeded explicitly (castStage), never from the content bank — so it stays
  // out of the standard launcher and is offered by the world tile instead.
  @override
  bool get seedsFromContentBank => false;

  @override
  Map<String, dynamic> initialState(ContentSource content) => <String, dynamic>{
    'i': 0,
    'n': 0,
    'slides': <Map<String, dynamic>>[],
  };

  @override
  WorldCastState decode(Map<String, dynamic> state) =>
      WorldCastState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final i = (s['i'] as num?)?.toInt() ?? 0;
    final n = (s['n'] as num?)?.toInt() ?? 0;
    final last = n <= 0 ? 0 : n - 1;
    switch (intent) {
      case GameIntent.next:
        s['i'] = (i + 1).clamp(0, last);
      case GameIntent.back:
        s['i'] = (i - 1).clamp(0, last);
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
  Set<GameIntent> activeIntents(WorldCastState s) => {
    if (s.index > 0) GameIntent.back,
    if (s.index < s.total - 1) GameIntent.next,
    GameIntent.reset,
  };

  @override
  Widget buildStage(BuildContext context, WorldCastState s) {
    final slide = s.current;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(s.accent.withValues(alpha: 0.45), Colors.black),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: slide == null
              ? const Text('…', style: TextStyle(color: Colors.white24))
              : _slide(context, slide),
        ),
      ),
    );
  }

  Widget _slide(BuildContext context, Map<String, dynamic> m) {
    switch (m['k'] as String?) {
      case 'title':
        return _Title(m: m);
      case 'q':
        return PresentBigText(
          label: 'The question',
          big: '“${m['text']}”',
          displayFont: false,
          shrinkWrap: true,
        );
      case 'watch':
        return PresentBigText(
          label: 'Watch · ${m['min']} min',
          big: '${m['title']}',
          sub: '→ ${m['after']}',
          displayFont: false,
          shrinkWrap: true,
        );
      case 'verbs':
        return _Lines(
          label: 'This week’s verbs',
          lines: [for (final v in (m['verbs'] as List? ?? const [])) '$v'],
          big: true,
        );
      case 'acts':
        return _Lines(
          label: 'Activities',
          lines: [for (final a in (m['acts'] as List? ?? const [])) '• $a'],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${m['emoji']}', style: const TextStyle(fontSize: 130)),
        const SizedBox(height: 20),
        Text(
          'WEEK ${m['week']}',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 22,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${m['name']}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${m['tagline']}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 24,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.label, required this.lines, this.big = false});
  final String label;
  final List<String> lines;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: big
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 20,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 20),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              l,
              style: TextStyle(
                color: Colors.white,
                fontSize: big ? 40 : 24,
                fontWeight: big ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}
