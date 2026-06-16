// Pins the "cockpit as home" toggle (slice 4): defaults OFF, and a set()
// persists to SharedPreferences so the choice survives a relaunch.

import 'package:differentworld/features/settings/cockpit_home_setting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to off, then set() persists', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Default: Today stays home.
    expect(await container.read(cockpitAsHomeProvider.future), isFalse);

    // Opt in.
    await container.read(cockpitAsHomeProvider.notifier).set(value: true);
    expect(container.read(cockpitAsHomeProvider).value, isTrue);

    // Persisted under the documented key.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.cockpit_as_home'), isTrue);
  });

  test('reads a previously-saved on value', () async {
    SharedPreferences.setMockInitialValues({'settings.cockpit_as_home': true});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(cockpitAsHomeProvider.future), isTrue);
  });
}
