import 'package:flutter/material.dart';

/// Renders a picture card's art (docs/CARD_GAMES.md). PNG today via
/// `Image.asset`; when the line-art SVG decks land, branch on a `.svg` path to
/// `SvgPicture.asset` (flutter_svg) — the manifest already carries either path,
/// so only this one widget changes. A broken/missing asset degrades to a
/// placeholder rather than throwing mid-game.
class CardTile extends StatelessWidget {
  const CardTile({required this.image, this.fit = BoxFit.contain, super.key});

  /// Bundled asset path (e.g. `assets/card_games/everyday/04-banana.png`) or,
  /// later, a Storage URL.
  final String image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      image,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white24,
          size: 48,
        ),
      ),
    );
  }
}

/// The shared "no deck loaded" stage for the picture-deck games (Name It,
/// Odd One Out, What's Missing) — shown until the wrapper screen seeds the
/// wire-state with cards.
class DeckEmptyStage extends StatelessWidget {
  const DeckEmptyStage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No cards yet.\nAdd a deck to play.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 18),
        ),
      ),
    );
  }
}
