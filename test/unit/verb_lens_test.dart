import 'package:differentworld/features/action_words/verbs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 12 verbs carry a lens (the personalization engine)', () {
    expect(kVerbs.length, 12);
    for (final v in kVerbs) {
      expect(v.lens, isNotEmpty, reason: '${v.id} has no lens');
      // The lens is a kid-facing "how", lowercase imperative.
      expect(v.lens.trim(), v.lens);
    }
  });

  test('lenses are distinct per verb', () {
    final lenses = kVerbs.map((v) => v.lens).toSet();
    expect(lenses.length, kVerbs.length);
  });

  test('verbById exposes the lens', () {
    expect(verbById('wait')?.lens, 'pause before each step');
    expect(verbById('play')?.lens, 'make a game of it');
  });
}
