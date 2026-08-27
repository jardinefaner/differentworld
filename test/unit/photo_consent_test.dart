// Consent is the one thing in this app where a wrong default is a
// compliance failure rather than a bug, so the three states get pinned
// explicitly — especially that "nobody asked" is not "no", and that a
// recorded "no" can never be overridden by a program default.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/photos/photo_consent.dart';
import 'package:differentworld/features/photos/photo_consent_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _renderGate();
  const now = '2026-08-24T08:00:00Z';

  Subject kid(String id, {bool? consent}) => Subject(
    id: id,
    spaceId: 'sp1',
    firstName: 'Kid',
    lastName: id,
    status: 'enrolled',
    capabilities: consent == null ? '{}' : '{"photo_consent":$consent}',
    createdAt: now,
    updatedAt: now,
  );

  Attachment photo(String id, {String? of, String? by}) => Attachment(
    id: id,
    spaceId: 'sp1',
    entityKind: 'entry',
    entityId: 'e1',
    url: 'attachments/$id.jpg',
    mimeType: 'image/jpeg',
    createdAt: now,
    updatedAt: now,
    subjectId: of,
    capturedBySubjectId: by,
  );

  group('recorded state', () {
    test('a missing key is unknown, not a refusal', () {
      expect(recordedConsent(kid('a')), PhotoConsent.unknown);
    });

    test('true is allowed, false is declined', () {
      expect(recordedConsent(kid('a', consent: true)), PhotoConsent.allowed);
      expect(recordedConsent(kid('a', consent: false)), PhotoConsent.declined);
    });
  });

  group('what the default may decide', () {
    test('unknown follows the program default, either way', () {
      expect(
        photosAllowedFor(kid('a'), spaceDefaultAllows: true),
        isTrue,
      );
      expect(
        photosAllowedFor(kid('a'), spaceDefaultAllows: false),
        isFalse,
      );
    });

    test('a recorded NO is never overridden by a permissive default', () {
      expect(
        photosAllowedFor(kid('a', consent: false), spaceDefaultAllows: true),
        isFalse,
        reason: 'the family answered; the program setting does not get a vote',
      );
    });

    test('a recorded YES survives a restrictive default', () {
      expect(
        photosAllowedFor(kid('a', consent: true), spaceDefaultAllows: false),
        isTrue,
      );
    });
  });

  test('awaitingConsent finds exactly the unanswered children', () {
    final roster = [
      kid('a'),
      kid('b', consent: true),
      kid('c', consent: false),
      kid('d'),
    ];
    expect(awaitingConsent(roster).map((s) => s.id), ['a', 'd']);
  });

  group('render-time filtering', () {
    final declined = kid('no', consent: false);
    final allowed = kid('yes', consent: true);
    final subjectsById = {declined.id: declined, allowed.id: allowed};

    test('a declining family’s child leaves the wall', () {
      final kept = withoutDeclinedSubjects(
        [photo('p1', of: 'no'), photo('p2', of: 'yes')],
        subjectsById: subjectsById,
        spaceDefaultAllows: true,
      );
      expect(kept.map((a) => a.id), ['p2']);
    });

    test('it also applies to who TOOK the photo', () {
      // Photo turns: a declining family's child as the photographer is
      // still their child appearing on the wall.
      final kept = withoutDeclinedSubjects(
        [photo('p1', by: 'no'), photo('p2', by: 'yes')],
        subjectsById: subjectsById,
        spaceDefaultAllows: true,
      );
      expect(kept.map((a) => a.id), ['p2']);
    });

    test('photos of nobody, and of unknown rows, are left alone', () {
      final kept = withoutDeclinedSubjects(
        [photo('p1'), photo('p2', of: 'someone-not-in-this-map')],
        subjectsById: subjectsById,
        spaceDefaultAllows: true,
      );
      expect(kept.length, 2);
    });

    test('a restrictive program default hides the unanswered too', () {
      final unknown = kid('maybe');
      final kept = withoutDeclinedSubjects(
        [photo('p1', of: 'maybe')],
        subjectsById: {unknown.id: unknown},
        spaceDefaultAllows: false,
      );
      expect(kept, isEmpty);
    });
  });
}

// `consentedPhotoUrl` is the render-side gate. It exists because consent
// covers being SHOWN, not only being photographed — and Pick Me points a
// child's face at the whole room.
void _renderGate() {
  const now = '2026-08-24T08:00:00Z';
  Subject kid(String id, {bool? consent, String? photo}) => Subject(
    id: id,
    spaceId: 'sp1',
    firstName: 'Kid',
    lastName: id,
    status: 'enrolled',
    photoUrl: photo,
    capabilities: consent == null ? '{}' : '{"photo_consent":$consent}',
    createdAt: now,
    updatedAt: now,
  );

  group('consentedPhotoUrl', () {
    test('a declining family is never shown, whatever the program default', () {
      final s = kid('a', consent: false, photo: 'sp1/subject/a/x.jpg');
      expect(consentedPhotoUrl(s, defaultAllows: true), isNull);
      expect(consentedPhotoUrl(s, defaultAllows: false), isNull);
    });

    test('an allowed family is shown even when the default is no', () {
      final s = kid('a', consent: true, photo: 'sp1/subject/a/x.jpg');
      expect(consentedPhotoUrl(s, defaultAllows: false), isNotNull);
    });

    test('unknown follows the program default, both ways', () {
      final s = kid('a', photo: 'sp1/subject/a/x.jpg');
      expect(consentedPhotoUrl(s, defaultAllows: true), isNotNull);
      expect(consentedPhotoUrl(s, defaultAllows: false), isNull);
    });

    test('no photo on file stays null rather than becoming a broken URL', () {
      expect(
        consentedPhotoUrl(kid('a', consent: true), defaultAllows: true),
        isNull,
      );
    });
  });
}
