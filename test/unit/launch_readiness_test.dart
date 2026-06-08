import 'package:differentworld/features/launch/launch_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Ready to run tomorrow" — the readiness composes from the three real
/// preconditions (a live world, kids enrolled, a day shape), plus a non-gating
/// reminder to print the basket.
void main() {
  test('a brand-new program is not ready and every gate is a todo', () {
    final items = buildReadiness(
      worldLive: false,
      hasKids: false,
      hasPlan: false,
    );
    expect(allReady(items), isFalse);
    expect(readyCount(items), (done: 0, total: 3));
    final gates = items.where((i) => i.gating);
    for (final g in gates) {
      expect(g.status, ReadyStatus.todo);
      expect(g.actionRoute, isNotNull, reason: '${g.id} must offer a fix');
    }
  });

  test('all three preconditions met → ready (the reminder does not gate)', () {
    final items = buildReadiness(
      worldLive: true,
      worldName: 'World of Water',
      week: 4,
      hasKids: true,
      hasPlan: true,
    );
    expect(allReady(items), isTrue);
    expect(readyCount(items), (done: 3, total: 3));
    // The live world's "why" confirms which world + week.
    final journey = items.firstWhere((i) => i.id == 'journey');
    expect(journey.status, ReadyStatus.done);
    expect(journey.why, contains('World of Water'));
    expect(journey.why, contains('Week 4'));
  });

  test('the print reminder is always present and never gates readiness', () {
    final items = buildReadiness(worldLive: true, hasKids: true, hasPlan: true);
    final cards = items.firstWhere((i) => i.id == 'cards');
    expect(cards.status, ReadyStatus.info);
    expect(cards.gating, isFalse);
    expect(cards.actionRoute, '/print');
    expect(allReady(items), isTrue); // info item doesn't block "ready"
  });

  test('partial setup counts correctly', () {
    final items = buildReadiness(
      worldLive: true,
      hasKids: true,
      hasPlan: false,
    );
    expect(allReady(items), isFalse);
    expect(readyCount(items), (done: 2, total: 3));
    expect(
      items.firstWhere((i) => i.id == 'plan').status,
      ReadyStatus.todo,
    );
  });
}
