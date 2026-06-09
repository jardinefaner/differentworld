import 'dart:async';

import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The one "Cast to the room" chooser — the two ways to get a present surface
/// onto a TV / projector, offered consistently everywhere (the season hub,
/// /this-week, a child's growth arc):
///
/// 1. **Show it on this screen** → open the present surface here and
///    screen-mirror the device (HDMI / AirPlay / Chromecast tab); on web the
///    surface carries a Fullscreen button.
/// 2. **Use a second screen** → the paired-screen flow (`/cast`): the TV shows a
///    join code, this device becomes the remote.
///
/// [mirrorRoute] is the present surface to open for the "this screen" path
/// (e.g. `/journey`, `/play-today`, `/growth/:id`). [mirrorLabel] /
/// [mirrorSubtitle] let callers word it for their surface.
Future<void> showCastToRoom(
  BuildContext context, {
  required String mirrorRoute,
  String mirrorLabel = 'Show it on this screen',
  String mirrorSubtitle =
      'Open it here, then mirror to the TV by cable, AirPlay, or Cast.',
}) {
  return showGlassSheet<void>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.screen_share_outlined),
            title: Text(mirrorLabel),
            subtitle: Text(mirrorSubtitle),
            onTap: () {
              final router = GoRouter.of(sheetCtx);
              Navigator.of(sheetCtx).pop();
              unawaited(router.push(mirrorRoute));
            },
          ),
          ListTile(
            leading: const Icon(Icons.cast),
            title: const Text('Use a second screen'),
            subtitle: const Text(
              'The screen shows a code; enter it, then drive from here.',
            ),
            onTap: () {
              final router = GoRouter.of(sheetCtx);
              Navigator.of(sheetCtx).pop();
              unawaited(router.push('/cast'));
            },
          ),
        ],
      ),
    ),
  );
}
