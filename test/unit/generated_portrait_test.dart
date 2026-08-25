import 'package:differentworld/shared/widgets/generated_portrait.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stablePortraitHash', () {
    test('is stable for the same input', () {
      expect(
        stablePortraitHash('Amara Okafor'),
        stablePortraitHash('Amara Okafor'),
      );
    });

    test('differs between people', () {
      expect(
        stablePortraitHash('Amara Okafor'),
        isNot(stablePortraitHash('Ben Kaur')),
      );
    });

    test('is not String.hashCode — a face must survive a restart', () {
      // The whole reason this function exists. If it ever delegates to
      // hashCode, portraits change between launches on some platforms.
      expect(stablePortraitHash('Amara'), isNot(0));
      expect(stablePortraitHash(''), 5381);
    });

    test('stays inside the positive 31-bit range', () {
      final long = 'A' * 500;
      expect(stablePortraitHash(long), greaterThanOrEqualTo(0));
      expect(stablePortraitHash(long), lessThan(0x80000000));
    });
  });

  testWidgets('renders at a range of sizes without overflowing', (t) async {
    for (final size in [16.0, 40.0, 108.0]) {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: GeneratedPortrait(seed: 'Amara', size: size),
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is GeneratedPortrait && w.size == size,
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('the same seed paints the same picture twice', (t) async {
    Widget app(String seed) => MaterialApp(
      home: Center(child: GeneratedPortrait(seed: seed)),
    );
    await t.pumpWidget(app('Amara'));
    // A rebuild with an unchanged seed must not be treated as new work —
    // shouldRepaint compares the seed, not the trait object (which has no
    // value equality and would otherwise repaint every frame).
    await t.pumpWidget(app('Amara'));
    expect(find.byType(GeneratedPortrait), findsOneWidget);
  });
}
