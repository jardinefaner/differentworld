import 'package:differentworld/app/router.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/env/env.dart';
import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DifferentWorldApp extends ConsumerWidget {
  const DifferentWorldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate PowerSync lifecycle (connect/disconnect on auth changes).
    // Only meaningful when env is configured; in tests it's a no-op.
    if (Env.hasPowerSync) {
      ref.watch(powerSyncLifecycleProvider);
    }
    // Activate the deep-link listener at app boot. Reads the cold-launch
    // URI (if any) and subscribes to subsequent links. Errors from this
    // FutureProvider are surfaced through debugPrint; the rest of the
    // app continues fine if deep-link plumbing fails on a given platform.
    ref.watch(deepLinkBootProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Different World',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
