---
name: test-widget-pattern
description: The setUp pattern for widget tests that need to mount the app with Supabase + SharedPreferences mocked. Triggered when adding a new widget test.
---

# Widget test scaffolding

`test/widget_test.dart` is the only widget test today. Pattern to copy
for any new one:

## setUp

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Stub the url_launcher channel — Supabase auth touches it.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (_) async => true,
    );

    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,  // ← required in tests
      ),
    );
  });

  testWidgets('your test name', (tester) async {
    await tester.pumpWidget(/* ... */);
    // ...
  });
}
```

## Why these stubs

- **`SharedPreferences.setMockInitialValues({})`** — Supabase persists
  session info here; without the mock it tries the platform channel
- **`url_launcher` channel stub** — the OAuth flow opens browser URLs
- **`detectSessionInUri: false`** — otherwise Supabase reads the test
  process's argv looking for an OAuth code and crashes

## Skip what you don't need

If your test doesn't mount the whole app (just one widget), you can
skip the Supabase.initialize. But for any test that touches
`appDatabaseProvider` / `currentMemberProvider`, you need it.

## ProviderScope override

Mock providers via overrides:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      currentMemberProvider.overrideWith((_) => Stream.value(testMember)),
    ],
    child: DifferentWorldApp(),
  ),
);
```

## Hot reload + PowerSync

Tests don't hit PowerSync, but if you accidentally trigger a connection
attempt the test hangs. Make sure your overrides cut the chain before
`powerSyncProvider` runs.
