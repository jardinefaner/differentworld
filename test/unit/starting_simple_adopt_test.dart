// adoptForNewcomer fires on invite redemption, which can happen more than
// once per person — a second program, a re-issued link, a re-install. The
// promise that makes that safe is that it never overrides a choice, so that
// is what is pinned here.

import 'package:differentworld/features/settings/starting_simple_setting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> box() async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(startingSimpleProvider.future);
    return c;
  }

  test('a fresh install starts with the full app', () async {
    final c = await box();
    expect(c.read(startingSimpleProvider).value, isFalse);
  });

  test('joining a program trims a newcomer who has never chosen', () async {
    final c = await box();
    await c.read(startingSimpleProvider.notifier).adoptForNewcomer();
    expect(c.read(startingSimpleProvider).value, isTrue);
  });

  test('it never overrides someone who turned it OFF', () async {
    final c = await box();
    await c.read(startingSimpleProvider.notifier).set(value: false);
    await c.read(startingSimpleProvider.notifier).adoptForNewcomer();
    // The whole point: joining a second program must not silently shrink
    // the app of someone who already said they wanted all of it.
    expect(c.read(startingSimpleProvider).value, isFalse);
  });

  test('it does not re-trim someone who turned it off after joining', () async {
    final c = await box();
    await c.read(startingSimpleProvider.notifier).adoptForNewcomer();
    await c.read(startingSimpleProvider.notifier).set(value: false);
    await c.read(startingSimpleProvider.notifier).adoptForNewcomer();
    expect(c.read(startingSimpleProvider).value, isFalse);
  });

  test(
    'the explanation is unseen until acknowledged, then stays seen',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(await c.read(startingSimpleNoteSeenProvider.future), isFalse);
      await c.read(startingSimpleNoteSeenProvider.notifier).markSeen();
      expect(c.read(startingSimpleNoteSeenProvider).value, isTrue);
    },
  );
}
