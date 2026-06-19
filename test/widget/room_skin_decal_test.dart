import 'package:differentworld/features/groups/room_skin_background.dart';
import 'package:differentworld/features/groups/room_skins.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cosmetic room decal (docs/VISION.md "two layers of skin"). The golden
/// harness can't seed a room skin through the group-resolution path, so the
/// proof that every signature + the new light DECAL mode actually paints —
/// without a bad Path / divide-by-zero — lives here.
void main() {
  testWidgets('every room skin paints in both decal + immersive modes', (
    tester,
  ) async {
    for (final skin in kRoomSkins) {
      for (final decal in const [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 720,
                child: RoomSkinBackground(
                  skin: skin,
                  decal: decal,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        // The painter ran (it's called during paint); no exception escaped.
        expect(
          tester.takeException(),
          isNull,
          reason: 'skin ${skin.id} (decal=$decal) threw while painting',
        );
        expect(find.byType(CustomPaint), findsWidgets);
      }
    }
  });

  testWidgets('a null skin renders the safe empty fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RoomSkinBackground(skin: null))),
    );
    expect(tester.takeException(), isNull);
  });
}
