import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/entries/entry_photos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Kind discriminators for the unified `entries` table.
class EntryKind {
  static const String observation = 'observation';
  static const String meal = 'meal';
  static const String nap = 'nap';
  static const String diaper = 'diaper';
  static const String incident = 'incident';
  static const String medication = 'medication';
}

typedef GroupEntriesKey = ({String groupId, String kind});

/// Stream of entries for a classroom, filtered by kind. Used by the
/// per-classroom observations / meals / naps screens.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final entriesForGroupProvider =
    StreamProvider.autoDispose.family<List<Entry>, GroupEntriesKey>(
  (ref, key) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchEntriesForGroup(groupId: key.groupId, kind: key.kind);
  },
);

typedef SubjectEntriesKey = ({String subjectId, String? kind});

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final entriesForSubjectProvider =
    StreamProvider.autoDispose.family<List<Entry>, SubjectEntriesKey>(
  (ref, key) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchEntriesForSubject(
      subjectId: key.subjectId,
      kind: key.kind,
    );
  },
);

class EntryActions {
  EntryActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// Create an observation. Returns the new entry's id. If [id] is
  /// supplied the caller controls it (so pre-uploaded photo paths
  /// already point at the right entry); otherwise a new uuid is
  /// generated inside.
  ///
  /// Pass [photoUrls] as the full list of photos (primary first).
  /// The first URL lands in the legacy `photo_url` column for back-
  /// compat with single-photo readers; the rest go to `details.photos`.
  Future<String> createObservation({
    required String subjectId,
    required String groupId,
    required String text,
    List<String> photoUrls = const [],
    String? id,
  }) async {
    final split = SerializedPhotos.split(photoUrls);
    return _create(
      kind: EntryKind.observation,
      subjectId: subjectId,
      groupId: groupId,
      body: text,
      photoUrl: split.primary,
      detailsJson: split.detailsJson,
      id: id,
    );
  }

  Future<String> _create({
    required String kind,
    String? subjectId,
    String? groupId,
    String? body,
    String? photoUrl,
    String detailsJson = '{}',
    String? id,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final member = _ref.read(currentMemberProvider).value;
    final spaceId = member?.spaceId;
    final recordedBy = member?.id;
    if (spaceId == null || recordedBy == null) {
      throw StateError('No Space / signed-in Member.');
    }
    final useId = id ?? _uuid.v4();
    await db.createEntry(
      id: useId,
      spaceId: spaceId,
      kind: kind,
      recordedBy: recordedBy,
      subjectId: subjectId,
      groupId: groupId,
      body: body,
      photoUrl: photoUrl,
      detailsJson: detailsJson,
    );
    return useId;
  }

  /// Update an existing entry's text and photos. The full [photoUrls]
  /// list replaces whatever was on the entry; pass `[]` to clear.
  Future<void> updateText({
    required String id,
    required String text,
    List<String> photoUrls = const [],
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    // Preserve any non-photo keys that already exist in `details`
    // (kind-specific payloads on future entry types, etc.).
    final existing = await (db.select(db.entries)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    final split = SerializedPhotos.split(
      photoUrls,
      baseDetailsJson: existing?.details,
    );
    await db.updateEntry(id: id, body: text);
    await db.updateEntryPhotos(
      id: id,
      photoUrl: split.primary,
      detailsJson: split.detailsJson,
    );
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.deleteEntry(id);
  }
}

final entryActionsProvider = Provider<EntryActions>(EntryActions.new);
