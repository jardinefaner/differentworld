import 'package:differentworld/features/action_words/present_timer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The present surface suggests a per-beat timer length but lets the teacher
/// dial any length — and remembers their customs so "customizable" sticks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('mmss', () {
    test('formats a countdown as m:ss', () {
      expect(mmss(300), '5:00');
      expect(mmss(90), '1:30');
      expect(mmss(605), '10:05');
    });

    test('never goes negative', () {
      expect(mmss(0), '0:00');
      expect(mmss(-30), '0:00');
    });
  });

  group('PresentTimerNotifier.remember', () {
    test('dedupes + moves to front', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(presentTimerProvider.future);
      final n = container.read(presentTimerProvider.notifier);

      await n.remember(180);
      await n.remember(420);
      await n.remember(180); // already present → bumped to front

      expect(container.read(presentTimerProvider).value, [180, 420]);
    });

    test('caps at the four most-recent', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(presentTimerProvider.future);
      final n = container.read(presentTimerProvider.notifier);

      for (final s in [60, 120, 300, 600, 900]) {
        await n.remember(s);
      }

      final v = container.read(presentTimerProvider).value!;
      expect(v.length, 4);
      expect(v.first, 900); // most recent
      expect(v.contains(60), isFalse); // oldest dropped
    });

    test('ignores non-positive durations', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(presentTimerProvider.future);
      final n = container.read(presentTimerProvider.notifier);

      await n.remember(0);
      await n.remember(-30);

      expect(container.read(presentTimerProvider).value, isEmpty);
    });
  });

  test('reads back persisted customs on a fresh build', () async {
    SharedPreferences.setMockInitialValues({
      'present.timer.custom_seconds': ['300', '180'],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final v = await container.read(presentTimerProvider.future);

    expect(v, [300, 180]);
  });

  test('drops corrupt persisted entries', () async {
    SharedPreferences.setMockInitialValues({
      'present.timer.custom_seconds': ['300', 'oops', '-5', '180'],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final v = await container.read(presentTimerProvider.future);

    expect(v, [300, 180]);
  });
}
