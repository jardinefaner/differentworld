import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What to do with a DEFERRED (selective-sync) entry on this pass.
enum _DeferredDisposition {
  /// The attachment row is hearted (`sort_order == 0`) → upload now.
  upload,

  /// The row exists but isn't hearted yet → keep waiting (no upload, no
  /// attempt bump, file stays).
  wait,

  /// The row is gone (deleted) → drop the entry + bytes (orphan cleanup).
  orphan,
}

/// One entry in the offline photo-upload queue.
///
/// Persisted as JSON in SharedPreferences (key
/// `photo_upload_queue.v1`) plus a sidecar file on disk for the
/// compressed bytes. The metadata holds enough state to retry the
/// upload + write the resulting path back into the entity row when
/// it eventually lands.
class PendingPhotoUpload {
  PendingPhotoUpload({
    required this.id,
    required this.bucket,
    required this.bucketPath,
    required this.localPath,
    required this.entityKind,
    required this.entityId,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.deferred = false,
  });

  factory PendingPhotoUpload.fromJson(Map<String, dynamic> json) {
    return PendingPhotoUpload(
      id: json['id'] as String,
      bucket: json['bucket'] as String,
      bucketPath: json['bucketPath'] as String,
      localPath: json['localPath'] as String,
      entityKind: json['entityKind'] as String,
      entityId: json['entityId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
      // Back-compat: entries queued before selective-sync shipped have no
      // `deferred` key — they are normal offline uploads, so default false.
      deferred: json['deferred'] as bool? ?? false,
    );
  }

  final String id;
  final String bucket;
  final String bucketPath;
  final String localPath;
  final String entityKind;
  final String entityId;
  final DateTime createdAt;
  int attempts;
  String? lastError;

  /// Selective-sync hold. When true, the bytes are intentionally kept
  /// LOCAL until the teacher marks the shot "for print" (the attachment
  /// row's `sort_order == 0`). `processQueue` SKIPS a deferred entry whose
  /// row isn't hearted yet — without bumping attempts or deleting the file
  /// — so an unhearted shot waits indefinitely instead of failing. Only the
  /// kid photo-turn shots set this; observations / avatars / character
  /// sheets stay `false` and upload as soon as they're online.
  final bool deferred;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bucket': bucket,
    'bucketPath': bucketPath,
    'localPath': localPath,
    'entityKind': entityKind,
    'entityId': entityId,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
    if (lastError != null) 'lastError': lastError,
    'deferred': deferred,
  };
}

/// The offline upload queue.
///
/// Flow when `PhotoService.uploadAndPersist` runs offline:
///   1. Compressed bytes go to `<docs>/pending_uploads/<id>.jpg`
///   2. A queue entry is registered in SharedPreferences
///   3. The entity row's photo_url is set to `pending:<id>` so the
///      app + other synced devices see "photo coming" rather than
///      a 404
///   4. On app boot (and on manual retry), `processQueue()` walks
///      every entry, tries the upload, and on success:
///        - Reads bytes back from disk
///        - Uploads to Storage
///        - Updates the entity row's photo_url to the bucket path
///        - Deletes the local file + the queue entry
///   5. Failures bump `attempts` + record `lastError`. After 12
///      attempts the entry is preserved but skipped on subsequent
///      passes — surface to the user via a banner so they can
///      investigate.
///
/// Auto-retry on connectivity change is wired via
/// [startConnectivityListener] — called once from app boot. Any
/// transition from offline to online (wifi / cellular / etc.) drains
/// the queue. App-boot `processQueue()` covers the cold-start case
/// where the device was already online.
class PhotoUploadQueue {
  PhotoUploadQueue(this._ref);

  final Ref _ref;
  static const _queueKey = 'photo_upload_queue.v1';
  static const _subdir = 'pending_uploads';
  static const _maxAttempts = 12;

  bool _processing = false;

