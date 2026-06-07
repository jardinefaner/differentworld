import 'package:differentworld/features/groups/room_skins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog includes the named room themes, with unique ids', () {
    final ids = kRoomSkins.map((s) => s.id).toList();
    expect(
      ids,
      containsAll(<String>['space', 'underwater', 'urban', 'safari', 'travel']),
    );
    expect(ids.toSet().length, ids.length); // unique
    for (final s in kRoomSkins) {
      expect(s.emoji, isNotEmpty);
      expect(s.name, isNotEmpty);
    }
  });

  test('roomSkinById round-trips and is null-safe', () {
    expect(roomSkinById(null), isNull);
    expect(roomSkinById('nope'), isNull);
    for (final s in kRoomSkins) {
      expect(roomSkinById(s.id), same(s));
    }
  });
}
