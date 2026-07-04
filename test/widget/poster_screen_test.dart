// PosterScreen's empty state must be a designed call-to-action, never a
// blank screen (the screen-rubric "empty state" requirement). The editor /
// working / error states depend on a picked image (image_picker channel),
// so they're exercised on-device; the geometry is pinned in
// test/unit/poster_engine_test.dart.

import 'package:differentworld/features/poster/poster_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty state shows the pick-a-source CTA (not a blank screen)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PosterScreen()),
      ),
    );
    // Let EdgeScaffold's microtask chrome push settle.
    await tester.pump();

    expect(find.text('Make something big'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
  });
}
