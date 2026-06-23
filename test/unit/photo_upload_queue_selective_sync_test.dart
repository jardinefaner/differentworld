// SELECTIVE PHOTO SYNC safety — the highest-risk children's-photo logic.
//
// A kid photo-turn shot is held on the device as a DEFERRED queue entry (bytes
// on disk; the attachment row's `url = 'pending:<id>'`). Two cardinal rules
// protect a child's kept photo:
//
//   (A) Only a HEARTED shot (the attachment row's `sort_order == 0`) ever
//       uploads. An un-hearted deferred entry WAITS — it is never consumed by a
//       drain (PhotoUploadQueue._deferredDisposition → wait), so a kept-but-
//       offline shot survives indefinitely until it syncs.
//   (B) The end-of-day cleanup (PhotoUploadQueue.cleanupExpiredDeferred) NEVER
//       deletes a keeper. It clears an entry ONLY when all three hold:
//       deferred==true AND createdAt.toLocal() < today's local midnight AND the
//       row is NOT a keeper (gone, or sort_order != 0).
//
// This test pins both. It mirrors the in-memory-Drift + ProviderContainer
// harness from entry_actions_db_test.dart: a real AppDatabase over
// NativeDatabase.memory() with createMigrator().createAll(), appDatabaseProvider
// overridden to resolve to it, and SharedPreferences mocked.
//
// We do NOT exercise the actual Storage upload (no Supabase): _drainOnce early-
// returns when `currentSession == null`, so processQueue can't reach the upload
// path under test. Instead we test (B) directly through cleanupExpiredDeferred,
// and assert (A)'s NEVER-LOSE half through cleanup's keeper-survival case (a
// hearted, offline, expired shot is kept). The upload-vs-wait DECISION of
// _deferredDisposition is a private method gated behind the session check; see
// the "what we couldn't reach" note in the report. The queue entries are seeded
// by writing the SharedPreferences JSON directly (the cleanest way to control
// createdAt — yesterday vs today — without depending on the wall clock), with a
// real temp file per entry so the queue's File ops resolve.

