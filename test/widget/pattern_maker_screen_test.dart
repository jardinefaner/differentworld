// Widget test for the Pattern Maker (docs/ACTIVITY_RUNTIME.md). The
// pre-capture state shows the prompt + Snap button; PatternCanvas repeats
// one tile into a grid of mirrored cells.

import 'dart:convert';

import 'package:differentworld/features/activity_runtime/pattern_maker.dart';
import 'package:differentworld/features/activity_runtime/pattern_maker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// A valid 1×1 transparent PNG — enough for the cells to mount.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('opens on the prompt with a Snap button', (tester) async {
    final router = GoRouter(
      initialLocation: '/activity/pattern',
      routes: [
        GoRoute(
          path: '/activity/pattern',
          builder: (_, _) => const PatternMakerScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make a Pattern'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Snap your tile'), findsOneWidget);
  });

  testWidgets('PatternCanvas repeats the tile into a grid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatternCanvas(
            tile: _png,
            config: const PatternConfig(tilesPerRow: 3),
          ),
        ),
      ),
    );
    await tester.pump();

    // 3×3 = 9 cells, each its own Image.memory.
    expect(find.byType(Image), findsNWidgets(9));
  });
}
