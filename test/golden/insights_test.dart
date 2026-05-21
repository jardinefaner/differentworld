import 'package:differentworld/app/theme.dart';
import 'package:differentworld/features/insights/insights_providers.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_helpers.dart';

/// Insights screen — empty state ("All clear · nothing to ask").
/// We golden the empty path because it's deterministic (no real
/// insights → no relative-time-since-yesterday drift). The data
/// path varies on `DateTime.now()` and isn't suitable for a
/// fixed-PNG comparison without a much deeper mock.
void main() {
  goldenAtAllBreakpoints(
    'insights',
    build: () => ProviderScope(
      overrides: [
        insightsProvider.overrideWith(
          (_) => const AsyncValue<List<Insight>>.data(<Insight>[]),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        debugShowCheckedModeBanner: false,
        home: const InsightsScreen(),
      ),
    ),
  );
}
