import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/captures/capture_inbox_screen.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_helpers.dart';

/// Capture inbox — empty state ("No captures yet"). The data path
/// requires a stable timestamp (relative-time formatting drifts on
/// every run), so we golden empty and leave loaded-state assertions
/// to widget tests with `withClock`.
void main() {
  goldenAtAllBreakpoints(
    'captures',
    build: () => ProviderScope(
      overrides: [
        capturesProvider(CaptureFilter.open).overrideWith(
          (_) => Stream<List<Capture>>.value(const <Capture>[]),
        ),
        capturesProvider(CaptureFilter.all).overrideWith(
          (_) => Stream<List<Capture>>.value(const <Capture>[]),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        debugShowCheckedModeBanner: false,
        home: const CaptureInboxScreen(),
      ),
    ),
  );
}
