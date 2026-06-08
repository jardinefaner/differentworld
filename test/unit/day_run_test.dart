import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/day_run_screen.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "day, on rails" assembler: given the live world (+ its rule + this
/// week's thinking game), buildDayRun returns the ordered run of show the
/// teacher just advances through — no hunting across screens.
void main() {
  CurriculumWorld loadWorld(int week) {
    final raw = File('assets/curriculum/ten_worlds.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final worlds = [
      for (final w in decoded['worlds'] as List)
        CurriculumWorld.fromJson(w as Map<String, dynamic>),
    ];
    return worlds.firstWhere((w) => w.week == week);
  }

  ThinkingGame loadThinking(String id) {
    final raw = File(
      'assets/curriculum/thinking_games.json',
    ).readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final g in decoded['games'] as List)
        ThinkingGame.fromJson(g as Map<String, dynamic>),
    ].firstWhere((g) => g.id == id);
  }

  test('the run opens on the world and closes on the reveal handoff', () {
    final beats = buildDayRun(world: loadWorld(4));
    expect(beats.first.kind, DayBeatKind.open);
    expect(beats.last.kind, DayBeatKind.close);
    expect(beats.first.big, isNotEmpty); // the world name
  });

  test('a full run threads the Big Thinking move in order', () {
    final world = loadWorld(4);
    final beats = buildDayRun(
      world: world,
      rules: rulesForWorld(world.id),
      thinking: loadThinking('adaptation'),
    );
    final kinds = beats.map((b) => b.kind).toList();

    // The four thinking beats appear, and in play → name → bridge → ask order.
    expect(
      kinds,
      containsAll(<DayBeatKind>[
        DayBeatKind.play,
        DayBeatKind.name,
        DayBeatKind.bridge,
        DayBeatKind.ask,
      ]),
    );
    expect(
      kinds.indexOf(DayBeatKind.play) < kinds.indexOf(DayBeatKind.name),
      isTrue,
    );
    expect(
      kinds.indexOf(DayBeatKind.name) < kinds.indexOf(DayBeatKind.bridge),
      isTrue,
    );
    expect(
      kinds.indexOf(DayBeatKind.bridge) < kinds.indexOf(DayBeatKind.ask),
      isTrue,
    );
    // The world frame comes before the thinking move, which comes before do.
    expect(
      kinds.indexOf(DayBeatKind.open) < kinds.indexOf(DayBeatKind.play),
      isTrue,
    );
    expect(
      kinds.indexOf(DayBeatKind.ask) < kinds.indexOf(DayBeatKind.activity),
      isTrue,
    );
  });

  test('with no thinking game, the run skips the thinking beats cleanly', () {
    final beats = buildDayRun(world: loadWorld(4));
    final kinds = beats.map((b) => b.kind).toSet();
    expect(kinds.contains(DayBeatKind.play), isFalse);
    expect(kinds.contains(DayBeatKind.open), isTrue);
    expect(kinds.contains(DayBeatKind.verbs), isTrue);
    expect(kinds.contains(DayBeatKind.close), isTrue);
  });

  test('every beat carries something to show (no blank slides)', () {
    final world = loadWorld(7);
    final beats = buildDayRun(
      world: world,
      rules: rulesForWorld(world.id),
      thinking: loadThinking('imagination'),
    );
    for (final b in beats) {
      final hasContent =
          b.big.isNotEmpty || b.lines.isNotEmpty || b.sub.isNotEmpty;
      expect(hasContent, isTrue, reason: '${b.kind} is blank');
      expect(b.label, isNotEmpty, reason: '${b.kind} has no caption');
    }
  });

  group('buildActivityArc — the teleprompter for any activity', () {
    test('runs play → name → bridge → ask → close, in that order', () {
      final kinds = buildActivityArc(
        'making paper boats',
      ).map((b) => b.kind).toList();
      expect(kinds, <DayBeatKind>[
        DayBeatKind.play,
        DayBeatKind.name,
        DayBeatKind.bridge,
        DayBeatKind.ask,
        DayBeatKind.close,
      ]);
    });

    test('the typed activity is the play headline', () {
      final beats = buildActivityArc('building a marble run');
      final play = beats.firstWhere((b) => b.kind == DayBeatKind.play);
      expect(play.big, 'building a marble run');
    });

    test('an empty / whitespace activity falls back to a non-blank prompt', () {
      for (final input in ['', '   ']) {
        final play = buildActivityArc(
          input,
        ).firstWhere((b) => b.kind == DayBeatKind.play);
        expect(play.big.trim(), isNotEmpty, reason: 'blank play headline');
      }
    });

    test('the activity is trimmed (no leading/trailing whitespace leaks)', () {
      final play = buildActivityArc(
        '  snack time  ',
      ).firstWhere((b) => b.kind == DayBeatKind.play);
      expect(play.big, 'snack time');
    });

    test('every beat carries content + a caption (no blank slides)', () {
      for (final b in buildActivityArc('a nature walk')) {
        final hasContent =
            b.big.isNotEmpty || b.lines.isNotEmpty || b.sub.isNotEmpty;
        expect(hasContent, isTrue, reason: '${b.kind} is blank');
        expect(b.label, isNotEmpty, reason: '${b.kind} has no caption');
      }
    });

    test('the bridge beat zooms out across three scopes', () {
      final bridge = buildActivityArc(
        'a drawing',
      ).firstWhere((b) => b.kind == DayBeatKind.bridge);
      expect(bridge.lines.length, 3);
    });

    test('the play beat suggests a 5-minute timer by default', () {
      final play = buildActivityArc(
        'a maze',
      ).firstWhere((b) => b.kind == DayBeatKind.play);
      expect(play.suggestedSeconds, 5 * 60);
    });

    test('a program play length flows into the play beat + its label', () {
      final play = buildActivityArc(
        'a maze',
        playSeconds: 8 * 60,
      ).firstWhere((b) => b.kind == DayBeatKind.play);
      expect(play.suggestedSeconds, 8 * 60);
      expect(play.label, contains('8 minutes'));
    });
  });

  group('suggested timer lengths per beat', () {
    test('the day run carries suggestions on the timed beats only', () {
      final world = loadWorld(7);
      final beats = buildDayRun(
        world: world,
        rules: rulesForWorld(world.id),
        thinking: loadThinking('imagination'),
      );
      // The Big-Thinking play beat suggests the 5-minute play.
      final play = beats.firstWhere((b) => b.kind == DayBeatKind.play);
      expect(play.suggestedSeconds, 5 * 60);
      // Every Watch beat suggests its video length (whole minutes, > 0).
      for (final w in beats.where((b) => b.kind == DayBeatKind.watch)) {
        expect(w.suggestedSeconds, greaterThan(0));
        expect(w.suggestedSeconds % 60, 0);
      }
      // Untimed beats default to 0 (no timer suggested).
      expect(
        beats.firstWhere((b) => b.kind == DayBeatKind.open).suggestedSeconds,
        0,
      );
      expect(
        beats.firstWhere((b) => b.kind == DayBeatKind.close).suggestedSeconds,
        0,
      );
    });

    test('the program play length drives play but not watch', () {
      final world = loadWorld(4);
      List<DayBeat> run(int playSeconds) => buildDayRun(
        world: world,
        rules: rulesForWorld(world.id),
        thinking: loadThinking('adaptation'),
        playSeconds: playSeconds,
      );
      int playOf(List<DayBeat> b) =>
          b.firstWhere((x) => x.kind == DayBeatKind.play).suggestedSeconds;
      List<int> watchesOf(List<DayBeat> b) => [
        for (final x in b)
          if (x.kind == DayBeatKind.watch) x.suggestedSeconds,
      ];

      final a = run(7 * 60);
      final c = run(9 * 60);
      // Play tracks the program length...
      expect(playOf(a), 7 * 60);
      expect(playOf(c), 9 * 60);
      // ...while the Watch beats stay intrinsic (invariant to play length).
      expect(watchesOf(a), watchesOf(c));
    });
  });

  group('initialBeatForPhase — open the run where the day actually is', () {
    List<DayBeat> fullRun() {
      final world = loadWorld(4);
      return buildDayRun(
        world: world,
        rules: rulesForWorld(world.id),
        thinking: loadThinking('adaptation'),
      );
    }

    test('prep / arrival open at the top (beat 0)', () {
      final beats = fullRun();
      expect(DayRunScreen.initialBeatForPhase(beats, DayPhase.prep), 0);
      expect(DayRunScreen.initialBeatForPhase(beats, DayPhase.arrival), 0);
    });

    test('program opens at the doing part (the Big Thinking play beat)', () {
      final beats = fullRun();
      final i = DayRunScreen.initialBeatForPhase(beats, DayPhase.program);
      expect(beats[i].kind, DayBeatKind.play);
    });

    test('pickup / closed open at the closing handoff', () {
      final beats = fullRun();
      for (final phase in [DayPhase.pickup, DayPhase.closed]) {
        final i = DayRunScreen.initialBeatForPhase(beats, phase);
        expect(beats[i].kind, DayBeatKind.close, reason: '$phase');
      }
    });

    test('the index is always in range, even for a minimal run', () {
      // A run with no thinking game still resolves to a valid index for
      // every phase (program falls back to activity → watch → 0).
      final beats = buildDayRun(world: loadWorld(4));
      for (final phase in DayPhase.values) {
        final i = DayRunScreen.initialBeatForPhase(beats, phase);
        expect(i, inInclusiveRange(0, beats.length - 1), reason: '$phase');
      }
    });
  });

  group('dayRunStartIndex — resume the last beat', () {
    List<DayBeat> run() {
      final world = loadWorld(4);
      return buildDayRun(
        world: world,
        rules: rulesForWorld(world.id),
        thinking: loadThinking('adaptation'),
      );
    }

    test('a resume from today, in range, wins over the phase', () {
      final beats = run();
      final i = dayRunStartIndex(
        beats: beats,
        phase: DayPhase.pickup,
        today: '2026-06-07',
        resume: const DayRunResume(date: '2026-06-07', index: 3),
      );
      expect(i, 3); // not teleported to the close beat
    });

    test('a stale (yesterday) resume is ignored → the phase beat', () {
      final beats = run();
      final i = dayRunStartIndex(
        beats: beats,
        phase: DayPhase.pickup,
        today: '2026-06-07',
        resume: const DayRunResume(date: '2026-06-06', index: 3),
      );
      expect(beats[i].kind, DayBeatKind.close); // pickup → close
    });

    test('an out-of-range resume index is ignored → the phase beat', () {
      final beats = run();
      final i = dayRunStartIndex(
        beats: beats,
        phase: DayPhase.program,
        today: '2026-06-07',
        resume: DayRunResume(date: '2026-06-07', index: beats.length + 5),
      );
      expect(beats[i].kind, DayBeatKind.play); // program → play
    });

    test('no resume → the phase beat', () {
      final beats = run();
      expect(
        dayRunStartIndex(
          beats: beats,
          phase: DayPhase.prep,
          today: '2026-06-07',
        ),
        0,
      );
    });
  });
}