  /// Set true if [processQueue] is invoked while a drain is already running.
  /// The running drain re-runs ONCE more after it finishes (bounded — not a
  /// loop) so a shot hearted DURING a drain doesn't have to wait for the next
  /// connectivity/boot pass to upload (B4/W1).
  bool _rerunRequested = false;

  /// In-memory mirror of every pending entry's `id → localPath`, so
  /// [localPathFor] (called per-thumbnail by an autoDispose provider while a
  /// 50-shot filmstrip scrolls) doesn't re-parse SharedPreferences on every
  /// call (W4). Rebuilt from the persisted list in [_load]/[_save], added to
  /// in [enqueue], and pruned in [_deleteLocalFile] + on every upload/drop —
  /// so a cleared, uploaded, or orphaned entry leaves the cache and a stale
  /// path is never handed back. `localPathFor` still stats the File, so a
  /// cache hit pointing at a now-deleted file correctly resolves to null.
  final Map<String, String> _localPathCache = <String, String>{};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Subscribe to connectivity changes so we drain the queue as
  /// soon as the device gets back online. Called once at app boot
  /// from `lib/app/app.dart`. Idempotent — re-subscribing on a
  /// hot-reload no-ops because we keep the existing subscription.
  void startConnectivityListener() {
    if (_connectivitySub != null) return;
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) {
        // Any "online" result fires a drain. `none` is the only
        // value that means truly offline; everything else (wifi,
        // mobile, ethernet, vpn, …) means we can try.
        final hasConnection = results.any(
          (r) => r != ConnectivityResult.none,
        );
        if (!hasConnection) return;
        if (kDebugMode) {
          debugPrint(
            '[photo-queue] connectivity online ($results) — processing queue',
          );
        }
        unawaited(processQueue());
      },
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('[photo-queue] connectivity listener error: $e');
        }
      },
    );
    _ref.onDispose(() {
      unawaited(_connectivitySub?.cancel());
      _connectivitySub = null;
    });
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Persist [bytes] to disk + record the pending upload in
  /// SharedPreferences. Returns the `pending:<id>` token the
  /// caller writes into the entity row so the UI knows the bytes
  /// aren't uploaded yet.
  Future<String> enqueue({
    required String bucket,
    required String bucketPath,
    required String entityKind,
    required String entityId,
    required Uint8List bytes,
    bool deferred = false,
  }) async {
    // Native-only: the queue persists bytes to the app-docs directory,
    // which path_provider / dart:io don't provide on web. Callers
    // (PhotoService) gate with kIsWeb and surface the failure instead;
    // this guard turns a confusing path_provider crash into a clear error
    // if a future caller forgets.
    if (kIsWeb) {
      throw UnsupportedError(
        'Offline photo upload queue is native-only (no filesystem on web).',
      );
    }
    final id = bucketPath.split('/').last.replaceAll('.jpg', '');
    final dir = await _pendingDir();
    final file = File(p.join(dir.path, '$id.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    final entry = PendingPhotoUpload(
      id: id,
      bucket: bucket,
      bucketPath: bucketPath,
      localPath: file.path,
      entityKind: entityKind,
      entityId: entityId,
      createdAt: DateTime.now().toUtc(),
      deferred: deferred,
    );
    final current = await _load();
    current.add(entry);
    await _save(current);
    // Mirror into the render cache so a freshly-held shot's filmstrip thumb
    // resolves without re-reading prefs (W4). `_save` already rebuilt the
    // cache from `current`, so this is belt-and-suspenders for the just-added
    // entry.
    _localPathCache[id] = entry.localPath;
    return 'pending:$id';
  }

  /// Drop a single queued entry by its id (or `pending:<id>` token — the
  /// prefix is stripped) + delete its local bytes + prune the render cache.
  /// Used by the persist-shot rollback (B2): when the attachment row-create
  /// fails AFTER `uploadOnly` already enqueued the deferred bytes, the entry
  /// is orphaned (nothing points at it, and a re-share enqueues a fresh copy)
  /// — removing it here stops the pending_uploads dir growing until the
  /// orphan-sweep. No-op when the id isn't queued.
  Future<void> remove(String idOrToken) async {
    final id = idOrToken.startsWith('pending:')
        ? idOrToken.substring('pending:'.length)
        : idOrToken;
    final entries = await _load();
    final keep = <PendingPhotoUpload>[];
    PendingPhotoUpload? dropped;
    for (final e in entries) {
      if (e.id == id) {
        dropped = e;
      } else {
        keep.add(e);
      }
    }
    if (dropped == null) return; // Not queued — nothing to do.
    await _deleteLocalFile(dropped);
    await _save(keep);
  }

  /// Walk every pending entry; try the upload + on success update
  /// the entity row + delete the local file + drop the entry. On
  /// failure, bump attempts + record the error message; entries
  /// past [_maxAttempts] are preserved but skipped.
  ///
  /// Safe to call any time — guarded against re-entry so a
  /// concurrent retry doesn't double-process. B4/W1: if it's invoked
  /// while a drain is already running, the in-flight drain re-runs ONE
  /// more time after it finishes (bounded, not a loop), so a shot
  /// hearted mid-drain still uploads promptly instead of waiting for
  /// the next connectivity/boot pass. Returns the count from the FINAL
  /// pass.
  Future<int> processQueue() async {
    if (_processing) {
      // A drain is already in flight. Flag it to run once more when it's
      // done (covers the race where a heart's `reorder` nudges the queue
      // while the boot/connectivity drain is mid-flight) and bow out.
      _rerunRequested = true;
      return 0;
    }
    _processing = true;
    var processed = 0;
    try {
      // Bounded re-run: drain, and if a heart landed during the drain
      // (`_rerunRequested`), drain exactly once more. Each pass clears the
      // flag first, so at most one extra pass per triggering event — never
      // an unbounded loop even under a steady stream of hearts.
      do {
        _rerunRequested = false;
        processed = await _drainOnce();
      } while (_rerunRequested);
      return processed;
    } finally {
      _processing = false;
    }
  }

  /// One pass over the queue. Caller ([processQueue]) owns the [_processing]
  /// re-entry gate + the bounded re-run loop; this just does the work once.
  Future<int> _drainOnce() async {
    var processed = 0;
    final entries = await _load();
    if (entries.isEmpty) return 0;
    // Don't have a session → don't even try.
    if (_supabase.auth.currentSession == null) return 0;
    final remaining = <PendingPhotoUpload>[];
    for (final e in entries) {
      if (e.attempts >= _maxAttempts) {
        remaining.add(e);
        continue;
      }
      // Selective-sync gate: a deferred (kid photo-turn) shot only
      // uploads once it's been marked "for print" (sort_order == 0).
      // Resolve its current state against the attachment row.
      if (e.deferred) {
        final disposition = await _deferredDisposition(e);
        switch (disposition) {
          case _DeferredDisposition.wait:
            // Intentionally waiting — NOT a failure. Keep the entry +
            // the local file untouched; do NOT bump attempts. The shot
            // stays on the device until it's hearted (or the future
            // end-of-day job, slice 2, releases it).
            remaining.add(e);
            continue;
          case _DeferredDisposition.orphan:
            // The attachment row is gone (deleted). Drop the entry +
            // bytes — same as the missing-bytes branch. Nothing to
            // upload to and nothing to point at.
            await _deleteLocalFile(e);
            processed += 1;
            continue;
          case _DeferredDisposition.upload:
            // Hearted — fall through to the normal upload path below.
            break;
        }
      }
      final ok = await _tryUpload(e);
      if (ok) {
        processed += 1;
      } else {
        remaining.add(e);
      }
    }
    await _save(remaining);
    return processed;
  }

  /// Single-entry attempt. Returns true on success (and the entry
  /// should be dropped); false on retry-able failure (entry stays
  /// + attempts++ already applied).
  Future<bool> _tryUpload(PendingPhotoUpload e) async {
    final file = File(e.localPath);
    // Sync check is fine — this runs in the background queue worker
    // and the file system check is sub-millisecond. The
    // avoid_slow_async_io lint targets UI-thread hot paths.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      // Bytes are gone — nothing to upload. Drop the entry.
      if (kDebugMode) {
        debugPrint(
          '[photo-queue] local bytes missing for ${e.id}; dropping',
        );
      }
      return true;
    }
    try {
      final bytes = await file.readAsBytes();
      await _supabase.storage
          .from(e.bucket)
          .uploadBinary(
            e.bucketPath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      // Upload landed — write the bucket path into the entity row
      // (replaces the `pending:<id>` placeholder), then drop the
      // local file.
      final db = await _ref.read(appDatabaseProvider.future);
      switch (e.entityKind) {
        case 'member':
          await db.membersDao.updateAvatarUrl(e.entityId, e.bucketPath);
        case 'subject':
          await db.subjectsDao.updatePhotoUrl(e.entityId, e.bucketPath);
        case 'character_sheet':
          // Different World drawn avatar. entityId == subjectId; the sheet
          // row was created with the `pending:` token at draw time, so this
          // patches it to the real path.
          await db.characterSheetsDao.setAvatarUrlForSubject(
            e.entityId,
            e.bucketPath,
          );
        case 'attachment':
          // Attachments use the bucket path as the `url` column.
          await db.attachmentsDao.updateUrl(e.entityId, e.bucketPath);
        default:
          // Unknown entity kind — leave the entity row alone; the
          // bytes uploaded but the link is orphaned. Worth a
          // debug log so we catch the bug.
          if (kDebugMode) {
            debugPrint(
              '[photo-queue] unknown entityKind=${e.entityKind}; '
              'upload succeeded but row not updated',
            );
          }
      }
      try {
        await file.delete();
      } on Object {
        // File-delete failure is fine; the entry's gone from the
        // queue so we won't retry. Disk leak is bounded.
      }
      return true;
    } on Object catch (err) {
      e
        ..attempts += 1
        ..lastError = err.toString();
      if (kDebugMode) {
        debugPrint(
          '[photo-queue] upload failed for ${e.id} '
          '(attempt ${e.attempts}): $err',
        );
      }
      return false;
    }
  }

  /// Resolve what a deferred entry should do this pass by reading its
  /// attachment row. Only `entityKind == 'attachment'` carries a
  /// `sort_order`; any other deferred kind (none today) is treated as
  /// "upload" so we never strand bytes on an unexpected kind.
  ///
  /// NEVER-LOSE: this method only ever READS — it cannot delete bytes or
  /// drop an entry. The caller acts on the returned disposition, and the
  /// only byte-dropping path (`orphan`) fires solely when the row is
  /// confirmed absent.
  Future<_DeferredDisposition> _deferredDisposition(
    PendingPhotoUpload e,
  ) async {
    if (e.entityKind != 'attachment') return _DeferredDisposition.upload;
    final db = await _ref.read(appDatabaseProvider.future);
    final row = await db.attachmentsDao.findById(e.entityId);
    if (row == null) return _DeferredDisposition.orphan;
    // sort_order == 0 is the "for print" / favorite marker (the heart).
    return row.sortOrder == 0
        ? _DeferredDisposition.upload
        : _DeferredDisposition.wait;
  }

  /// Best-effort delete of a queue entry's local bytes. Used by the
  /// orphan path. A delete failure is fine — the entry is dropped from
  /// the queue regardless, so the disk leak is bounded + one file.
  Future<void> _deleteLocalFile(PendingPhotoUpload e) async {
    // Prune the render cache first so localPathFor stops handing back this
    // path the instant we drop the bytes (W4 correctness).
    _localPathCache.remove(e.id);
    final file = File(e.localPath);
    try {
      // Background queue worker, sub-ms FS check — not a UI hot path.
      // ignore: avoid_slow_async_io
      if (await file.exists()) await file.delete();
    } on Object {
      // Bounded disk leak; the entry is gone from the queue.
    }
  }

  /// Resolve the on-disk path for a still-pending entry's bytes, so a
  /// local render (the review grid / progress folder) can show the photo
  /// before it ever uploads. Returns null when the entry isn't found or
  /// the file is gone. Never touches the network.
  ///
  /// W4: reads the in-memory [_localPathCache] (id → localPath) instead of
  /// re-parsing SharedPreferences on every call — a 50-shot filmstrip drives
  /// 50+ calls per scroll via an autoDispose provider, and a prefs read each
  /// time is wasteful. A cleared / uploaded / orphaned entry is pruned from
  /// the cache, so a `null` miss is correct; a hit still stats the File, so a
  /// path whose bytes were deleted out from under us resolves to null too.
  Future<String?> localPathFor(String id) async {
    final cached = _localPathCache[id];
    if (cached == null) return null;
    final file = File(cached);
    // One-shot resolve inside a FutureProvider (off build()); a single
    // sub-ms existence check, not a per-frame call.
    // ignore: avoid_slow_async_io
    if (await file.exists()) return cached;
    // Bytes gone (uploaded + deleted, or swept). Drop the stale mapping so we
    // don't stat a dead path again, and report the miss.
    _localPathCache.remove(id);
    return null;
  }

  /// Read pending entries from SharedPreferences. Side effect: rebuilds the
  /// [_localPathCache] from the parsed list so the render cache stays in sync
  /// with what's persisted (W4).
  Future<List<PendingPhotoUpload>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) {
      _rebuildLocalPathCache(const []);
      return <PendingPhotoUpload>[];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final entries = list
          .map(
            (e) => PendingPhotoUpload.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      _rebuildLocalPathCache(entries);
      return entries;
    } on Object catch (e, st) {
      // Corrupt — start over rather than crash. The on-disk files
      // are orphaned but at least the app boots.
      //
      // B7: this used to recover silently, so an app-kill mid-`_save` could
      // drop every queued (held) shot with NO trace — a "my photos vanished"
      // report had nothing to go on. Emit a redacted breadcrumb: byte length
      // only, never the JSON contents (which carry storage paths) and no PII.
      // Recovery behaviour is unchanged (start empty); we just stop failing
      // silently. The original decode error is the cause.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError(
            'photo upload queue JSON corrupt (${raw.length} bytes); '
            'recovering to empty. Cause: ${e.runtimeType}',
          ),
          stack: st,
          library: 'photos',
        ),
      );
      _rebuildLocalPathCache(const []);
      return <PendingPhotoUpload>[];
    }
  }

  Future<void> _save(List<PendingPhotoUpload> entries) async {
    final prefs = await SharedPreferences.getInstance();
    // Keep the render cache authoritative with what we persist (W4).
    _rebuildLocalPathCache(entries);
    if (entries.isEmpty) {
      await prefs.remove(_queueKey);
      return;
    }
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_queueKey, raw);
  }

  /// Replace [_localPathCache] with the id → localPath mapping for [entries].
  /// Called from [_load]/[_save] so the cache exactly mirrors the persisted
  /// queue — an entry that's no longer in the list drops out, so a cleared /
  /// uploaded / orphaned shot can't strand a stale path (W4).
  void _rebuildLocalPathCache(List<PendingPhotoUpload> entries) {
    _localPathCache
      ..clear()
      ..addEntries(entries.map((e) => MapEntry(e.id, e.localPath)));
  }

  Future<Directory> _pendingDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _subdir));
    // Sync check is fine; this runs once per enqueue, off the UI
    // thread, and the directory check is sub-millisecond.
    // ignore: avoid_slow_async_io
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Watch pending count for UI surfaces (a banner when > 0).
  Future<int> pendingCount() async {
    final entries = await _load();
    return entries.length;
  }
}

final Provider<PhotoUploadQueue> photoUploadQueueProvider =
    Provider<PhotoUploadQueue>(PhotoUploadQueue.new);
