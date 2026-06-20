import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('presentSlides no-ops on an empty deck (never casts nothing)', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    await presentSlides(ctx, title: 'Empty', slides: const []);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SlidePresentScreen renders the first slide + page dots', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SlidePresentScreen(
            title: 'Otters',
            slides: [
              PresentSlide(
                eyebrow: 'NOW · 2:30 – 3:15',
                title: 'Outdoor free play',
                subtitle: 'Sunny field',
                icon: Icons.wb_sunny_outlined,
              ),
              PresentSlide(
                eyebrow: 'NEXT · 3:15',
                title: 'Snack',
                icon: Icons.local_cafe_outlined,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Outdoor free play'), findsOneWidget);
    expect(find.textContaining('NOW'), findsOneWidget);
    // The second page is lazily built by PageView.builder — not in the tree yet.
    expect(find.text('Snack'), findsNothing);
  });
}
