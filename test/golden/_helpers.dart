import 'dart:io' show Platform;

import 'package:differentworld/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Goldens are ENVIRONMENT-SENSITIVE and OFF by default.
///
/// Font rasterization + anti-aliasing differ across OS and Flutter
/// versions, so a baseline generated on one machine fails against another
/// with a near-total pixel diff (~98%) even when the screen is unchanged.
/// There is no pinned runner for them — the only CI workflow is
/// `deploy-web.yml` — so they are LOCAL, ON-DEMAND visual checks, not a
/// gate in the default suite.
///
/// Default `flutter test` SKIPS them (they report as skipped; the suite
/// stays green). To run them, regenerate on YOUR machine first, then
/// verify — both behind the `RUN_GOLDENS` env flag:
///
/// ```sh
/// RUN_GOLDENS=1 flutter test --update-goldens test/golden/   # regenerate
/// RUN_GOLDENS=1 flutter test test/golden/                    # verify
/// ```
///
/// Always eyeball the regenerated PNGs before committing — a stray spacing
/// or wrong-color change is exactly what this suite is for.
final bool runGoldens = Platform.environment['RUN_GOLDENS'] == '1';

/// Standard breakpoints the goldens render at. Tests call
/// [pumpAt] once per breakpoint they care about — by convention the
/// PNG filename embeds the breakpoint name so a regression in
/// just-one-form-factor is obvious.
///
/// Sizes match the persona / device targets in CLAUDE.md's
/// "Responsive layout" section.
const Map<String, Size> goldenBreakpoints = <String, Size>{
  'phone-portrait': Size(390, 844), // iPhone 15
  'phone-landscape': Size(844, 390), // same, rotated
  'tablet-portrait': Size(1024, 1366), // 12.9" iPad
  'desktop': Size(1440, 900), // 13" laptop
};

/// One-time per-suite init. Mirrors the bootstrap in widget_test.dart
/// so golden suites can be loaded in isolation without depending on
/// the full app boot.
Future<void> ensureGoldenBootstrap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async => null,
      );

  // The PDF-preview screens (progress report) rasterize via the printing
  // plugin's channel; without it a MissingPluginException fails the plate.
  // Null replies leave the preview on its loading surface — fine for a plate.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('net.nfet.printing'), (
        call,
      ) async {
        // PdfPreview null-checks the info reply, so it needs a real map;
        // "can't print / share / raster" keeps the preview on its calm
        // fallback surface.
        if (call.method == 'printingInfo') {
          return <String, dynamic>{
            'directPrint': false,
            'dynamicLayout': false,
            'canPrint': false,
            'canShare': false,
            'canRaster': false,
          };
        }
        return null;
      });

  // Screens that keep the display awake (galleries, run surfaces) toggle
  // wakelock_plus on mount; without the plugin the pigeon channel throws a
  // PlatformException that fails the plate. Reply "success, null" (pigeon
  // encodes success as a one-element list).
  const wakelockCodec = StandardMessageCodec();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.'
        'WakelockPlusApi.toggle',
        (message) async => wakelockCodec.encodeMessage(<Object?>[null]),
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.'
        'WakelockPlusApi.isEnabled',
        (message) async => wakelockCodec.encodeMessage(<Object?>[false]),
      );

  try {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
      ),
    );
  } on Object {
    // Already initialized by a previous suite in the same process —
    // Supabase.initialize throws an AssertionError on a second call.
  }
}

/// Pump a pre-built widget tree at a specific size. The caller is
/// responsible for constructing the full tree (typically
/// `ProviderScope > MaterialApp > home`), which lets each test site
/// inject its own Riverpod overrides without forcing a typed
/// `List<Override>` parameter through this helper (Override isn't
/// publicly exported by flutter_riverpod).
///
/// Surface size + viewport are set so MediaQuery-aware widgets
/// behave as if they're on a device of [size].
Future<void> pumpAt(
  WidgetTester tester, {
  required Widget app,
  required Size size,
  Duration settle = const Duration(seconds: 1),
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle(settle);
}

/// Wrap a bare screen widget in `ProviderScope > MaterialApp > screen`
/// using the app's theme. Suitable for screens with no provider
/// overrides; screens that need overrides should build the tree
/// inline at the call site.
Widget wrapForGolden(Widget screen) {
  return ProviderScope(
    child: MaterialApp(
      theme: buildLightTheme(),
      debugShowCheckedModeBanner: false,
      home: screen,
    ),
  );
}

/// Standard golden assertion. Filename format:
/// `goldens/{screen}__{breakpoint}.png` — the double underscore is
/// the breakpoint sentinel so a grep finds every variant of one
/// screen.
///
/// Run `flutter test --update-goldens test/golden/` after a UI
/// change to regenerate. CI runs WITHOUT `--update-goldens`; mismatch
/// fails the test.
Future<void> expectGolden(
  WidgetTester tester, {
  required String screen,
  required String breakpoint,
}) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/${screen}__$breakpoint.png'),
  );
}

/// Run a golden test at every breakpoint. The [build] closure is
/// called once per breakpoint to construct the widget tree; it
/// SHOULD return a fully-formed `ProviderScope > MaterialApp` (use
/// [wrapForGolden] when no overrides are needed).
void goldenAtAllBreakpoints(
  String screen, {
  required Widget Function() build,
  Map<String, Size>? breakpoints,
  Duration settle = const Duration(seconds: 1),
}) {
  final sizes = breakpoints ?? goldenBreakpoints;
  group(screen, () {
    setUpAll(ensureGoldenBootstrap);
    for (final entry in sizes.entries) {
      testWidgets(
        '$screen @ ${entry.key}',
        (tester) async {
          await pumpAt(
            tester,
            app: build(),
            size: entry.value,
            settle: settle,
          );
          await expectGolden(
            tester,
            screen: screen,
            breakpoint: entry.key,
          );
        },
        // Environment-sensitive; skipped unless RUN_GOLDENS=1. See the
        // [runGoldens] doc above for how to regenerate + run them.
        skip: !runGoldens,
      );
    }
  });
}
