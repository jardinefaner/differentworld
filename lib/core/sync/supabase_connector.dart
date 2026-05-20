import 'dart:convert';

import 'package:differentworld/core/env/env.dart';
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bridges PowerSync ↔ Supabase.
///
/// - `fetchCredentials` hands PowerSync the Supabase JWT, which the PowerSync
///   service validates against the JWT secret configured in its dashboard.
/// - `uploadData` applies the local CRUD queue to Supabase. **It must guard
///   against a null session** — otherwise `supabase_flutter` falls back to
///   the anon key, PostgREST runs the request as the `anon` role, and every
///   RLS policy that checks `auth.uid() is not null` rejects the row.
///   Symptom: `new row violates row-level security policy` in a retry loop.
class SupabaseConnector extends PowerSyncBackendConnector {
  SupabaseConnector(this.db);

  final PowerSyncDatabase db;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final auth = _supabase.auth;
    final initial = auth.currentSession;
    if (initial == null) return null;
    var session = initial;

    // Proactively refresh if the access token is within 60 seconds of
    // expiry. Otherwise PowerSync may hand the service an expired JWT
    // and we lose ~1 sync cycle to retries.
    if (_isExpiringSoon(session)) {
      try {
        final refreshed = await auth.refreshSession();
        final newSession = refreshed.session;
        if (newSession != null) session = newSession;
      } on AuthException {
        // Refresh failed (e.g. revoked refresh token). PowerSync will
        // retry; on persistent failure the user needs to sign in again.
      }
    }

