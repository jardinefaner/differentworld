import 'dart:math';

/// One counted ingredient in a potion — `3 petals` (the count is the counting
/// math; the kids gather that many for real).
class PotionIngredient {
  const PotionIngredient(this.count, this.name, this.emoji);

  final int count;
  final String name;
  final String emoji;
}

/// A potion-of-the-moment recipe: a few counted garden ingredients, a stir
/// count, and a magical effect.
class PotionRecipe {
  const PotionRecipe({
    required this.ingredients,
    required this.stirs,
    required this.effect,
  });

  final List<PotionIngredient> ingredients;
  final int stirs;
  final String effect;
}

const List<({String name, String emoji})> _ingredients = [
  (name: 'petals', emoji: '🌸'),
  (name: 'leaves', emoji: '🍃'),
  (name: 'dewdrops', emoji: '💧'),
  (name: 'blades of grass', emoji: '🌱'),
  (name: 'smooth stones', emoji: '🪨'),
  (name: 'daisies', emoji: '🌼'),
  (name: 'acorns', emoji: '🌰'),
  (name: 'pinecones', emoji: '🌲'),
  (name: 'feathers', emoji: '🪶'),
  (name: 'clover leaves', emoji: '☘️'),
];

const List<String> _effects = [
  'makes everyone giggle',
  'helps the plants grow tall',
  'brings happy dreams',
  'gives you super listening ears',
  'makes you brave',
  'fills the room with calm',
  'grows a little more kindness',
  'makes the day sparkle',
  'turns frowns upside down',
  'gives you a burst of good ideas',
];

/// Brews a **potion of the moment** (docs/VISION.md 2026-06-19): 2–3 garden
/// ingredients with small counts (the counting), a stir count, and a magical
/// effect. Deterministic by [salt] — the "brew another" button bumps it, so
/// the same salt always yields the same potion. Pure + testable.
PotionRecipe brewPotion(int salt) {
  final r = Random(salt);
  final pool = List.of(_ingredients)..shuffle(r);
  final n = 2 + r.nextInt(2); // 2 or 3 ingredients
  final ingredients = <PotionIngredient>[
    for (var i = 0; i < n; i++)
      PotionIngredient(1 + r.nextInt(5), pool[i].name, pool[i].emoji),
  ];
  final stirs = 3 + r.nextInt(5); // 3..7
  final effect = _effects[r.nextInt(_effects.length)];
  return PotionRecipe(ingredients: ingredients, stirs: stirs, effect: effect);
}
