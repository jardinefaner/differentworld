// The generic LiveSession transport (docs/LIVE_SESSIONS.md). The Realtime
// transport itself isn't unit-tested (needs a live server); the channel
// topic derivation is. The This-or-That reducer + state that USED to live
// here moved to its single source of truth — see this_or_that_game_test.dart
// (the game now drives both /activity and /live).

import 'package:differentworld/features/live_session/live_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('topicFor is stable + case-insensitive', () {
    expect(LiveSession.topicFor('rj4k'), LiveSession.topicFor('RJ4K'));
    expect(LiveSession.topicFor('AB2C'), 'dw-session-AB2C');
  });
}