    return PowerSyncCredentials(
      endpoint: Env.powerSyncUrl,
      token: session.accessToken,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    // Guard against running with no session. Without this, the REST
    // client falls back to the anon key and every INSERT/UPDATE/DELETE
    // is rejected by RLS — silently for the user, an infinite retry
    // loop in the logs.
    final auth = _supabase.auth;
    final initial = auth.currentSession;
    if (initial == null) {
      // Don't complete; PowerSync will retry on the next cycle (after
      // sign-in restores the session).
      debugPrint('[connector] uploadData: NO SESSION; throwing.');
      throw const _NoSessionException();
    }
    var session = initial;

    // Diagnostic — debug builds only. Token material (even a prefix)
    // never goes to release logs.
    if (kDebugMode) {
      final tokenPrefix = session.accessToken.length >= 16
          ? '${session.accessToken.substring(0, 16)}…'
          : session.accessToken;
      debugPrint(
        '[connector] uploadData: session.user=${session.user.id} '
        'token=$tokenPrefix '
        'expiresAtEpoch=${session.expiresAt} '
        'ops=${transaction.crud.length}',
      );
    }
    if (_isExpiringSoon(session)) {
      try {
        final refreshed = await auth.refreshSession();
        final newSession = refreshed.session;
        if (newSession != null) session = newSession;
      } on AuthException catch (e, st) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: st,
            library: 'powersync',
            context: ErrorDescription(
              'Refreshing Supabase session before CRUD upload',
            ),
          ),
        );
        rethrow;
      }
    }

    for (final op in transaction.crud) {
      final table = _supabase.from(op.table);
      final patched = _decodeJsonbColumns(op.opData);
      try {
        switch (op.op) {
          case UpdateType.put:
            final payload = <String, dynamic>{'id': op.id, ...?patched};
            final naturalKey = _naturalKeyByTable[op.table];
            if (naturalKey != null) {
              // Multi-device offline-first writes can collide on a
              // non-PK UNIQUE constraint. Each device generates its own
              // local uuid for what's logically the same row (e.g. the
              // same kid + same survey template). Without onConflict
              // the second device hits 23505 and PowerSync retries
              // forever, blocking every later op in the queue. With
              // it, PostgREST merges by the natural key. The id may
              // "drift" once when devices first reconcile — that's the
              // accepted cost; the row stays consistent thereafter.
              await table.upsert(payload, onConflict: naturalKey);
            } else {
              await table.upsert(payload);
            }
          case UpdateType.patch:
            await table
                .update(patched ?? <String, dynamic>{})
                .eq('id', op.id);
          case UpdateType.delete:
            await table.delete().eq('id', op.id);
        }
      } catch (e, st) {
        // Surface the per-op context (table + op type + id) so the
        // logcat tail shows WHICH row PostgREST rejected. Without
        // this, PowerSync's generic exception log doesn't tell us
        // whether it was spaces, members, or something downstream.
        //
        // Debug-only — in production this same information reaches
        // the crash reporter via FlutterError.reportError below.
        if (kDebugMode) {
          debugPrint(
            '[connector] upload FAILED · op=${op.op.name} '
            'table=${op.table} id=${op.id} · $e',
          );
        }
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: st,
            library: 'powersync',
            context: ErrorDescription(
              'Uploading ${op.op.name} on ${op.table}/${op.id}',
            ),
          ),
        );
        rethrow;
      }
    }
    await transaction.complete();
  }

  /// Tables where the server enforces uniqueness on something other
  /// than the PK. PowerSync's CRUD queue uploads each device's local
  /// `id`, but the constraint is on the natural key — so we tell
  /// PostgREST to resolve a conflict on that key instead of failing
  /// the INSERT.
  ///
  /// Keep in sync with the `create unique index ... on public.<table>
  /// (...)` declarations in `supabase/migrations/`. Anything LOW-risk
  /// for cross-device collision (most join tables) can be left out;
  /// the worst case is a single retry-and-recover, not an infinite
  /// loop, because join-table writes are typically single-origin.
  static const Map<String, String> _naturalKeyByTable = {
    'survey_responses': 'subject_id,template_id',
    'dismissed_insights': 'member_id,insight_id',
    'member_certifications': 'member_id,cert_key',
    'attendance_records': 'subject_id,date',
  };

  /// PowerSync's local schema stores jsonb columns as TEXT (the raw JSON
  /// string). PostgREST expects an actual JSON value for jsonb columns —
  /// if we pass the string verbatim it lands as a *jsonb string literal*,
  /// not a jsonb object. The next sync round-trip then returns that
  /// stringified blob, parsed once it's a plain `String` instead of a
  /// `Map`, and every reader falls back to empty caps. So: detect known
  /// jsonb columns and `jsonDecode` them before they leave the device.
  ///
  /// Columns enumerated per `supabase/migrations/` — keep this in sync
  /// when adding jsonb columns. Better fragile than silently wrong.
  Map<String, dynamic>? _decodeJsonbColumns(Map<String, dynamic>? opData) {
    if (opData == null) return null;
    const jsonbColumns = <String>{
      'capabilities', // spaces / members / groups / subjects / invites / vehicles / activities
      'settings', // spaces
      'details', // entries
      'answers', // survey_responses — missing this caused every survey
      //           response to round-trip as a stringified JSON literal,
      //           so SurveyAnswers.fromJson saw a String not a Map and
      //           the table view rendered "—" for every cell.
      'items', // vehicle_logs (checklist payload)
      'snapshot_json', // exports (the rendered-data snapshot)
      'manifest', // trip_vehicles (array of subject ids on this vehicle)
    };
    Map<String, dynamic>? next;
    for (final entry in opData.entries) {
      if (!jsonbColumns.contains(entry.key)) continue;
      final raw = entry.value;
      if (raw is! String) continue; // already a Map/List, nothing to do
      try {
        final decoded = jsonDecode(raw);
        next ??= Map<String, dynamic>.from(opData);
        next[entry.key] = decoded;
      } on FormatException {
        // Not JSON — leave it alone; server can reject if invalid.
      }
    }
    return next ?? opData;
  }

  static bool _isExpiringSoon(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt - nowSeconds < 60;
  }
}

class _NoSessionException implements Exception {
  const _NoSessionException();
  @override
  String toString() => 'No Supabase session; refusing to upload as anon.';
}
