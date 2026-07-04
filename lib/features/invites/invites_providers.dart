import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/invites/invite_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Pending (un-accepted, un-expired) invites for a space. Driven by the
/// local Drift stream — PowerSync replicates the rows down whenever the
/// signed-in user's space matches.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final pendingInvitesProvider = StreamProvider.autoDispose
    .family<List<Invite>, String>(
      (ref, spaceId) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.invitesDao.watchPendingInSpace(spaceId);
      },
    );

/// Stable expiration presets, surfaced in the create-invite sheet.
enum InviteExpiry {
  oneDay,
  sevenDays,
  thirtyDays,
  never,
}

extension InviteExpiryX on InviteExpiry {
  String get label => switch (this) {
    InviteExpiry.oneDay => '1 day',
    InviteExpiry.sevenDays => '7 days',
    InviteExpiry.thirtyDays => '30 days',
    InviteExpiry.never => 'Never',
  };

  /// Returns the ISO-8601 timestamp to store, or null for "Never".
  String? expiresAtFromNow() {
    final now = DateTime.now().toUtc();
    return switch (this) {
      InviteExpiry.oneDay => now.add(const Duration(days: 1)).toIso8601String(),
      InviteExpiry.sevenDays =>
        now.add(const Duration(days: 7)).toIso8601String(),
      InviteExpiry.thirtyDays =>
        now.add(const Duration(days: 30)).toIso8601String(),
      InviteExpiry.never => null,
    };
  }
}

class InviteActions {
  InviteActions(this._ref);

  final Ref _ref;

  /// Creates a pending invite. Returns the created `Invite` (with a fresh
  /// code) so the caller can render the share view immediately.
  ///
  /// The local Drift write is optimistic; PowerSync uploads to Supabase
  /// in the background. The `code` is generated client-side from a
  /// secure RNG against an unambiguous alphabet — see InviteCode.
  Future<Invite> create({
    required String spaceId,
    required String role,
    required InviteExpiry expiry,
    String? email,
    String? createdBy,
    String? subjectId,
    String capabilitiesJson = '{}',
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final id = const Uuid().v4();
    final code = InviteCode.generate();
    final expiresAt = expiry.expiresAtFromNow();
    final normalizedEmail = (email == null || email.trim().isEmpty)
        ? null
        : email.trim().toLowerCase();

    await db.invitesDao.create(
      id: id,
      spaceId: spaceId,
      role: role,
      email: normalizedEmail,
      code: code,
      createdBy: createdBy,
      expiresAt: expiresAt,
      subjectId: subjectId,
      capabilitiesJson: capabilitiesJson,
    );

    return (db.select(db.invites)..where((i) => i.id.equals(id))).getSingle();
  }

  /// Convenience for the family-side invite: a director attaches a
  /// guardian to a child, then mints an invite they can text or email
  /// to the parent. Subject is required so accept_invite knows which
  /// child this guardian goes with.
  Future<Invite> createGuardianInvite({
    required String spaceId,
    required String subjectId,
    required InviteExpiry expiry,
    String? email,
    String? createdBy,
  }) {
    return create(
      spaceId: spaceId,
      role: 'guardian',
      expiry: expiry,
      email: email,
      createdBy: createdBy,
      subjectId: subjectId,
    );
  }

  Future<void> revoke(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.invitesDao.revoke(id);
  }

  /// Newcomer-side: redeem an invite. If `code` is null the backend
  /// matches by the signed-in user's auth.users.email (the magic path).
  ///
  /// Calls the Supabase RPC directly because the consumption is a
  /// server-only transaction (members.space_id update + invites.accepted_at
  /// in one shot) and a Drift-local optimistic version doesn't make
  /// sense. This is the one place outside auth where the UI talks to
  /// Supabase directly.
  ///
  /// Passes the auth user's id (`session.user.id`) as an explicit
  /// `caller_uid` param — the function falls back to `auth.uid()` only
  /// when the param is null. Reason: `auth.uid()` returns NULL in REST
  /// requests on this ES256-keyed project (see CLAUDE.md gotcha and
  /// migration 20260523000003). Without the explicit pass, guardian
  /// invites silently never linked the user_id and the next sign-in
  /// couldn't resolve them.
  Future<void> redeem({String? code}) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentSession?.user.id;
    try {
      await supabase.rpc<dynamic>(
        'accept_invite',
        params: {
          'invite_code': code,
          'caller_uid': userId,
        },
      );
    } on PostgrestException catch (e) {
      // Surface 'No matching active invite' as a clean exception the
      // UI can branch on. Any other Postgrest error bubbles up.
      if (e.message.contains('No matching active invite')) {
        throw const NoMatchingInviteException();
      }
      // Surface the real error code + message in debug builds so the
      // next failure isn't another opaque "Could not redeem that
      // invite." Logs are kDebugMode-gated per the no-PII-in-logs
      // policy — the message can carry the invite code or guardian
      // email otherwise.
      if (kDebugMode) {
        debugPrint(
          '[invites] accept_invite rpc failed: ${e.message} '
          'code=${e.code} hint=${e.hint} details=${e.details}',
        );
      }
      rethrow;
    }

    // RPC succeeded → the server changed the guardian row (linked
    // user_id) AND created the subject_guardians link AND stamped
    // the invite as accepted. None of these write through Drift, so
    // the PowerSync delta has to round-trip — and on the family path
    // it goes via the `by_guardian` stream which may not be
    // dashboard-deployed yet (Wave 41 follow-up). The Wave 45 + 46
    // PostgREST fallbacks fired exactly ONCE on initial subscription
    // and returned null/empty because the rows didn't exist at that
    // point. Without a re-fire signal the providers stay null and
    // the user is stuck on JoinOrCreate forever.
    //
    // Invalidate the resolution chain so the fallbacks run again
    // with the new server state. Order matters: guardian first
    // (viewer.isGuardian gates everything downstream), then the
    // children IDs. currentMemberProvider too in case this was a
    // staff redemption (the member's space_id just changed).
    _ref
      ..invalidate(currentMemberProvider)
      ..invalidate(currentGuardianProvider)
      ..invalidate(myChildSubjectIdsProvider);
    // viewerProvider doesn't need an explicit invalidate — it
    // recomputes from the three above via ref.watch.
  }
}

final inviteActionsProvider = Provider<InviteActions>(InviteActions.new);

/// Thrown when the backend reports no active invite for the signed-in
/// user or the provided code. The newcomer flow catches this and asks
/// for a code.
class NoMatchingInviteException implements Exception {
  const NoMatchingInviteException();

  @override
  String toString() => 'NoMatchingInviteException';
}
