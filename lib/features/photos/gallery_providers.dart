import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The program-wide Photos gallery data layer (route `/photos`).
///
/// Reads are pure Drift (offline-first); the bytes render through the
/// signed-URL broker like every other photo surface. Filtering and
/// day-grouping are pure functions so the gallery's behavior is pinned
/// by unit tests without a widget in sight.

/// Which slice of sources the gallery shows. Vehicles are operational
/// paperwork, not memories — hidden unless explicitly chosen.
enum GallerySource {
  /// Every kid-moment photo (observations, work, turns) — the default.
  moments,

  /// Only photos attached to observations / work samples.
  observations,

  /// Only photo-turn shots (a kid was the photographer).
  turns,

  /// Vehicle inspection photos.
  vehicles,
}

/// The latest images across the whole space, newest first (windowed to
/// 500 in the DAO). Staff-only at the screen; RLS scopes rows to the
/// space regardless.
final StreamProvider<List<Attachment>> spacePhotosProvider =
    StreamProvider.autoDispose<List<Attachment>>((ref) async* {
      final viewer = ref.watch(viewerProvider);
      final spaceId = viewer.spaceId;
      if (spaceId == null) {
        yield const <Attachment>[];
        return;
      }
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.attachmentsDao.watchImagesInSpace(spaceId);
    });

bool _isVehicle(Attachment a) => a.entityKind == 'vehicle_log';

/// One filtered pass over the space feed. [groupId]/[subjectId] are
/// null for "all". Room membership resolves through the tagged subject
/// (`subjectsById`) — an untagged photo has no room and only shows under
/// "All rooms".
List<Attachment> filterGalleryPhotos(
  List<Attachment> all, {
  required GallerySource source,
  required Map<String, Subject> subjectsById,
  String? groupId,
  String? subjectId,
}) {
  return [
    for (final a in all)
      if (switch (source) {
        GallerySource.moments => !_isVehicle(a),
        GallerySource.observations => a.entityKind == 'entry',
        GallerySource.turns => a.capturedBySubjectId != null,
        GallerySource.vehicles => _isVehicle(a),
      })
        if (subjectId == null ||
            a.subjectId == subjectId ||
            a.capturedBySubjectId == subjectId)
          if (groupId == null ||
              subjectsById[a.subjectId]?.groupId == groupId ||
              subjectsById[a.capturedBySubjectId]?.groupId == groupId)
            a,
  ];
}

/// When the photo happened — `taken_at` when the capture stamped it,
/// else the row's creation time.
DateTime galleryPhotoTime(Attachment a) {
  final taken = a.takenAt;
  if (taken != null && taken.isNotEmpty) {
    final parsed = DateTime.tryParse(taken);
    if (parsed != null) return parsed.toLocal();
  }
  return (DateTime.tryParse(a.createdAt) ?? DateTime.now()).toLocal();
}

/// One scroll section: a local calendar day and its photos (input order
/// preserved — the feed is already newest-first).
typedef GalleryDay = ({DateTime day, List<Attachment> photos});

/// Group a newest-first feed into day sections, newest day first.
List<GalleryDay> groupGalleryByDay(List<Attachment> photos) {
  final out = <GalleryDay>[];
  for (final a in photos) {
    final t = galleryPhotoTime(a);
    final day = DateTime(t.year, t.month, t.day);
    if (out.isEmpty || out.last.day != day) {
      out.add((day: day, photos: [a]));
    } else {
      out.last.photos.add(a);
    }
  }
  return out;
}
