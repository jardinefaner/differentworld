import 'dart:async';

import 'package:differentworld/app/router.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/env/env.dart';
import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:differentworld/features/omnibox/omnibox_overlay.dart';
import 'package:differentworld/features/photos/photo_upload_queue.dart';
import 'package:differentworld/features/settings/text_scale_setting.dart';
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

    // Process any deferred photo uploads queued from previous offline
    // sessions. Fire-and-forget — the worker logs internally and the
    // entity rows still hold the `pending:<id>` token until a retry
    // succeeds, so the UI doesn't depend on this completing before
    // first frame.
    unawaited(ref.read(photoUploadQueueProvider).processQueue());
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Different World',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Wrap every routed page in:
      //   1. AppTextScaleApplier — applies the user's in-app text-size
      //      override (Settings → Display) on top of the OS dynamic-
      //      type setting. Layered above OmniboxShortcuts so the
      //      shortcut chrome itself respects the user's font preference.
      //   2. OmniboxShortcuts — Cmd+K (mac) / Ctrl+K (everything else)
      //      summons the command palette from any screen.
      // Both wrappers are shallow — no rebuilds on route changes.
      builder: (context, child) => AppTextScaleApplier(
        child: OmniboxShortcuts(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
