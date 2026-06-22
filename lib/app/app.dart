import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/app/router.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/env/env.dart';
import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:differentworld/features/photos/photo_upload_queue.dart';
import 'package:differentworld/features/settings/display_style_setting.dart';
import 'package:differentworld/features/settings/font_choice.dart';
import 'package:differentworld/features/settings/outdoor_mode_setting.dart';
import 'package:differentworld/features/settings/text_scale_setting.dart';
import 'package:differentworld/shared/widgets/orientation_lock.dart';
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
    //   1. End-of-day cleanup: clear un-printed local photo-turn shots the
    //      teacher DIDN'T keep (selective sync, slice 2). AWAITED BEFORE the
    //      drain so a cleanup and an upload can never interleave on the queue.
    //      It never touches a hearted (kept) shot — see cleanupExpiredDeferred.
    //   2. Drain any uploads queued from previous offline sessions
    //      (cold-start case where the device is already online).
    //   3. Start the connectivity listener so future offline-to-
    //      online transitions auto-drain.
    // Steps 1+2 are fire-and-forget relative to first frame (chained so the
    // cleanup finishes before the drain begins) — the worker logs internally
    // and entity rows hold the `pending:<id>` token until retries succeed, so
    // the UI doesn't depend on these completing before first frame.
    final photoQueue = ref.read(photoUploadQueueProvider);
    unawaited(() async {
      await photoQueue.cleanupExpiredDeferred();
      await photoQueue.processQueue();
    }());
    photoQueue.startConnectivityListener();
    final router = ref.watch(routerProvider);
    // Outdoor mode (Jordan persona): when on, the high-contrast
    // theme replaces both the light AND dark slots so the active
    // theme is the outdoor variant regardless of OS brightness
    // setting. When off, normal light/dark theme behavior.
    final outdoorAsync = ref.watch(outdoorModeProvider);
    final isOutdoor = outdoorAsync.value == OutdoorMode.on;
    final outdoor = isOutdoor ? outdoorTheme() : null;
    // Calm is the default look — flatten every raw Card app-wide (Today's
    // cards and the rest) via flatCardTheme. Default Calm (only an explicit
    // 'boxed' choice reverts), so it applies from the FIRST frame — no boxed
    // flash. Semantic cards keep their tint (the theme colour is just the
    // default; an explicit `color:` wins).
    final style = ref.watch(displayStyleProvider).value;
    // Calm AND Clean are both flat (only an explicit 'boxed' opts out); Clean
    // additionally re-voices the type ramp (tight tracking, medium weight,
    // sentence case) — the show_widget mockup look (docs/VISION.md).
    final isCalm = style != DisplayStyle.boxed;
    final cleanText = style == DisplayStyle.clean
        ? AppType.cleanTextTheme()
        : null;
    // The in-app font picker (Settings → Display → Fonts). Re-skins the base
    // ramp with the chosen display + body families; the bundled Fraunces +
    // Space Grotesk default keeps the first frame offline-safe.
    final fontChoice =
        ref.watch(fontChoiceProvider).value ?? FontChoice.fallback;
    final fontText = applyFontChoice(
      cleanText ?? AppType.textTheme(),
      fontChoice,
    );
    ThemeData calmify(ThemeData t) =>
        isCalm ? t.copyWith(cardTheme: flatCardTheme(t.colorScheme)) : t;
    return MaterialApp.router(
      title: 'Different World',
      theme: calmify(outdoor ?? buildLightTheme(textTheme: fontText)),
      darkTheme: calmify(outdoor ?? buildDarkTheme(textTheme: fontText)),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Wrap every routed page in AppTextScaleApplier — applies the user's
      // in-app text-size override (Settings → Display) on top of the OS
      // dynamic-type setting. Shallow — no rebuilds on route changes.
      //
      // Cmd/Ctrl-K (summon search) is bound in AppShell now, alongside the
      // omnibox it opens — the single search surface is the `/search` route
      // (DRY: the old app-wide `OmniboxShortcuts` → `showOmnibox` dialog was
      // a second search UI; folded into the route).
      //
      // Wave 127: SelectionArea was here in Wave 111 but lived
      // OUTSIDE the routed Navigator/Overlay, causing
      // "No Overlay widget found" assertions on every screen build.
      // It now lives inside AppShell (which sits BELOW the routed
      // Navigator), where the Overlay ancestor exists.
      builder: (context, child) => OrientationLock(
        child: AppTextScaleApplier(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
