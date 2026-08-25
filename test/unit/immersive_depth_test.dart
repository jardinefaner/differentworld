// The immersive providers are reference-counted for one reason: `enter` and
// `exit` are both deferred out of the build phase, so when one fullscreen
// screen replaces another there are two microtasks in flight and the ORDER
// they drain in is not guaranteed. A plain boolean gets the wrong answer in
// one of those orders — chrome reappearing over a fullscreen surface.

import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:differentworld/features/speak/speak_immersive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cast immersive depth', () {
    late ProviderContainer container;
    CastImmersive notifier() => container.read(castImmersiveProvider.notifier);
    bool value() => container.read(castImmersiveProvider);

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('one screen enters and leaves', () {
      expect(value(), isFalse);
      notifier().enter();
      expect(value(), isTrue);
      notifier().exit();
      expect(value(), isFalse);
    });

    test('handover stays immersive when enter drains BEFORE exit', () {
      // The order a plain boolean gets wrong: the incoming screen's enter
      // lands first, then the outgoing screen's deferred exit — which would
      // flip chrome back on over a fullscreen surface.
      notifier().enter(); // screen A is up
      notifier().enter(); // screen B mounts
      notifier().exit(); // screen A's deferred dispose finally runs
      expect(value(), isTrue, reason: 'B is still fullscreen');
    });

    test('handover stays immersive when exit drains BEFORE enter', () {
      notifier().enter(); // A
      notifier().exit(); // A's dispose
      notifier().enter(); // B
      expect(value(), isTrue);
    });

    test('an unmatched exit cannot drive the count negative', () {
      notifier()
        ..exit()
        ..exit();
      expect(value(), isFalse);
      // One enter must still be enough to go immersive — a negative count
      // would have needed three.
      notifier().enter();
      expect(value(), isTrue);
    });
  });

  group('speak immersive depth', () {
    test('same contract', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(speakImmersiveProvider.notifier)
        ..enter()
        ..enter()
        ..exit();
      expect(container.read(speakImmersiveProvider), isTrue);
      n.exit();
      expect(
        container.read(speakImmersiveProvider),
        isFalse,
        reason: 'last one out',
      );
    });
  });
}
