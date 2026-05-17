import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton Supabase client. Reading this before `Supabase.initialize` has
/// been called will throw — guard the boot path in main.dart with
/// `Env.hasSupabase` so we never get here without init.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Live stream of auth state changes. We watch this from `sessionProvider`
/// so that any consumer can react to sign-in / sign-out without manually
/// re-reading the client.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

/// Current session, recomputed on every auth event.
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseProvider).auth.currentSession;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider) != null;
});

/// Auth mutations. `signOut()` cleanly tears down the PowerSync connection
/// before clearing the Supabase session so the sync engine doesn't try to
/// upload with a stale JWT in the brief window before the lifecycle
/// listener catches the auth state change.
class AuthActions {
  AuthActions(this._ref);

  final Ref _ref;

  Future<void> signOut() async {
    final db = _ref.read(powerSyncProvider).value;
    if (db != null) {
      try {
        await db.disconnect();
      } on Object {
        // Disconnect is best-effort; proceed with sign-out regardless.
      }
    }
    await _ref.read(supabaseProvider).auth.signOut();
  }
}

final authActionsProvider = Provider<AuthActions>(AuthActions.new);
