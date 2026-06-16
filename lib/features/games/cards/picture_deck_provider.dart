import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bundled picture-card decks (docs/CARD_GAMES.md). Each deck's
/// `manifest.json` is loaded from assets at first use; cards are offline-first
/// by construction. Add a deck = add its folder here + to `pubspec.yaml`
/// assets. PNG today; SVG decks (the line-art coloring sets) slot in once the
/// card renderer speaks SVG — the manifest already carries either path.
const _deckDirs = <String>[
  'assets/card_games/everyday',
];

/// All cards across every bundled deck. A missing / malformed manifest is
/// skipped, never fatal — a bad deck can't break game discovery.
final pictureDeckProvider = FutureProvider<List<PictureCard>>((ref) async {
  final out = <PictureCard>[];
  for (final dir in _deckDirs) {
    try {
      final json = await rootBundle.loadString('$dir/manifest.json');
      out.addAll(parseDeckManifest(json, assetDir: dir));
    } on Object {
      // skip this deck; others still load
    }
  }
  return out;
});

/// The decks exposed as a [ContentSource] of kind `picture`, layered on the
/// curated floor — so any card game's `initialState(content)` can simply call
/// `content.take(ContentKind.picture, n)` and the round-generator does the rest.
final pictureContentProvider = FutureProvider<ContentSource>((ref) async {
  final cards = await ref.watch(pictureDeckProvider.future);
  return LocalContentBank.seededWith(cards.map((c) => c.toContentItem()));
});
