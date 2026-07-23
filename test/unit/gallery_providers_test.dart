// The program-wide Photos gallery's pure core: source filtering (vehicles
// hidden from moments), room resolution through the tagged kid, the
// kid filter matching both of-axes, and day grouping.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/photos/gallery_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Attachment _photo(
  String id, {
  String entityKind = 'entry',
  String? subjectId,
  String? capturedBy,
  String createdAt = '2026-07-13T20:00:00Z',
  String? takenAt,
}) {
  return Attachment(
    id: id,
    spaceId: 'space-1',
    entityKind: entityKind,
    entityId: 'e-$id',
    url: 'space-1/x/$id.jpg',
    mimeType: 'image/jpeg',
    subjectId: subjectId,
    capturedBySubjectId: capturedBy,
    createdAt: createdAt,
    updatedAt: createdAt,
    takenAt: takenAt,
  );
}

Subject _kid(String id, String groupId) => Subject(
  id: id,
  spaceId: 'space-1',
  groupId: groupId,
  firstName: 'K$id',
  lastName: 'L',
  capabilities: '{}',
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-01-01T00:00:00Z',
);

void main() {
  final kids = {
    'zoe': _kid('zoe', 'maple'),
    'mat': _kid('mat', 'cedar'),
  };

  group('filterGalleryPhotos', () {
    final photos = [
      _photo('a', subjectId: 'zoe'),
      _photo('b', subjectId: 'mat'),
      _photo('c', entityKind: 'vehicle_log'),
      _photo('d', capturedBy: 'zoe', entityKind: 'attachment'),
      _photo('e'), // untagged group moment
    ];

    test('moments hides vehicles, keeps everything else', () {
      final out = filterGalleryPhotos(
        photos,
        source: GallerySource.moments,
        subjectsById: kids,
      );
      expect(out.map((a) => a.id), ['a', 'b', 'd', 'e']);
    });

    test('room filter resolves through the tagged kid (both axes)', () {
      final out = filterGalleryPhotos(
        photos,
        source: GallerySource.moments,
        subjectsById: kids,
        groupId: 'maple',
      );
      // zoe's photo + the shot zoe took; mat (cedar) and untagged drop.
      expect(out.map((a) => a.id), ['a', 'd']);
    });

    test('kid filter matches of-kid and shot-by-kid', () {
      final out = filterGalleryPhotos(
        photos,
        source: GallerySource.moments,
        subjectsById: kids,
        subjectId: 'zoe',
      );
      expect(out.map((a) => a.id), ['a', 'd']);
    });

    test('vehicles only via the explicit source', () {
      final out = filterGalleryPhotos(
        photos,
        source: GallerySource.vehicles,
        subjectsById: kids,
      );
      expect(out.map((a) => a.id), ['c']);
    });

    test('turns = a kid was the photographer', () {
      final out = filterGalleryPhotos(
        photos,
        source: GallerySource.turns,
        subjectsById: kids,
      );
      expect(out.map((a) => a.id), ['d']);
    });
  });

  group('day grouping', () {
    test('takenAt wins over createdAt and days split correctly', () {
      final photos = [
        _photo('new', createdAt: '2026-07-14T21:00:00Z'),
        _photo('stamped', takenAt: '2026-07-12T18:30:00Z'),
        _photo('old', createdAt: '2026-07-12T15:00:00Z'),
      ];
      final days = groupGalleryByDay(photos);
      expect(days.length, 2);
      expect(days.first.photos.map((a) => a.id), ['new']);
      expect(days.last.photos.map((a) => a.id), ['stamped', 'old']);
      expect(
        galleryPhotoTime(photos[1]).day,
        galleryPhotoTime(photos[2]).day,
      );
    });
  });

  group('quilt sizing', () {
    test('span is deterministic per id and only 1 or 2', () {
      for (final id in ['a', 'bb', 'photo-123', 'zzz-9']) {
        final first = galleryTileSpan(id);
        expect(first, galleryTileSpan(id));
        expect(first == 1 || first == 2, isTrue);
      }
    });

    test('some ids go big, most stay small', () {
      final ids = [for (var i = 0; i < 200; i++) 'photo-$i'];
      final bigs = ids.where((id) => galleryTileSpan(id) == 2).length;
      expect(bigs, greaterThan(0));
      expect(bigs, lessThan(100));
    });
  });
}
