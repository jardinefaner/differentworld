// The Live Board presentable (docs/LIVE_BOARD.md): the stages the cast
// receiver renders. Pins the wire-state round-trip + that each instrument
// shows its content (and stays inside its bounds — the auto-fit law).

import 'package:differentworld/features/live_board/board_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const game = BoardGame();

  group('BoardState wire round-trips', () {
    test('word', () {
      final s = BoardState.fromMap(
        const BoardState(instrument: BoardInstrument.word, word: 'cat').toMap(),
      );
      expect(s.instrument, BoardInstrument.word);
      expect(s.word, 'cat');
    });

    test('spell carries name + word', () {
      final s = BoardState.fromMap(
        const BoardState(
          instrument: BoardInstrument.spell,
          name: 'Maya',
          word: 'because',
        ).toMap(),
      );
      expect(s.instrument, BoardInstrument.spell);
      expect(s.name, 'Maya');
      expect(s.word, 'because');
    });

    test('number carries the count + label', () {
      final s = BoardState.fromMap(
        const BoardState(
          instrument: BoardInstrument.number,
          number: 12,
          word: 'days together',
        ).toMap(),
      );
      expect(s.instrument, BoardInstrument.number);
      expect(s.number, 12);
      expect(s.word, 'days together');
    });

    test('turn carries the kid name', () {
      final s = BoardState.fromMap(
        const BoardState(
          instrument: BoardInstrument.turn,
          name: 'Aria',
        ).toMap(),
      );
      expect(s.instrument, BoardInstrument.turn);
      expect(s.name, 'Aria');
    });

    test('reveal carries lines + shown count', () {
      final s = BoardState.fromMap(
        const BoardState(
          instrument: BoardInstrument.reveal,
          word: 'one\ntwo\nthree',
          number: 2,
        ).toMap(),
      );
      expect(s.instrument, BoardInstrument.reveal);
      expect(s.word, 'one\ntwo\nthree');
      expect(s.number, 2);
    });

    test('sound-it-out chunks split on -, ·, /, space', () {
      expect(soundChunks('but-ter-fly'), ['but', 'ter', 'fly']);
      expect(soundChunks('c·a·t'), ['c', 'a', 't']);
      expect(soundChunks('sun  shine'), ['sun', 'shine']);
      expect(soundChunks('   '), isEmpty);
    });

    test('unknown/empty kind decodes to idle', () {
      expect(
        BoardState.fromMap(const <String, dynamic>{}).instrument,
        BoardInstrument.idle,
      );
    });

    // FUTURE-PROOFING: the buildStage / _state / controls / chip switches are
    // exhaustive (the compiler catches a forgotten enum case), but fromMap
    // maps a STRING → enum, so a new instrument added without a fromMap case
    // would silently decode to idle. This loops EVERY value and asserts the
    // wire round-trips back to itself — so adding an instrument without wiring
    // its decode fails here, loudly, instead of shipping a dead chip.
    test('every BoardInstrument round-trips through the wire', () {
      for (final i in BoardInstrument.values) {
        final back = BoardState.fromMap(BoardState(instrument: i).toMap());
        expect(back.instrument, i, reason: 'fromMap is missing a case for $i');
      }
    });
  });

  // A realistic room-screen size; the auto-fit stages scale to fill it.
  // ProviderScope because the board's stages render PersonAvatar, which
  // watches the drawn-portraits setting on every build — not only when a
  // photo is present.
  Widget host(BoardState state) => ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 640,
            height: 360,
            child: Builder(
              builder: (context) => game.buildStage(context, state),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('word stage shows the word', (tester) async {
    await tester.pumpWidget(
      host(const BoardState(instrument: BoardInstrument.word, word: 'cat')),
    );
    expect(find.text('cat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spell stage shows the word (avatar + word)', (tester) async {
    await tester.pumpWidget(
      host(
        const BoardState(
          instrument: BoardInstrument.spell,
          name: 'Maya',
          word: 'because',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('because'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('number stage shows the count + label', (tester) async {
    await tester.pumpWidget(
      host(
        const BoardState(
          instrument: BoardInstrument.number,
          number: 12,
          word: 'days together',
        ),
      ),
    );
    expect(find.text('12'), findsOneWidget);
    expect(find.text('days together'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turn stage shows whose turn', (tester) async {
    await tester.pumpWidget(
      host(const BoardState(instrument: BoardInstrument.turn, name: 'Aria')),
    );
    await tester.pump();
    expect(find.textContaining('Aria'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reveal stage shows only the revealed lines', (tester) async {
    await tester.pumpWidget(
      host(
        const BoardState(
          instrument: BoardInstrument.reveal,
          word: 'one\ntwo\nthree',
          number: 2,
        ),
      ),
    );
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsNothing); // not yet revealed
    expect(tester.takeException(), isNull);
  });

  testWidgets('sound stage lights chunks up to the lit count', (tester) async {
    await tester.pumpWidget(
      host(
        const BoardState(
          instrument: BoardInstrument.sound,
          word: 'but-ter-fly',
          number: 2,
        ),
      ),
    );
    expect(find.text('but'), findsOneWidget);
    expect(find.text('ter'), findsOneWidget);
    expect(find.text('fly'), findsOneWidget); // shown, just dim until lit
    expect(tester.takeException(), isNull);
  });

  testWidgets('idle stage prompts for an instrument', (tester) async {
    await tester.pumpWidget(host(const BoardState()));
    expect(find.textContaining('instrument'), findsOneWidget);
  });

  // FUTURE-PROOFING: every instrument must render its stage without throwing,
  // even on empty content (the receiver paints it before the teacher types).
  testWidgets('every instrument renders a stage without error', (tester) async {
    for (final i in BoardInstrument.values) {
      await tester.pumpWidget(host(BoardState(instrument: i)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$i stage threw');
    }
  });
}
