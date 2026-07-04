import 'dart:convert';

import 'package:differentworld/features/activity_runtime/content_bank.dart';

/// One picture card from a deck (docs/CARD_GAMES.md). The [image] is a bundled
/// asset path (e.g. `assets/card_games/everyday/04-banana.png`) or a Storage
/// URL; the word lives in [label] as DATA so games can hide / show / match it.
/// Label-free art + this metadata is the deck's leverage — tag once, the
/// round-generator composes every game from it.
class PictureCard {
  const PictureCard({
    required this.id,
    required this.label,
    required this.image,
    required this.category,
    required this.deck,
  });

  factory PictureCard.fromContentItem(ContentItem i) => PictureCard(
    id: i.payload['id']! as String,
    label: i.payload['label']! as String,
    image: i.payload['image']! as String,
    category: (i.payload['category'] as String?) ?? 'thing',
    deck: (i.payload['deck'] as String?) ?? 'deck',
  );

  final String id;
  final String label;
  final String image;
  final String category;
  final String deck;

  /// First letter of the label — phonics / Beat-the-Letter. Derived, not stored.
  String get letter => label.isEmpty ? '' : label[0].toLowerCase();

  /// True for `.svg` art (line-art decks) — the caller picks the renderer
  /// (flutter_svg) vs a raster Image for `.png`.
  bool get isSvg => image.toLowerCase().endsWith('.svg');

  /// Round data rides INSIDE a game's wire-state, so the control device renders
  /// from the broadcast with no content fetch (docs/CARD_GAMES.md, the cast
  /// invariant). Embed the PATH, never bytes.
  ContentItem toContentItem() => ContentItem(
    kind: ContentKind.picture,
    fingerprint: '$deck:$id',
    payload: {
      'id': id,
      'label': label,
      'image': image,
      'category': category,
      'letter': letter,
      'deck': deck,
    },
  );
}

/// Parse a deck `manifest.json` (the slicer's output) into cards. Image paths
/// are resolved relative to [assetDir] (the deck's bundled folder). Bad/missing
/// fields degrade gracefully so a malformed card can't crash a game boot.
List<PictureCard> parseDeckManifest(
  String jsonStr, {
  required String assetDir,
}) {
  final Map<String, dynamic> m;
  try {
    m = jsonDecode(jsonStr) as Map<String, dynamic>;
  } on Object {
    return const <PictureCard>[];
  }
  final deck = (m['deck'] as String?) ?? 'deck';
  final raw = (m['cards'] as List?) ?? const <dynamic>[];
  final out = <PictureCard>[];
  for (final c in raw) {
    if (c is! Map) continue;
    final id = c['id'];
    final image = c['image'];
    if (id is! String || image is! String) continue;
    out.add(
      PictureCard(
        id: id,
        label: (c['label'] as String?) ?? id.replaceAll('-', ' '),
        image: '$assetDir/$image',
        category: (c['category'] as String?) ?? 'thing',
        deck: deck,
      ),
    );
  }
  return out;
}
