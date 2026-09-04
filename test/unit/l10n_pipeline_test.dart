// The i18n pipeline, pinned.
//
// English-only shipped, so nothing here checks a translation. What it checks
// is that the PIPELINE resolves — because the failure mode of a half-wired
// l10n setup is silent: the app keeps rendering the hardcoded English it
// always did, and nobody notices the ARB is not actually reaching the widgets
// until a translator asks why their file changed nothing.

import 'dart:convert';
import 'dart:io';

import 'package:differentworld/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the generated delegate resolves English', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l10n.familyToday, 'Today');
    expect(l10n.familyShareSent, 'Sent to the teacher!');
  });

  test('placeholders interpolate rather than printing their own name', () {
    // A placeholder that is not wired shows up as the literal `{childName}`,
    // which reads as a bug to a parent and is easy to miss in review.
    return AppLocalizations.delegate.load(const Locale('en')).then((l10n) {
      final title = l10n.familyWelcomeTitle('Amara');
      expect(title, contains('Amara'));
      expect(title, isNot(contains('{')));
    });
  });

  test('the plural has all its English forms', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l10n.familyPhotoCount(0), 'No photos yet');
    expect(l10n.familyPhotoCount(1), '1 photo');
    expect(l10n.familyPhotoCount(4), '4 photos');
  });

  test('every ARB key carries a description', () {
    // A translator sees the key and the string, not the screen. Without a
    // description, "Today" could be a noun, a heading, or a button — and the
    // three take different words in most languages.
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = arb.keys.where((k) => !k.startsWith('@')).toList();
    expect(keys, isNotEmpty);

    // Not every key needs one — a bare noun reused across screens is fine —
    // but the ones carrying placeholders or plurals always do, because those
    // are the ones a translator can get structurally wrong.
    final structural = keys.where(
      (k) => (arb[k] as String).contains('{'),
    );
    for (final k in structural) {
      expect(
        arb['@$k'],
        isNotNull,
        reason:
            '"$k" interpolates or pluralises, so a translator needs to know '
            'what the placeholder IS. Add an @$k block with a description '
            'and an example.',
      );
    }
  });

  test('supportedLocales is not empty and leads with English', () {
    expect(AppLocalizations.supportedLocales, isNotEmpty);
    expect(AppLocalizations.supportedLocales.first.languageCode, 'en');
  });
}