import 'dart:convert';
import 'dart:io';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/photos/photo_upload_queue.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late PhotoUploadQueue queue;
  late Directory tmpDir;
  const now = '2026-06-22T00:00:00Z';

  // The prefs key the queue persists under (PhotoUploadQueue._queueKey).
  const queueKey = 'photo_upload_queue.v1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.createMigrator().createAll();
    // A space row so seeded attachments satisfy the schema (spaceId is NOT
    // NULL); the cleanup never reads it but create() requires it.
    await db
        .into(db.spaces)
        .insert(
          SpacesCompanion.insert(
            id: 'sp1',
            name: 'Test Program',
            settings: '{}',
            capabilities: '{}',
            createdAt: now,
            updatedAt: now,
          ),
        );
    container = ProviderContainer(
      overrides: [
        // The queue reads `appDatabaseProvider.future`; resolve it to the
        // in-memory db.
        appDatabaseProvider.overrideWith((ref) async => db),
      ],
    );
    queue = container.read(photoUploadQueueProvider);
    tmpDir = await Directory.systemTemp.createTemp('dw_photo_queue_test_');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (tmpDir.existsSync()) {
      await tmpDir.delete(recursive: true);
    }
  });

  // --- helpers ------------------------------------------------------------

  /// Seed an attachment ROW with a given id + sort_order (null = un-hearted /
  /// no heart; 0 = hearted "for print"; other = un-kept ordering slot).
  Future<void> seedAttachment(String id, {int? sortOrder}) async {
    await db.attachmentsDao.create(
      id: id,
      spaceId: 'sp1',
      entityKind: 'attachment',
      entityId: id, // self-referential; the queue keys on entityId == row id
      url: 'pending:$id',
      sortOrder: sortOrder,
      capturedBySubjectId: 's1',
    );
  }

  /// Create a real temp file standing in for the entry's compressed bytes, so
  /// the queue's `File(localPath).exists()/delete()` resolve. Returns the path.
  Future<String> seedLocalFile(String id) async {
    final f = File('${tmpDir.path}/$id.jpg');
    await f.writeAsBytes(<int>[0xFF, 0xD8, 0xFF], flush: true); // JPEG magic
    return f.path;
  }

  /// Seed a QUEUE entry by writing the prefs JSON directly. This is the clean
  /// way to control `createdAt` (yesterday vs today) deterministically without
  /// leaning on the wall clock or `enqueue` (which stamps "now" and needs
  /// path_provider, unavailable in unit tests). `entityId` defaults to the same
  /// id so it points at the seeded attachment row.
  Future<void> seedQueueEntry({
    required String id,
    required DateTime createdAt,
    required bool deferred,
    required String localPath,
    String? entityId,
    String entityKind = 'attachment',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(queueKey);
    final list = <dynamic>[
      if (existing != null && existing.isNotEmpty)
        ...jsonDecode(existing) as List<dynamic>,
      <String, dynamic>{
        'id': id,
        'bucket': 'student-photos',
        'bucketPath': 'sp1/attachment/$id/x.jpg',
        'localPath': localPath,
        'entityKind': entityKind,
        'entityId': entityId ?? id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'attempts': 0,
        'deferred': deferred,
      },
    ];
    await prefs.setString(queueKey, jsonEncode(list));
  }

  /// The set of entry ids currently persisted in the queue.
  Future<Set<String>> queuedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(queueKey);
    if (raw == null || raw.isEmpty) return <String>{};
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toSet();
  }

  // Deterministic "yesterday" / "today" anchors relative to LOCAL midnight,
  // which is exactly the boundary cleanupExpiredDeferred compares against.
  DateTime localMidnightToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // An hour BEFORE local midnight today == late yesterday (strictly before the
  // boundary → "expired").
  DateTime yesterday() =>
      localMidnightToday().subtract(const Duration(hours: 1));

  // An hour AFTER local midnight today == early today (>= boundary → "kept").
  DateTime today() => localMidnightToday().add(const Duration(hours: 1));

  // --- (B) cleanupExpiredDeferred — the NEVER-DELETE-A-KEEPER cardinal rule --

  test(
    '(1) yesterday + deferred + UN-hearted (row exists) → DELETED '
    '(row gone, entry gone, file gone)',
    () async {
      const id = 'UNHEARTED';
      await seedAttachment(id, sortOrder: 5); // sort_order != 0 → not a keeper
      final path = await seedLocalFile(id);
      await seedQueueEntry(
        id: id,
        createdAt: yesterday(),
        deferred: true,
        localPath: path,
      );

      final cleared = await queue.cleanupExpiredDeferred();

      expect(cleared, 1, reason: 'the un-kept expired shot is swept');
      expect(
        await db.attachmentsDao.findById(id),
        isNull,
        reason: 'row deleted so the discard propagates via PowerSync',
      );
      expect(await queuedIds(), isNot(contains(id)), reason: 'entry dropped');
      expect(File(path).existsSync(), isFalse, reason: 'local bytes deleted');
    },
  );

  test(
    '(2) THE CRITICAL ONE — yesterday + deferred + HEARTED (sort_order==0) → '
    'KEPT (the keeper-waiting-offline case)',
    () async {
      const id = 'HEARTED';
      await seedAttachment(id, sortOrder: 0); // hearted → KEEPER
      final path = await seedLocalFile(id);
      await seedQueueEntry(
        id: id,
        createdAt: yesterday(),
        deferred: true,
        localPath: path,
      );

      final cleared = await queue.cleanupExpiredDeferred();

      expect(cleared, 0, reason: 'a keeper is NEVER cleared');
      final row = await db.attachmentsDao.findById(id);
      expect(row, isNotNull, reason: 'the kept row survives');
      expect(row!.sortOrder, 0, reason: 'still hearted');
      expect(
        await queuedIds(),
        contains(id),
        reason: 'entry still queued — it will upload once back online',
      );
      expect(File(path).existsSync(), isTrue, reason: 'local bytes preserved');
    },
  );

  test(
    '(3) TODAY + deferred + un-hearted → KEPT (the date gate — today is safe)',
    () async {
      const id = 'TODAY';
      await seedAttachment(id, sortOrder: 5);
      final path = await seedLocalFile(id);
      await seedQueueEntry(
        id: id,
        createdAt: today(),
        deferred: true,
        localPath: path,
      );

      final cleared = await queue.cleanupExpiredDeferred();

      expect(cleared, 0, reason: "today's shots are always safe");
      expect(await db.attachmentsDao.findById(id), isNotNull);
      expect(await queuedIds(), contains(id));
      expect(File(path).existsSync(), isTrue);
    },
  );

  test(
    '(4) NON-deferred entry, even old + un-hearted → KEPT (never touched)',
    () async {
      const id = 'INFLIGHT';
      // An ordinary offline upload (observation / avatar) in flight. sort_order
      // is irrelevant; deferred==false means the cleanup ignores it entirely.
      await seedAttachment(id, sortOrder: 5);
      final path = await seedLocalFile(id);
      await seedQueueEntry(
        id: id,
        createdAt: yesterday(),
        deferred: false, // <-- the gate
        localPath: path,
      );

      final cleared = await queue.cleanupExpiredDeferred();

      expect(cleared, 0, reason: 'a non-deferred entry is never considered');
      expect(
        await db.attachmentsDao.findById(id),
        isNotNull,
        reason: 'in-flight upload row untouched',
      );
      expect(await queuedIds(), contains(id), reason: 'entry survives to retry');
      expect(File(path).existsSync(), isTrue);
    },
  );

  test(
    '(5) orphan — yesterday + deferred, but the row is GONE → entry + file '
    'dropped (no row to keep, safe to clean)',
    () async {
      const id = 'ORPHAN';
      // No seedAttachment → findById returns null → "not a keeper" (orphan).
      final path = await seedLocalFile(id);
      await seedQueueEntry(
        id: id,
        createdAt: yesterday(),
        deferred: true,
        localPath: path,
      );

      final cleared = await queue.cleanupExpiredDeferred();

      expect(cleared, 1, reason: 'an orphaned expired entry is cleaned');
      expect(await queuedIds(), isNot(contains(id)), reason: 'entry dropped');
      expect(File(path).existsSync(), isFalse, reason: 'local bytes deleted');
    },
  );

  test(
    'mixed batch — one keeper survives while the un-kept siblings are swept '
    '(the cleanup is selective, not all-or-nothing)',
    () async {
      // Three expired deferred shots from yesterday: a keeper + two throwaways.
      await seedAttachment('KEEP', sortOrder: 0);
      await seedAttachment('TOSS_A', sortOrder: 3);
      await seedAttachment('TOSS_B', sortOrder: 7);
      final pKeep = await seedLocalFile('KEEP');
      final pA = await seedLocalFile('TOSS_A');
      final pB = await seedLocalFile('TOSS_B');
      await seedQueueEntry(
        id: 'KEEP',
        createdAt: yesterday(),
        deferred: true,
        localPath: pKeep,
      );
      await seedQueueEntry(
        id: 'TOSS_A',
        createdAt: yesterday(),
        deferred: true,
        localPath: pA,
      );
      await seedQueueEntry(
        id: 'TOSS_B',
        createdAt: yesterday(),
        deferred: true,
        localPath: pB,
      );

      final cleared = await queue.cleanupExpiredDeferred();

      expect(cleared, 2, reason: 'both throwaways swept, the keeper spared');
      expect(await db.attachmentsDao.findById('KEEP'), isNotNull);
      expect(await db.attachmentsDao.findById('TOSS_A'), isNull);
      expect(await db.attachmentsDao.findById('TOSS_B'), isNull);
      expect(await queuedIds(), <String>{'KEEP'});
      expect(File(pKeep).existsSync(), isTrue);
      expect(File(pA).existsSync(), isFalse);
      expect(File(pB).existsSync(), isFalse);
    },
  );

  // --- (A) the upload-gate's NEVER-LOSE half ---
  //
  // processQueue / _deferredDisposition can't be exercised here: _drainOnce
  // touches `Supabase.instance.client`, which ASSERTS (not a clean null-session
  // return) when Supabase isn't initialized — so the upload-vs-wait decision is
  // unreachable without a full Supabase test harness. See the report's
  // "couldn't reach" note. What we CAN pin deterministically through the
  // reachable surface (cleanup) is the never-lose guarantee for a kept shot
  // that hasn't synced yet: a hearted, still-deferred, not-yet-expired entry —
  // exactly a "kept the moment it was taken, offline, today" shot — is left
  // fully intact (row + bytes + queue presence). Combined with case (2) (a
  // hearted shot survives even AFTER it expires), this brackets the whole
  // keeper lifetime: a kept shot is never lost, whether it's still today's or
  // already yesterday's.

  test(
    '(A) a hearted-but-unsynced deferred shot taken TODAY is left fully intact '
    '(the keeper waiting to upload is never lost)',
    () async {
      const id = 'WAITING_KEEPER';
      await seedAttachment(id, sortOrder: 0); // hearted → keeper, still pending
      final path = await seedLocalFile(id);
      await seedQueueEntry(
        id: id,
        createdAt: today(),
        deferred: true,
        localPath: path,
      );

      // The end-of-day sweep runs (e.g. at the next boot) — it must not touch
      // this shot: it's a keeper AND it's today's.
      final cleared = await queue.cleanupExpiredDeferred();

      expect(cleared, 0, reason: 'a hearted, unexpired shot is never cleared');
      expect(
        await queuedIds(),
        contains(id),
        reason: 'still queued — it will upload once the device is online',
      );
      expect(File(path).existsSync(), isTrue, reason: 'bytes preserved');
      final row = await db.attachmentsDao.findById(id);
      expect(row, isNotNull, reason: 'the row is left intact');
      expect(row!.sortOrder, 0, reason: 'still hearted');
    },
  );

  test(
    'cleanup on an empty queue is a no-op (idempotent, returns 0)',
    () async {
      expect(await queue.cleanupExpiredDeferred(), 0);
    },
  );
}
