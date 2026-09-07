import 'dart:convert';

import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One item this program wrote for itself — a row in `content_items` with
/// `space_id` set and `source = 'staff'`, which the activity banks read
/// alongside the curated seeds with no game-side code
/// (docs/CONDITIONS.md).
@immutable
class OurContentItem {
  const OurContentItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.createdBy,
  });

  final String id;
  final String kind;
  final Map<String, Object?> payload;
  final String createdAt;
  final String? createdBy;
}

/// This space's own items of one `kind`, newest first. Empty (never an error)
/// for a viewer with no space — a guardian has nothing to author.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final ourContentProvider = StreamProvider.autoDispose
    .family<List<OurContentItem>, String>((
      ref,
      kind,
    ) async* {
      final spaceId = ref.watch(viewerProvider).spaceId;
      if (spaceId == null) {
        yield const <OurContentItem>[];
        return;
      }
      final db = await ref.watch(appDatabaseProvider.future);
      await for (final rows in db.contentBankDao.watchOwnByKind(
        spaceId,
        kind,
      )) {
        yield [
          for (final r in rows)
            if (decodeContentPayload(r.payload)
                case final Map<String, Object?> p)
              OurContentItem(
                id: r.id,
                kind: r.kind,
                payload: p,
                createdAt: r.createdAt,
                createdBy: r.createdBy,
              ),
        ];
      }
    });

/// How many of one `kind` this space has written — the number the library index
/// and the in-activity strip both read. `AsyncValue` so a FAILED read is
/// never drawn as a confident zero (the `.value ?? const []` trap).
///
/// A row whose payload won't decode is dropped upstream and so isn't counted.
/// That is deliberate, not an oversight: this number answers "how many of
/// these can the room play", and a row the bank can't parse doesn't play.
/// Don't "fix" it by counting raw rows — that would promise content that
/// never appears.
// ignore: specify_nonobvious_property_types
final ourContentCountProvider = Provider.autoDispose
    .family<AsyncValue<int>, String>((
      ref,
      kind,
    ) {
      return ref
          .watch(ourContentProvider(kind))
          .whenData((items) => items.length);
    });

Map<String, Object?>? decodeContentPayload(String raw) {
  try {
    final d = jsonDecode(raw);
    return d is Map ? Map<String, Object?>.from(d) : null;
  } on FormatException {
    return null;
  }
}

final ourContentActionsProvider = Provider<OurContentActions>(
  OurContentActions.new,
);

/// Create / edit / remove / restore, for any `ContentKindSpec`. One set of
/// verbs for every kind — a new kind inherits CRUD by existing in
/// `authorableKinds`.
class OurContentActions {
  OurContentActions(this._ref);
  final Ref _ref;

  /// Write a new item. Returns its id so a caller can undo a create.
  Future<String> create({
    required String kind,
    required Map<String, Object?> payload,
    String? id,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      throw StateError('Join a program before writing your own content.');
    }
    final db = await _ref.read(appDatabaseProvider.future);
    return db.contentBankDao.createStaffItem(
      id: id,
      spaceId: spaceId,
      kind: kind,
      payload: jsonEncode(payload),
      createdBy: viewer.memberId,
    );
  }

  /// Replace an item's payload. Kind / space / author are fixed at creation.
  Future<void> update(String id, Map<String, Object?> payload) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.contentBankDao.updatePayload(id, jsonEncode(payload));
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.contentBankDao.deleteById(id);
  }

  /// Undo a delete — the SAME id, so the row re-syncs as itself rather than
  /// arriving on other devices as a duplicate.
  Future<void> restore(OurContentItem item) async {
    final spaceId = _ref.read(viewerProvider).spaceId;
    if (spaceId == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.contentBankDao.createStaffItem(
      id: item.id,
      spaceId: spaceId,
      kind: item.kind,
      payload: jsonEncode(item.payload),
      createdBy: item.createdBy,
    );
  }
}
