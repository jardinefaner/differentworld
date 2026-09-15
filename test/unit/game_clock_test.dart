// Three games are nothing without a clock — Whack-a-Mole's mole moves on its
// own, Simon plays its sequence back, Boggle's sand runs out — and exactly one
// surface used to wind one: the single-device runner, in a private method of
// its State. So all three worked in a hand and FROZE everywhere else. Cast
// Whack-a-Mole to the TV a substitute had just set up and the room watched a
// still picture of a mole; run it across two devices and the same.
//
// The clock belongs to the authority (the thing that reduces), because there
// is exactly one authority per session however many screens are watching —
// which a clock living in the view would not be, the moment a presenter opened
// the fullscreen stage over its own board.

import 'dart:io';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_engine.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_clock.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every surface that holds a reducer, and therefore owes the room a clock.
const _authorities = <String, String>{
  'lib/features/games/game_runner.dart': 'one device',
  'lib/features/live_session/cast_cockpit.dart': 'the cast (phone drives TV)',
  'lib/features/live_session/live_game_screen.dart': 'the live presenter',
};

/// A FRESH bank per call, never a shared one.
///
/// `LocalContentBank` serves UNSEEN items and tracks "seen" for its lifetime,
/// so one instance shared across tests drains: the first test deals every
/// prompt and the rest get empty rounds. It does not fail — it quietly deals
/// nothing, and a test that asserts on an empty round can pass while
/// exercising nothing at all.
LocalContentBank _bank() => LocalContentBank.seededWith(curatedSeeds);

void main() {
  final ticking = liveGames.where((g) => g.ticks).toList();

  test('a game that declares a clock gets one', () {
    final clock = GameClock();
    addTearDown(clock.stop);
    for (final def in ticking) {
      clock.follow(def, () {});
      expect(clock.running, isTrue, reason: '${def.title} got no clock');
    }
    clock
      ..stop()
      ..follow(liveGames.firstWhere((g) => !g.ticks), () {});
    expect(
      clock.running,
      isFalse,
      reason: 'a game with no clock should cost nothing at all',
    );
  });

  test('re-pointing at the same game keeps the beat it is on', () async {
    // A re-cast of the game already on screen must not restart the mole's
    // rhythm mid-round — the cockpit calls follow on every build.
    final clock = GameClock();
    addTearDown(clock.stop);
    var beats = 0;
    final mole = ticking.first;
    clock.follow(mole, () => beats++);
    await Future<void>.delayed(mole.tickEvery * 2.5);
    clock.follow(mole, () => beats++);
    await Future<void>.delayed(mole.tickEvery * 0.8);
    expect(beats, greaterThanOrEqualTo(2), reason: 'the beat stopped');
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('stop means stopped', () async {
    final clock = GameClock();
    var beats = 0;
    final mole = ticking.first;
    clock
      ..follow(mole, () => beats++)
      ..stop();
    await Future<void>.delayed(mole.tickEvery * 2);
    expect(beats, 0);
    expect(clock.running, isFalse);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('a game that declares a clock does something with the beat', () {
    // The other half: declaring `ticks` and ignoring `tick` is a clock that
    // winds nothing, which looks exactly like no clock at all.
    for (final def in ticking) {
      final start = def.initialState(ContentEngine(const <ContentItem>[]));
      var wire = Map<String, dynamic>.from(start);
      var moved = false;
      // A few beats — a sequence game may spend one setting itself up.
      for (var i = 0; i < 6 && !moved; i++) {
        wire = def.reduce(wire, GameIntent.tick, const {});
        moved = wire.toString() != start.toString();
      }
      expect(
        moved,
        isTrue,
        reason: '${def.title} declares a clock and ignores every beat of it',
      );
    }
  });

  test('a timed game actually runs out', () {
    // Scattergories shipped with no clock at all, which is the one thing the
    // game IS — "how many can you get before time runs out". Six squares, all
    // the time in the world, and nothing to play against. Boggle had one
    // nobody could set.
    for (final g in liveGames) {
      if (!g.settings.any((s) => s.id == secondsId)) continue;
      final defaults = defaultSettingValues(g.settings);
      var wire = g.initialStateFor(_bank(), {...defaults, secondsId: 30});
      // A room that answers nothing still gets an ending.
      for (var i = 0; i < 40; i++) {
        wire = g.reduce(wire, GameIntent.tick, const {});
      }
      expect(
        wire['d'],
        isTrue,
        reason: '${g.title} never runs out — the clock is decoration',
      );
      expect(
        (wire['o'] as String?) ?? '',
        isNotEmpty,
        reason: '${g.title} ends on a buzzer and says nothing about it',
      );
      // And it must NOT end early: the sand has to actually last.
      var early = g.initialStateFor(_bank(), {...defaults, secondsId: 30});
      for (var i = 0; i < 10; i++) {
        early = g.reduce(early, GameIntent.tick, const {});
      }
      expect(
        early['d'],
        isNot(true),
        reason: '${g.title} ends a third of the way through its own round',
      );
    }
  });

  test('there is ONE clock, and every authority winds it', () {
    // The count question. A second hand-rolled `Timer.periodic` driving a
    // game's reducer is the defect coming back — it is how the first one
    // ended up reachable from exactly one of three surfaces.
    final stray = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('game_clock.dart')) continue;
      // The Visual Timer repaints its own countdown locally on every device;
      // it drives a widget, not a reducer.
      if (f.path.endsWith('timer_game.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('Timer.periodic') && src.contains('GameIntent')) {
        stray.add(f.path);
      }
    }
    expect(
      stray,
      isEmpty,
      reason: 'a second clock for a game lives here: $stray',
    );

    for (final entry in _authorities.entries) {
      expect(
        File(entry.key).readAsStringSync(),
        contains('GameClock'),
        reason:
            '${entry.value} holds a reducer and winds no clock — every game '
            'with one freezes there',
      );
    }
  });
}
