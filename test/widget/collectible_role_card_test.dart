import 'package:differentworld/features/heroes/hero_catalog.dart';
import 'package:differentworld/features/heroes/widgets/collectible_role_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a collectible role card shows the role, emoji portrait + footer', (
    tester,
  ) async {
    const data = HeroCardData(
      animal: HeroPick('whale', 'Whale', '🐳'),
      skin: HeroPick('midnight', 'Midnight', '🌙'),
      powers: [
        HeroPick('shield', 'Shield', '🛡️'),
        HeroPick('underwater', 'Breathe underwater', '🌊'),
      ],
      name: 'Wallace',
      from: 'the Deep Sea',
      drawingName: null,
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: CollectibleRoleCard(data: data, childName: 'Maya'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // The role title (Name of From), the emoji portrait (no drawing → emoji),
    // and the owner footer.
    expect(find.text('Wallace of the Deep Sea'), findsOneWidget);
    expect(find.text('🐳'), findsOneWidget);
    expect(find.text('Maya’s card'), findsOneWidget);
  });

  test('roleAccent is stable per animal + safe for null/empty', () {
    expect(roleAccent('whale'), roleAccent('whale'));
    expect(roleAccent('ant'), isNotNull);
    expect(roleAccent(null), isNotNull);
    expect(roleAccent(''), isNotNull);
  });
}
