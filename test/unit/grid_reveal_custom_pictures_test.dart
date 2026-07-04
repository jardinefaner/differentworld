// Reveal the Picture pulls the space's uploaded photos from the content bank
// (kind `picture`) into its pool, honoring the "mix in the built-in emoji"
// preference. Pure — no device, no bank wiring; a fake ContentSource stands in.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/games/grid_reveal_game.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePictureSource implements ContentSource {
  _FakePictureSource(this._pics);
  final List<ContentItem> _pics;

  @override
  List<ContentItem> take(String kind, int n) =>
      kind == ContentKind.picture ? _pics.take(n).toList() : const [];

  @override
  ContentItem? next(String kind) => null;

  @override
  int remaining(String kind) => 0;
}

ContentItem _pic(String image, String label) => ContentItem(
  kind: ContentKind.picture,
  fingerprint: image,
  payload: {'image': image, 'label': label},
);

void main() {
  const game = GridRevealGame();
  const values = {'cols': 2, 'rows': 2};

  test('a custom photo with mix OFF is the only thing that can play', () {
    final src = _FakePictureSource([
      _pic('sp1/custom_picture/p1/x.jpg', 'Dog'),
    ]);
    final s = game.initialStateFor(src, {...values, 'mixEmoji': false});
    expect(s['photo'], true);
    expect(s['pic'], 'sp1/custom_picture/p1/x.jpg');
    expect(s['lbl'], 'Dog');
  });

  test('no custom photos → an emoji plays', () {
    final s = game.initialStateFor(_FakePictureSource(const []), values);
    expect(s['photo'], false);
    expect((s['pic'] as String).isNotEmpty, isTrue);
  });

  test('a still-uploading (pending:) photo is skipped', () {
    final src = _FakePictureSource([_pic('pending:p1', 'Not ready')]);
    // mix OFF, but the only custom is pending → falls back to emoji, never
    // shows a broken pending path.
    final s = game.initialStateFor(src, {...values, 'mixEmoji': false});
    expect(s['photo'], false);
  });

  test('grid dimensions + reveal flags come from the settings', () {
    final s = game.initialStateFor(
      _FakePictureSource(const []),
      {'cols': 3, 'rows': 2},
    );
    expect(s['cols'], 3);
    expect(s['rows'], 2);
    expect(s['rev'] as List, hasLength(6));
    expect(s['d'], false);
  });
}
