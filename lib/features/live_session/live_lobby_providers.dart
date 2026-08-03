import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/live_session/live_lobby.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The active live sessions in the current program — drives the Today
/// "a session is live — tap to join" banner (docs/LIVE_SESSIONS.md).
///
/// Realtime, not Drift: this is the documented present/control exception (the
/// lobby is ephemeral coordination, never durable data). `.autoDispose` so the
/// lobby channel is open only while something watches it (Today on screen);
/// it tears the channel down on dispose.
// Riverpod 3 provider types don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final activeSessionsProvider = StreamProvider.autoDispose<List<LiveSessionAd>>((
  ref,
) {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final memberId = viewer.memberId;
  // No space/member (guardian / not loaded) → nothing to discover.
  if (spaceId == null || memberId == null) {
    return Stream.value(const <LiveSessionAd>[]);
  }
  final watcher = LobbyWatcher.watch(
    client: ref.read(supabaseProvider),
    spaceId: spaceId,
    memberId: memberId,
  );
  ref.onDispose(() => unawaited(watcher.dispose()));
  return watcher.ads;
});
