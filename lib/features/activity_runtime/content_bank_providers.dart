import 'dart:convert';

import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The banked content snapshot an activity draws from: the curated in-app
/// floor ([curatedSeeds]) with any synced AI / crowd rows from
/// `content_items` layered on top (docs/CONTENT_BANK.md).
///
/// Exposes the merged ITEMS, not a [ContentSource] — each activity builds
/// its OWN [LocalContentBank] from this list so per-session seen-tracking
/// is independent (a shared bank instance would deplete across sessions).
///
/// KeepAlive (not autoDispose): the bank is app-wide and small, so the
/// underlying Drift watch stays warm — activities opened after the first
/// see synced content with no re-subscribe. Not a family, so there's no
/// per-key leak. Until the watch emits, callers fall back to
/// [curatedSeeds] (offline-first: play is instant; the DB tier enriches
/// transparently once it syncs).
///
/// NOTE: live multi-device activities (charades, live This-or-That)
/// intentionally do NOT read this — they need a deterministic shared order
/// across devices, which curated-only [LocalContentBank.seeded] gives them.
/// Coordinated DB-content selection for live sessions is a later design.
final bankedContentProvider = StreamProvider<List<ContentItem>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final db = await ref.watch(appDatabaseProvider.future);
  final spaceId = viewer.spaceId;
  final rows = spaceId == null
      ? db.contentBankDao.watchGlobal()
      : db.contentBankDao.watchForSpace(spaceId);
  try {
    await for (final banked in rows) {
      yield <ContentItem>[
        ...curatedSeeds,
        for (final r in banked)
          if (_decodePayload(r.payload) case final Map<String, Object?> p)
            ContentItem(kind: r.kind, fingerprint: r.fingerprint, payload: p),
      ];
    }
  } on Object {
    // If the Drift watch errors (e.g. DB torn down during a hot restart),
    // degrade to the curated offline floor instead of leaving this
    // keepAlive provider stuck in an error state. Activities keep working.
    yield curatedSeeds;
  }
});

/// Decode a banked row's JSON payload, skipping malformed rows rather than
/// crashing the whole bank. (Server/AI inserts should never be malformed,
/// but a single bad row must not take the activity down.)
Map<String, Object?>? _decodePayload(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  } on FormatException {
    return null;
  }
}
