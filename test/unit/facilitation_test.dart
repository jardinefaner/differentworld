// The facilitation engine's first two seams (docs/FACILITATION.md): one shape
// for "where are we", and one role for "whose turn".
//
// The point of these tests is not that the arithmetic works — it is that each
// TurnSource preserves the rule its original implementation existed to
// guarantee. FairDraw wrapping the picker's FairBag has to keep "everyone
// before anyone repeats", or the wrapper is a regression wearing an
// abstraction.

import 'dart:math';

import 'package:differentworld/features/facilitation/steps.dart';
import 'package:differentworld/features/facilitation/turn_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Steps — one shape for three encodings', () {
    test('reads a grid game wire-state', () {
      final s = Steps.fromWire({'i': 2, 'n': 8});
      expect(s, isNotNull);
      expect(s!.index, 2);
      expect(s.human, 3, reason: 'the room says "three of eight"');
      expect(s.counter, '3 / 8');
      expect(s.spoken, 'Step 3 of 8');
    });

    test('a labelled step reads as what it IS, not just a number', () {
      final s = Steps.fromWire({'i': 1, 'n': 6}, label: 'the demo');
      expect(s!.spoken, 'the demo · 2 of 6');
    });

    test('a wire-state with no count is not a step', () {
      // A game that has not dealt yet must not render "1 / 0".
      expect(Steps.fromWire(const {}), isNull);
      expect(Steps.fromWire(const {'i': 0, 'n': 0}), isNull);
    });

    test('first and last are edges, not out-of-range', () {
      const s = Steps(index: 0, total: 3);
      expect(s.isFirst, isTrue);
      expect(s.isLast, isFalse);
      expect(s.forward.forward.isLast, isTrue);
      // Clamped: stepping past the end stays ON the end. "Are we finished" is
      // the activity's question, not the counter's.
      expect(s.forward.forward.forward.index, 2);
      expect(s.back.index, 0);
    });

    test('fraction is bounded', () {
      expect(const Steps(index: 0, total: 4).fraction, closeTo(0.25, 1e-9));
      expect(const Steps(index: 3, total: 4).fraction, 1.0);
    });

    test('a zero-total Steps is rejected at construction', () {
      // Not merely unused — `at()` clamps to `total - 1` and `clamp(0, -1)`
      // throws, so a zero-total would have failed on the first navigation
      // instead of at the mistake.
      expect(() => Steps(index: 0, total: 0), throwsA(isA<AssertionError>()));
    });
  });

  group('NoTurn — the honest default', () {
    test('announces nothing rather than announcing nobody', () {
      const t = NoTurn();
      expect(t.current, isNull);
      expect(t.line, isNull, reason: '"null to play" is worse than silence');
      expect(t.advance(), same(t));
    });
  });

  group('AlternatingSides — two sides, flipping', () {
    test('names whose go it is and hands over', () {
      const t = AlternatingSides(sides: ['Team 1', 'Team 2']);
      expect(t.current!.label, 'Team 1');
      expect(t.current!.side, 0);
      expect(t.line, 'Team 1 to play');

      final next = t.advance() as AlternatingSides;
      expect(next.current!.label, 'Team 2');
      expect(next.advance().current!.label, 'Team 1', reason: 'it wraps');
    });

    test('is pure — advancing does not mutate the original', () {
      const t = AlternatingSides(sides: ['A', 'B']);
      t.advance();
      expect(t.at, 0, reason: 'a turn can ride the wire and survive a rebuild');
    });

    test('empty sides announce nothing', () {
      const t = AlternatingSides(sides: []);
      expect(t.current, isNull);
      expect(t.line, isNull);
    });
  });

  group('RosterOrder — each child once, then done', () {
    const ids = ['s1', 's2', 's3'];
    const names = {'s1': 'Amara', 's2': 'Bo', 's3': 'Chen'};

    test('goes in order and says whose turn', () {
      TurnSource t = const RosterOrder(ids: ids, names: names);
      expect(t.current!.label, 'Amara');
      expect(t.current!.subjectId, 's1', reason: 'a person, so it can link');
      expect(t.line, "Amara's turn");

      t = t.advance();
      expect(t.current!.label, 'Bo');
    });

    test('ends rather than wrapping — that IS the activity ending', () {
      TurnSource t = const RosterOrder(ids: ids, names: names);
      for (var i = 0; i < 3; i++) {
        t = t.advance();
      }
      expect((t as RosterOrder).isDone, isTrue);
      expect(t.current, isNull);
      expect(t.line, isNull);
    });

    test('a missing name falls back to the id rather than throwing', () {
      // A roster mid-sync must not break the turn.
      const t = RosterOrder(ids: ['s9'], names: {});
      expect(t.current!.label, 's9');
    });
  });

  group('FairDraw — everyone before anyone repeats', () {
    const names = {'a': 'Amara', 'b': 'Bo', 'c': 'Chen', 'd': 'Dee'};
    const eligible = ['a', 'b', 'c', 'd'];

    test('announces nobody before the first draw', () {
      final t = FairDraw.fresh(
        eligible: eligible,
        names: names,
        rng: Random(1),
      );
      expect(t.current, isNull, reason: 'it has not drawn yet');
      expect(t.line, isNull);
    });

    test('THE RULE: a full round picks everyone exactly once', () {
      // This is the guarantee the picker exists for. If wrapping FairBag broke
      // it, the abstraction would be a regression.
      TurnSource t = FairDraw.fresh(
        eligible: eligible,
        names: names,
        rng: Random(7),
      );
      final seen = <String>[];
      for (var i = 0; i < eligible.length; i++) {
        t = t.advance();
        seen.add(t.current!.subjectId!);
      }
      expect(
        seen.toSet().length,
        eligible.length,
        reason: 'no repeat inside one round: $seen',
      );
      expect(seen.toSet(), eligible.toSet());
    });

    test('the round refills, so a second round is a fresh shuffle', () {
      TurnSource t = FairDraw.fresh(
        eligible: eligible,
        names: names,
        rng: Random(3),
      );
      final seen = <String>[];
      for (var i = 0; i < eligible.length * 2; i++) {
        t = t.advance();
        seen.add(t.current!.subjectId!);
      }
      final second = seen.sublist(eligible.length);
      expect(
        second.toSet().length,
        eligible.length,
        reason: 'the second round is also everyone-once: $second',
      );
    });

    test('an empty room advances to nothing rather than throwing', () {
      final t = FairDraw.fresh(
        eligible: const [],
        names: const {},
        rng: Random(1),
      );
      expect(t.advance().current, isNull);
    });

    test('a seeded draw is reproducible, refills included', () {
      // The rng is CARRIED now, so the interesting case — the order of a
      // fresh round after the bag empties — is pinnable rather than luck.
      List<String> run(int seed) {
        TurnSource t = FairDraw.fresh(
          eligible: eligible,
          names: names,
          rng: Random(seed),
        );
        final seen = <String>[];
        for (var i = 0; i < eligible.length * 2; i++) {
          t = t.advance();
          seen.add(t.current!.subjectId!);
        }
        return seen;
      }

      expect(run(11), run(11), reason: 'same seed, same sequence');
    });

    test('a derived state does not share a collection with its parent', () {
      // The doc promises this of states produced by advance(); a promise in a
      // comment that the code does not keep is the failure mode to avoid.
      final t =
          FairDraw.fresh(
                eligible: List.of(eligible),
                names: Map.of(names),
                rng: Random(4),
              ).advance()
              as FairDraw;
      expect(() => t.eligible.add('zzz'), throwsUnsupportedError);
      expect(() => t.names['zzz'] = 'Z', throwsUnsupportedError);
    });

    test('the drawn person carries an id, so a surface can link to them', () {
      final t = FairDraw.fresh(
        eligible: eligible,
        names: names,
        rng: Random(5),
      ).advance();
      expect(t.current!.subjectId, isNotNull);
      expect(t.current!.label, names[t.current!.subjectId]);
    });
  });

  group('EveryoneOnce — everyone once, the adult picks', () {
    const ids = ['a', 'b', 'c'];
    const names = {'a': 'Amara', 'b': 'Bo', 'c': 'Chen'};

    test('nobody is automatically up — that IS the rule', () {
      const t = EveryoneOnce(ids: ids, names: names);
      expect(t.current, isNull);
      expect(
        t.choices.map((h) => h.subjectId),
        ids,
        reason:
            'a non-empty choices list is how a surface knows to show a picker',
      );
    });

    test('the count is what the room needs, not a name', () {
      const t = EveryoneOnce(ids: ids, names: names, done: {'a'});
      expect(t.remaining, 2);
      expect(t.line, '2 still to go');
      expect(t.hasGone('a'), isTrue);
      expect(t.hasGone('b'), isFalse);
    });

    test('choosing marks that child and removes them from the choices', () {
      const t = EveryoneOnce(ids: ids, names: names);
      final after = t.advance(chosen: 'b') as EveryoneOnce;
      expect(after.hasGone('b'), isTrue);
      expect(after.choices.map((h) => h.subjectId), ['a', 'c']);
      expect(t.remaining, 3, reason: 'pure — the original is untouched');
      expect(
        () => after.done.add('c'),
        throwsUnsupportedError,
        reason: 'a derived state owns collections nobody else can mutate',
      );
    });

    test('advancing with no choice changes nothing', () {
      // The adult has not picked yet; guessing for them would be wrong.
      const t = EveryoneOnce(ids: ids, names: names);
      expect((t.advance() as EveryoneOnce).remaining, 3);
    });

    test('done when everyone has gone, and it stops announcing', () {
      const t = EveryoneOnce(ids: ids, names: names, done: {'a', 'b', 'c'});
      expect(t.isDone, isTrue);
      expect(t.line, isNull);
      expect(t.choices, isEmpty);
    });

    test('an empty roster is not "done" — there is nothing to finish', () {
      const t = EveryoneOnce(ids: [], names: {});
      expect(
        t.isDone,
        isFalse,
        reason: 'an empty room has not completed a round',
      );
    });

    test('done may include ids not on the roster, and is ignored', () {
      // The real set is a MERGE of this session and what the data layer says
      // already shot — which can name a child who has since left the group.
      const t = EveryoneOnce(ids: ids, names: names, done: {'a', 'gone'});
      expect(t.remaining, 2);
    });
  });

  group('the role holds across implementations', () {
    test('every source answers the same three questions', () {
      final sources = <TurnSource>[
        const NoTurn(),
        const AlternatingSides(sides: ['A', 'B']),
        const RosterOrder(ids: ['x'], names: {'x': 'Ex'}),
        const EveryoneOnce(ids: ['x'], names: {'x': 'Ex'}),
        FairDraw.fresh(
          eligible: const ['x'],
          names: const {'x': 'Ex'},
          rng: Random(2),
        ),
      ];
      for (final s in sources) {
        // No throw, and advancing always returns a source of the same role —
        // which is what lets an activity hold one without knowing which it is.
        expect(() => s.current, returnsNormally);
        expect(() => s.line, returnsNormally);
        expect(() => s.choices, returnsNormally);
        expect(s.advance(), isA<TurnSource>());
      }
    });
  });
}
