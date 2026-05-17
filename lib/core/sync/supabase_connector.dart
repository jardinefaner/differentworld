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
      throw const _NoSessionException();
    }
    var session = initial;
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
        switch (op.op) {
          case UpdateType.put:
            await table.upsert(<String, dynamic>{
              'id': op.id,
              ...?op.opData,
            });
          case UpdateType.patch:
            await table.update(op.opData ?? <String, dynamic>{}).eq('id', op.id);
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
