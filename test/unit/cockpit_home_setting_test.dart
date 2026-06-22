// Pins the "cockpit as home" toggle (slice 4 → WORKFLOWS.md seam 4): defaults
// ON (the advancing spine), and a set() persists to SharedPreferences so the
// choice survives a relaunch.

import 'package:differentworld/features/settings/cockpit_home_setting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to on, then set(false) persists the opt-out', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Default: the cockpit is home (the spine).
    expect(await container.read(cockpitAsHomeProvider.future), isTrue);

    // Opt out → the Today dashboard.
    await container.read(cockpitAsHomeProvider.notifier).set(value: false);
    expect(container.read(cockpitAsHomeProvider).value, isFalse);

    // Persisted under the documented key.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.cockpit_as_home'), isFalse);
  });

  test('reads a previously-saved off value', () async {
    SharedPreferences.setMockInitialValues({'settings.cockpit_as_home': false});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(cockpitAsHomeProvider.future), isFalse);
  });
}
