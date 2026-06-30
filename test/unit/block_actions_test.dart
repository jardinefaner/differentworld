import 'package:differentworld/features/action_words/block_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('blockActionKindsFor', () {
    List<BlockActionKind> k(String kind, String title, {bool session = false}) =>
        blockActionKindsFor(
          scheduleKind: kind,
          title: title,
          hasSession: session,
        );

    test('a session block gets the photo-class tray', () {
      expect(k('on_site', 'Rotation 1', session: true), const [
        BlockActionKind.runDeck,
        BlockActionKind.cast,
        BlockActionKind.capture,
        BlockActionKind.observe,
      ]);
    });

    test('session takes precedence over the field-trip / routine branch', () {
      expect(
        k('field_trip', 'Museum workshop', session: true).first,
        BlockActionKind.runDeck,
      );
    });

    test('a field trip gets trip-board / notify / message', () {
      expect(k('field_trip', 'Pond trip'), const [
        BlockActionKind.tripBoard,
        BlockActionKind.notify,
        BlockActionKind.message,
      ]);
    });

    test('arrival → check-in / capture / message', () {
      expect(k('on_site', 'Arrival & check-in'), const [
        BlockActionKind.checkIn,
        BlockActionKind.capture,
        BlockActionKind.message,
      ]);
    });

    test('meal → headcount / capture / observe', () {
      expect(k('break', 'Snack'), const [
        BlockActionKind.headcount,
        BlockActionKind.capture,
        BlockActionKind.observe,
      ]);
    });

    test('outdoor / free play includes incident', () {
      expect(
        k('on_site', 'Free play outside'),
        contains(BlockActionKind.incident),
      );
    });

    test('a closed / pickup block → pickup / message / capture', () {
      expect(k('closed', 'Pickup'), const [
        BlockActionKind.pickup,
        BlockActionKind.message,
        BlockActionKind.capture,
      ]);
      // Any closed block is the handoff, even without a pickup keyword.
      expect(k('closed', 'Wrap up').first, BlockActionKind.pickup);
    });

    test('welcome / circle → words pick / cast / observe', () {
      expect(k('on_site', 'Morning circle'), const [
        BlockActionKind.wordsPick,
        BlockActionKind.cast,
        BlockActionKind.observe,
      ]);
    });

    test('a generic do-it activity → run / capture / observe / cast', () {
      expect(k('on_site', 'Open studio'), const [
        BlockActionKind.runActivity,
        BlockActionKind.capture,
        BlockActionKind.observe,
        BlockActionKind.cast,
      ]);
    });

    test('every tray is non-empty (no block is a dead slide)', () {
      for (final kind in ['on_site', 'break', 'closed', 'field_trip']) {
        expect(k(kind, 'Anything'), isNotEmpty, reason: kind);
      }
    });
  });
}
