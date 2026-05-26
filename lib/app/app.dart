import 'dart:async';

import 'package:differentworld/app/router.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/env/env.dart';
import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:differentworld/features/omnibox/omnibox_overlay.dart';
import 'package:differentworld/features/photos/photo_upload_queue.dart';
import 'package:differentworld/features/settings/outdoor_mode_setting.dart';
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

    // Photo upload queue:
    //   1. Drain any uploads queued from previous offline sessions
    //      (cold-start case where the device is already online).
    //   2. Start the connectivity listener so future offline-to-
    //      online transitions auto-drain.
    // Both fire-and-forget — the worker logs internally and entity
    // rows hold the `pending:<id>` token until retries succeed, so
    // the UI doesn't depend on these completing before first frame.
    final photoQueue = ref.read(photoUploadQueueProvider);
    unawaited(photoQueue.processQueue());
    photoQueue.startConnectivityListener();
    final router = ref.watch(routerProvider);
    // Outdoor mode (Jordan persona): when on, the high-contrast
    // theme replaces both the light AND dark slots so the active
    // theme is the outdoor variant regardless of OS brightness
    // setting. When off, normal light/dark theme behavior.
    final outdoorAsync = ref.watch(outdoorModeProvider);
    final isOutdoor =
        outdoorAsync.value == OutdoorMode.on;
    final outdoor = isOutdoor ? outdoorTheme() : null;
    return MaterialApp.router(
      title: 'Different World',
      theme: outdoor ?? buildLightTheme(),
      darkTheme: outdoor ?? buildDarkTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Wrap every routed page in:
      //   1. AppTextScaleApplier — applies the user's in-app text-size
      //      override (Settings → Display) on top of the OS dynamic-
      //      type setting. Layered above OmniboxShortcuts so the
      //      shortcut chrome itself respects the user's font preference.
      //   2. OmniboxShortcuts — Cmd+K (mac) / Ctrl+K (everything else)
      //      summons the command palette from any screen.
      //   3. SelectionArea (Wave 111) — every `Text` inside the
      //      routed tree becomes click-and-drag selectable. Only
      //      ONE `SelectableText` existed in the codebase before
      //      this; parents couldn't copy a teacher's note about
      //      their kid, directors couldn't copy an invite code by
      //      dragging across it. The contextMenu uses the platform
      //      defaults (copy / select-all). On native this is a
      //      gestural floating toolbar; on web it's the browser's
      //      own selection model — they just work.
      // All wrappers are shallow — no rebuilds on route changes.
      builder: (context, child) => AppTextScaleApplier(
        child: OmniboxShortcuts(
          child: SelectionArea(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
