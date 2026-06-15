import 'package:differentworld/app/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Stub url_launcher so Supabase's auth setup doesn't crash trying to
    // resolve the launch URL channel during tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => null,
    );

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        // detectSessionInUri parses the test runner's URL on boot, which
        // doesn't contain auth tokens — turn it off so initialize() returns
        // cleanly.
        detectSessionInUri: false,
      ),
    );
  });

  testWidgets('unauthenticated boot lands on the login screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DifferentWorldApp()));
    // Bounded pump, NOT pumpAndSettle: the full app shell carries a
    // perpetual ticker (the sync-status indicator / IME cursor) that never
    // goes idle, so pumpAndSettle would hang until its 10-minute timeout.
    // The signed-out redirect to /login is synchronous (sessionProvider
    // reads currentSession == null), so one frame plus a clock advance past
    // the route transition is enough to land on — and fully build — the
    // login screen.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // The login wordmark is now DwWordmark — DIFFERENT / WORLD as two
    // stacked tracked-caps lines (over the Horizon mark).
    expect(find.text('DIFFERENT'), findsOneWidget);
    expect(find.text('WORLD'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
