import 'package:differentworld/features/action_words/summer_book.dart'
    show scrubOtherNames;
import 'package:differentworld/features/exports/exports_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/keepsake_pdf.dart';
import 'package:differentworld/features/photos/person_photo_url.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart' show networkImage;

/// The work of turning a child's FAVORITE photos into the keepsake PDF and
/// handing the bytes to the export pipeline. The renderer
/// (`keepsake_pdf.dart`) is complete; this is the data-assembly that feeds it
/// and the hand-off to `ExportActions.createAndStore` (the same durable
/// audit-row + Storage-upload path the progress report uses), so a keepsake
/// becomes a permanent record the director can later send home.
///
/// STAFF-side, network-allowed: building the PDF needs the photo BYTES, which
/// live in Supabase Storage (the synced row only carries a path — see the
/// "Binary media never goes through PowerSync" rule). So unlike the folder's
/// reads, this is an explicit "I'm online and want to generate" action; the
/// screen surfaces an offline-aware error if a fetch fails.

/// How many took-photos to include when NONE are hearted — a sensible keepsake
/// length so the fallback ("just give me their best") doesn't balloon into a
/// hundred-page contact sheet. Favorites (when present) are never capped.
const int _unheartedCap = 12;

/// What a finished keepsake build hands back so the screen can confirm + offer
/// to open it. [bytes] are kept so "View" can preview/share the exact file
/// without a Storage round-trip.
@immutable
class KeepsakeResult {
  const KeepsakeResult({
    required this.exportId,
    required this.bytes,
    required this.firstName,
    required this.photoCount,
  });

  final String exportId;
  final Uint8List bytes;
  final String firstName;
  final int photoCount;
}

/// Thrown when there are no usable photos to build from — distinct from a
/// failure so the screen can nudge ("Add some photos first / heart your
/// favorites") instead of showing an error frame.
class KeepsakeNoPhotosException implements Exception {
  const KeepsakeNoPhotosException();
}

class KeepsakeActions {
  KeepsakeActions(this._ref);

  final Ref _ref;

  /// Gather the child's favorite took-photos (or the capped took-photos when
  /// none are hearted), fetch each into a print image, scrub any OTHER child's
  /// name out of the captions, render the keepsake PDF, and store it as an
  /// export. Returns the result so the caller can surface + open it.
  ///
  /// Throws [KeepsakeNoPhotosException] when nothing usable is found; lets
  /// other exceptions (network / Storage / RLS) propagate so the caller can
  /// show an offline-aware error.
  Future<KeepsakeResult> buildAndStore(String subjectId) async {
    final subject = await _ref.read(subjectByIdProvider(subjectId).future);
    final firstName = (subject?.firstName ?? '').trim();

    // FAVORITES first: the hearted took-photos (sort_order == 0). If the child
    // has none hearted, fall back to their took-photos capped at a sensible
    // keepsake length — "their best" defaults to "the recent ones".
    final took = await _ref.read(
      attachmentsCapturedByCuratedProvider(subjectId).future,
    );
    final favorites = took.where((a) => (a.sortOrder ?? 1) == 0).toList();
    final chosen = favorites.isNotEmpty
        ? favorites
        : took.take(_unheartedCap).toList();

    // Skip any offline-unuploaded photo — its bytes aren't in Storage yet, so
    // it can't render (it would be a blank cell). `pending:<local-path>` is the
    // sentinel a queued upload writes into the row's url.
    final uploadable = chosen
        .where((a) => !a.url.startsWith('pending:'))
        .toList();
    if (uploadable.isEmpty) {
      throw const KeepsakeNoPhotosException();
    }

    // The other-child-name scrub set: every enrolled child's first/last name
    // EXCEPT this child's own (their own name stays — it's their keepsake).
    // Mirrors the Summer Book export path exactly.
    final roster = await _ref.read(subjectsInSpaceProvider.future);
    final otherNames = <String>{};
    for (final s in roster) {
      if (s.id == subjectId) continue;
      if (s.firstName.trim().isNotEmpty) otherNames.add(s.firstName);
      if (s.lastName.trim().isNotEmpty) otherNames.add(s.lastName);
    }

    // Fetch each photo's bytes into a print image. Per-photo try/catch so one
    // failed fetch (a 404 / expired path / transient blip) drops just that
    // photo instead of sinking the whole keepsake — the same resilience the
    // role-deck print uses. No PII in the debug line (path/name excluded).
    final photos = <KeepsakePhoto>[];
    for (final a in uploadable) {
      try {
        final signed = await _ref.read(
          signedPersonPhotoUrlProvider(a.url).future,
        );
        if (signed == null || signed.isEmpty) continue;
        final image = await networkImage(signed);
        final caption = (a.caption ?? '').trim();
        photos.add(
          KeepsakePhoto(
            image: image,
            takenAt: keepsakeDateLabel(DateTime.tryParse(a.takenAt ?? '')),
            caption: caption.isEmpty
                ? null
                : scrubOtherNames(caption, otherNames),
          ),
        );
      } on Object catch (e) {
        if (kDebugMode) debugPrint('[keepsake] photo fetch failed: $e');
      }
    }

    // Every chosen photo failed to fetch — treat as "couldn't build" (a real
    // failure, network-shaped), not "no photos". An exception lets the caller's
    // offline-aware error copy fire.
    if (photos.isEmpty) {
      throw const KeepsakeFetchFailedException();
    }

    final generatedAt = DateTime.now();
    final bytes = await renderKeepsakeBytes(
      KeepsakeData(
        firstName: firstName,
        photos: photos,
        generatedAt: generatedAt,
      ),
    );

    // Hand the bytes to the REAL export-store method — creates the audit row,
    // uploads to the `exports` bucket, stamps the path. Author = the signed-in
    // member (read inside createAndStore via viewer.memberId); subject = this
    // child; status stays 'draft' until a later send. The "{Name} · keepsake"
    // title lives in the PDF doc itself + here in the snapshot for the record.
    final actions = _ref.read(exportActionsProvider);
    final exportId = await actions.createAndStore(
      templateId: 'keepsake',
      templateVersion: 'v1',
      format: 'pdf',
      bytes: bytes,
      snapshot: {
        'subjectId': subjectId,
        'title': '${firstName.isEmpty ? 'A child' : firstName} · keepsake',
        'photoCount': photos.length,
        'fromFavorites': favorites.isNotEmpty,
        'generatedAt': generatedAt.toIso8601String(),
      },
      subjectId: subjectId,
      groupId: subject?.groupId,
    );

    return KeepsakeResult(
      exportId: exportId,
      bytes: bytes,
      firstName: firstName.isEmpty ? 'This child' : firstName,
      photoCount: photos.length,
    );
  }
}

/// Thrown when every selected photo failed to fetch its bytes — a build
/// failure (usually offline / Storage), so the caller shows a retry-on-a-
/// connection message rather than the "no photos" nudge.
class KeepsakeFetchFailedException implements Exception {
  const KeepsakeFetchFailedException();
}

final keepsakeActionsProvider = Provider<KeepsakeActions>(KeepsakeActions.new);
