// The six sounds are bundled and mapped — a pad with no note is Simon in
// silence again, which is the state this layer exists to leave behind.

import 'dart:io';

import 'package:differentworld/features/games/game_sounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The plugin asserts without a binding; with one, it fails on the missing
  // channel — which is the case the pool has to survive.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every sound has a bundled file', () {
    for (final s in GameSound.values) {
      expect(File(s.asset).existsSync(), isTrue, reason: s.asset);
      expect(File(s.asset).lengthSync(), greaterThan(1000), reason: s.asset);
    }
  });

  test('the four pads each have a note; other slots are silent', () {
    expect(GameSoundAsset.forSlot(1), GameSound.pad1);
    expect(GameSoundAsset.forSlot(4), GameSound.pad4);
    expect(GameSoundAsset.forSlot(0), isNull);
    expect(GameSoundAsset.forSlot(7), isNull);
  });

  test('playing with no platform never throws — it goes quiet', () async {
    await GameSounds.reset();
    expect(() => GameSounds.play(GameSound.win), returnsNormally);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(() => GameSounds.play(GameSound.pad1), returnsNormally);
  });
}
