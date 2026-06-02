// The anonymous board's channel topic (docs/VISION.md #5). The broadcast
// transport itself needs a live server, but the topic key is pure + must be
// stable / case-insensitive so a typed-in code finds the same channel.

import 'package:differentworld/features/live_session/board_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('topicFor is stable, namespaced, and case-insensitive', () {
    expect(BoardSession.topicFor('rj4k'), BoardSession.topicFor('RJ4K'));
    expect(BoardSession.topicFor('AB2C'), 'dw-board-AB2C');
    // Distinct namespace from the game sessions (dw-session-*).
    expect(BoardSession.topicFor('AB2C').startsWith('dw-board-'), isTrue);
  });
}
