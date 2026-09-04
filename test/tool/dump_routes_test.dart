// Not a test — a route DUMPER that borrows the test harness because the
// router is a Riverpod provider and only Dart can walk it.
//
// Regexing `path:` out of router.dart does not work: go_router NESTS routes
// and a child's `path` is relative, so `'now'` under `'/'` is `/now` and
// `'block'` under `'/schedule'` is `/schedule/block`. A regex sees bare
// segments and gets both the full path and the nesting depth wrong, which
// makes every "is this buried?" and "is this reachable?" judgement wrong with
// it. This asks the router.
//
//     flutter test test/tool/dump_routes_test.dart --dart-define=DUMP=1
//
// Writes build/route_map.json for tool/map_screens.py to join against.

import 'dart:convert';
import 'dart:io';

import 'package:differentworld/app/router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Same bootstrap as no_dead_links_test — `routerProvider` reaches
  // `supabaseProvider`, which asserts on an uninitialised Supabase.
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
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
  });

  test('dump the route tree', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    final rows = <Map<String, dynamic>>[];

    void walk(List<RouteBase> routes, String parent) {
      for (final r in routes) {
        var full = parent;
        if (r is GoRoute) {
          final p = r.path;
          full = p.startsWith('/')
              ? p
              : (parent.endsWith('/') ? '$parent$p' : '$parent/$p');
          rows.add({
            'path': full,
            'name': r.name,
            // The builder's runtime type is the closure, not the screen — the
            // screen name is resolved by the Python side from the source.
            'hasBuilder': r.builder != null || r.pageBuilder != null,
            'depth': full.split('/').where((s) => s.isNotEmpty).length,
          });
        }
        if (r.routes.isNotEmpty) walk(r.routes, full);
      }
    }

    walk(router.configuration.routes, '');

    final out = File('build/route_map.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
    // This is a dumper, not a test — the path it wrote is the useful output,
    // and a caller needs to see it.
    // ignore: avoid_print
    print('wrote ${rows.length} routes to ${out.path}');
    expect(rows, isNotEmpty);
  });
}
