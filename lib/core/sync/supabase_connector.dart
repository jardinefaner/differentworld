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

    try {
      for (final op in transaction.crud) {
        final table = _supabase.from(op.table);
        final patched = _decodeJsonbColumns(op.opData);
        switch (op.op) {
          case UpdateType.put:
            await table.upsert(<String, dynamic>{
              'id': op.id,
              ...?patched,
            });
          case UpdateType.patch:
            await table
                .update(patched ?? <String, dynamic>{})
                .eq('id', op.id);
          case UpdateType.delete:
            await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } on Exception {
      // Don't complete on failure — PowerSync re-queues for retry.
      // RLS-rejected rows will spin forever; we'll add a poison-pill
      // policy when we hit that in practice.
      rethrow;
    }
  }

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
      'capabilities', // spaces / members / groups / subjects / invites
      'settings', // spaces
      'details', // entries
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
