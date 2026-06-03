// The poster tool remembers a teacher's last size / fit / paper / labels.
// These pin the persistence round-trip + the defensive fallbacks (a missing
// or corrupt blob must degrade to defaults, never crash).

import 'package:differentworld/features/poster/poster_models.dart';
import 'package:differentworld/features/poster/poster_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing saved → defaults', () async {
    final o = await PosterPrefs.load();
    expect(o.size, 2);
    expect(o.fitShape, isTrue);
    expect(o.fit, PosterFit.fill);
    expect(o.paper, PosterPaper.letter);
    expect(o.labels, isTrue);
  });

  test('round-trips a saved configuration', () async {
    const saved = PosterOptions(
      size: 4,
      fitShape: false,
      fit: PosterFit.whole,
      paper: PosterPaper.a4,
      quality: PosterQuality.lossless,
      labels: false,
      guides: true,
    );
    await PosterPrefs.save(saved);
    final loaded = await PosterPrefs.load();
    expect(loaded.size, 4);
    expect(loaded.fitShape, isFalse);
    expect(loaded.fit, PosterFit.whole);
    expect(loaded.paper, PosterPaper.a4);
    expect(loaded.quality, PosterQuality.lossless);
    expect(loaded.labels, isFalse);
    expect(loaded.guides, isTrue);
  });

  test('a corrupt blob falls back to defaults', () async {
    SharedPreferences.setMockInitialValues({'poster.options.v1': 'not json'});
    final o = await PosterPrefs.load();
    expect(o.size, 2);
    expect(o.fit, PosterFit.fill);
  });

  test('an out-of-range size is clamped', () async {
    SharedPreferences.setMockInitialValues({'poster.options.v1': '{"size": 99}'});
    final o = await PosterPrefs.load();
    expect(o.size, 5);
  });

  test('an unknown enum name falls back, not throws', () async {
    SharedPreferences.setMockInitialValues({
      'poster.options.v1': '{"fit": "bogus", "paper": "tabloid"}',
    });
    final o = await PosterPrefs.load();
    expect(o.fit, PosterFit.fill);
    expect(o.paper, PosterPaper.letter);
  });
}
