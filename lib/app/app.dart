import 'package:differentworld/app/router.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/env/env.dart';
import 'package:differentworld/core/sync/power_sync_provider.dart';
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
