import 'package:differentworld/features/groups/room_skin_background.dart';
import 'package:differentworld/features/groups/room_skins.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ambient room-skin painters must render from a tiny card thumbnail to a
/// full-screen hero without throwing, and an unset skin must be a safe no-op.
void main() {
  testWidgets('every skin paints at thumbnail + hero sizes without throwing', (
    tester,
  ) async {
    for (final size in const [Size(40, 40), Size(360, 180), Size(1200, 800)]) {
      for (final skin in kRoomSkins) {
        await tester.pumpWidget(
          Center(
            child: SizedBox.fromSize(
              size: size,
              child: RoomSkinBackground(skin: skin),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${skin.id} @ $size');
      }
    }
  });

  testWidgets('a null skin renders nothing (the safe fallback)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Center(
        child: SizedBox(
          width: 120,
          height: 80,
          child: RoomSkinBackground(skin: null),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
