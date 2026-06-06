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
    );
    final current = await _load();
    current.add(entry);
    await _save(current);
    return 'pending:$id';
  }

  /// Walk every pending entry; try the upload + on success update
  /// the entity row + delete the local file + drop the entry. On
  /// failure, bump attempts + record the error message; entries
  /// past [_maxAttempts] are preserved but skipped.
  ///
  /// Safe to call any time — guarded against re-entry so a
  /// concurrent retry doesn't double-process.
  Future<int> processQueue() async {
    if (_processing) return 0;
    _processing = true;
    var processed = 0;
    try {
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
        final ok = await _tryUpload(e);
        if (ok) {
          processed += 1;
        } else {
          remaining.add(e);
        }
      }
      await _save(remaining);
      return processed;
    } finally {
      _processing = false;
    }
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
      await _supabase.storage.from(e.bucket).uploadBinary(
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
          await db.characterSheetsDao
              .setAvatarUrlForSubject(e.entityId, e.bucketPath);
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

  /// Read pending entries from SharedPreferences.
  Future<List<PendingPhotoUpload>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return <PendingPhotoUpload>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => PendingPhotoUpload.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on Object {
      // Corrupt — start over rather than crash. The on-disk files
      // are orphaned but at least the app boots.
      return <PendingPhotoUpload>[];
    }
  }

  Future<void> _save(List<PendingPhotoUpload> entries) async {
    final prefs = await SharedPreferences.getInstance();
    if (entries.isEmpty) {
      await prefs.remove(_queueKey);
      return;
    }
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_queueKey, raw);
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
