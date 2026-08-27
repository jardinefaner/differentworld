// Every `context.push('/literal')` in lib/ must resolve against the REAL
// router.
//
// This exists because dead links kept shipping and none of them were
// catchable by eye: a `?id=` on a route that takes its arguments through
// `extra`, a `/groups/:id/run/:blockId` that was never declared, a
// `/settings/locations` guessed from the screen's name. go_router does not
// throw on these — it silently renders the 404 or falls back to a
// different screen, so the tap "works" and lands somewhere the user did
// not ask for.
//
// A regex version of this check was written first and QUIETLY PASSED a
// deliberately-broken route, because its prefix fallback swallowed the
// failure. So this asks go_router's own matcher instead of imitating it.

import 'dart:io';

import 'package:differentworld/app/router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async => null,
        );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
      ),
    );
  });

  /// Literal push targets, with `$interpolation` replaced by a stand-in
  /// segment. Only fully-literal-or-interpolated paths are checked —
  /// anything built by string concatenation is out of scope and stays a
  /// human problem.
  List<({String file, int line, String target})> pushTargets() {
    final out = <({String file, int line, String target})>[];
    final re = RegExp(r"""context\.push(?:<[^>]*>)?\(\s*'(/[^']*)'""");
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Doc comments and commented-out code are not taps. Worth saying
        // out loud: the first run flagged two, and one of them WAS a real
        // problem — feature_card's example taught `/family/:id`, a route
        // that does not exist. A wrong example ships as a dead link the
        // moment somebody copies it, so it was fixed rather than excused.
        final code = lines[i].trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        for (final m in re.allMatches(lines[i])) {
          var t = m.group(1)!;
          // `${expr}` and `$expr` both stand for one path segment.
          t = t.replaceAll(RegExp(r'\$\{[^}]*\}'), 'x');
          t = t.replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_.]*'), 'x');
          out.add((file: f.path, line: i + 1, target: t));
        }
      }
    }
    return out;
  }

  test('every literal push target resolves to a real route', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    final targets = pushTargets();

    expect(
      targets.length,
      greaterThan(50),
      reason: 'the scan found almost nothing — the regex has drifted',
    );

    final dead = <String>[];
    for (final t in targets) {
      final match = router.configuration.findMatch(Uri.parse(t.target));
      if (match.isError) {
        dead.add('${t.file}:${t.line} → ${t.target}');
      }
    }

    expect(
      dead,
      isEmpty,
      reason:
          'These taps navigate somewhere the user did not ask for. '
          'go_router renders its 404 or a fallback screen instead of '
          'throwing, so nothing surfaces at runtime:\n  '
          '${dead.join("\n  ")}',
    );
  });

  test('the check can actually fail', () {
    // A checker that cannot fail is worse than none, because it is
    // believed. The regex version of this test passed a deliberately
    // broken route; this asserts the matcher rejects one.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    final bogus = router.configuration.findMatch(
      Uri.parse('/groups/g1/run/definitely-not-a-route'),
    );
    expect(bogus.isError, isTrue);
  });
}
