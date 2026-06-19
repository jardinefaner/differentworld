// brewPotion (docs/VISION.md 2026-06-19) must always yield a makeable recipe —
// a couple of counted ingredients, a sensible stir count, an effect — and be
// deterministic per salt (so "brew another" is a real re-roll, not chaos).

import 'package:differentworld/features/activity_runtime/potions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a recipe is always makeable — counted ingredients, stir, effect', () {
    for (var salt = 1; salt <= 50; salt++) {
      final p = brewPotion(salt);
      expect(
        p.ingredients.length,
        inInclusiveRange(2, 3),
        reason: 'salt $salt',
      );
      for (final ing in p.ingredients) {
        expect(ing.count, inInclusiveRange(1, 5), reason: 'count salt $salt');
        expect(ing.name.trim(), isNotEmpty);
        expect(ing.emoji.trim(), isNotEmpty);
      }
      expect(p.stirs, inInclusiveRange(3, 7), reason: 'stirs salt $salt');
      expect(p.effect.trim(), isNotEmpty);
    }
  });

  test('same salt is deterministic', () {
    final a = brewPotion(9);
    final b = brewPotion(9);
    expect(a.stirs, b.stirs);
    expect(a.effect, b.effect);
    expect(
      a.ingredients.map((i) => '${i.count}${i.name}').toList(),
      b.ingredients.map((i) => '${i.count}${i.name}').toList(),
    );
  });

  test('an ingredient is never repeated within one potion', () {
    for (var salt = 1; salt <= 30; salt++) {
      final names = brewPotion(salt).ingredients.map((i) => i.name).toList();
      expect(names.toSet().length, names.length, reason: 'salt $salt');
    }
  });
}
