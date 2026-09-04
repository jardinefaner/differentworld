import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/activity_runtime/content_engine.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/live_session/cast_session_controller.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Put something on the room's screen.
///
/// There are two mechanisms and a staffer should never have to know which one
/// applies — the app knows, so the app decides:
///
/// 1. **A paired screen** — a second device joined by code; this phone drives
///    it. The receiver renders `gameById(...)` and NOTHING else, so this only
///    exists for routes [gameForRoute] resolves.
/// 2. **Mirroring** — open the surface on THIS device and send the device's
///    own picture out over HDMI / AirPlay / Cast. Works for every route,
///    because it is just navigation.
///
/// Three things were wrong before, all of them the same shape — the sheet
/// talked about the mechanism instead of the intent:
///
/// * **It lost what you picked.** "Use a second screen" pushed a bare `/cast`,
///   so asking for Riddle Me This on the TV dropped you in a generic lobby
///   with no memory of the riddle. Now the game rides the route and casts the
///   moment a screen is connected.
/// * **It offered a screen it could not fill.** Every card got the same two
///   options, including the 18 breaks a paired receiver cannot render. Potions
///   would connect a TV and then have no way to reach it. An option that
///   cannot work is worse than an absent one, so mirror-only activities now
///   say so plainly instead of dead-ending.
/// * **It asked again when it already knew.** With a screen already connected,
///   the answer is not a question — it is one tap.
Future<void> showCastToRoom(
  BuildContext context,
  WidgetRef ref, {
  required String mirrorRoute,

  /// What is going on the screen, for the sheet's title: "Put {this} on a
  /// screen". Naming the thing is what makes the sheet about the intent.
  String? what,
  String mirrorLabel = 'Run it here',
  String mirrorSubtitle = 'Mirror this device by cable, AirPlay, or Cast.',
}) async {
  final def = gameForRoute(mirrorRoute);
  final cast = ref.read(castSessionProvider);
  final subject = what == null ? 'this' : '“$what”';

  // Already connected: don't ask, do it. The screen is the thing that changes,
  // so the phone says what happened — a silent tap on the device you are
  // holding reads as a tap that failed.
  if (cast.active && def != null) {
    ref
        .read(castSessionProvider.notifier)
        .castGame(
          def,
          ContentEngine(ref.read(bankedContentProvider).value ?? curatedSeeds),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(castConfirmation(what, cast.peers))),
      );
    }
    return;
  }

  if (!context.mounted) return;
  return showGlassSheet<void>(
    context: context,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GlassDragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Put $subject on a screen',
                style: theme.textTheme.titleLarge,
              ),
            ),
            // A paired screen leads when it is possible: it is the better
            // outcome (the room watches the TV, the staffer keeps the phone)
            // and, once set up, every later cast is a single tap.
            if (def != null)
              ListTile(
                leading: const Icon(Icons.cast),
                title: const Text('Send it to a TV'),
                subtitle: const Text(
                  'Set the TV up once — then everything is one tap.',
                ),
                onTap: () {
                  final router = GoRouter.of(sheetCtx);
                  Navigator.of(sheetCtx).pop();
                  // Carry the intent. `/cast` casts this the moment a screen
                  // connects, so the answer to "put the riddle on the TV" is
                  // the riddle on the TV — not a lobby.
                  unawaited(router.push('/cast?cast=${def.id}'));
                },
              ),
            ListTile(
              leading: const Icon(Icons.screen_share_outlined),
              title: Text(def == null ? 'Run it here' : mirrorLabel),
              subtitle: Text(mirrorSubtitle),
              onTap: () {
                final router = GoRouter.of(sheetCtx);
                Navigator.of(sheetCtx).pop();
                unawaited(router.push(mirrorRoute));
              },
            ),
            // Say why the TV is not on offer. Without this the sheet just
            // looks thinner for some activities than others, which reads as a
            // missing feature rather than a real property of the activity.
            if (def == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Text(
                  what == null
                      ? 'This one runs on this device — a second screen '
                            "can't show it on its own."
                      : '$what runs on this device — a second screen '
                            "can't show it on its own.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// What the phone says after a one-tap cast.
///
/// A live session means a session OBJECT exists, not that a TV is watching
/// one — `peers` can be zero while the code is up and nothing has joined. The
/// first version said "X is on the screen" either way, which is the one lie
/// that costs a staffer something real: they say "everyone look at the screen"
/// and the room looks at a join code.
///
/// It stays a confirmation in both cases, because the cast DID happen — the
/// state is queued and a screen joining later receives it (the presenter
/// re-publishes on presence sync). Only the tense changes.
///
/// A pure function so the claim is testable without standing up a Realtime
/// session; the branch it guards is otherwise unreachable in a widget test.
String castConfirmation(String? what, int peers) {
  final subject = what ?? 'It';
  return peers > 0
      ? '$subject is on the screen'
      : '$subject shows as soon as a screen connects';
}
