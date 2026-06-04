import 'dart:async';

import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/live_session/live_lobby.dart';
import 'package:differentworld/features/live_session/live_lobby_providers.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The "a session is live — tap to join" banner (docs/LIVE_SESSIONS.md "One
/// place to join"). Sits at the top of Today; renders nothing unless a session
/// is live in the program. One tap joins — the game is resolved from the
/// session, so the user never picks it. Multiple live sessions → a picker.
class LiveSessionBanner extends ConsumerWidget {
  const LiveSessionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .value (not requireValue): loading / error / no-space → no banner.
    final sessions =
        ref.watch(activeSessionsProvider).value ?? const <LiveSessionAd>[];
    if (sessions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final single = sessions.length == 1 ? sessions.first : null;
    final detail = single != null
        ? '${_gameName(single)} now'
              '${single.presenter.isEmpty ? '' : ' · ${single.presenter}'}'
        : '${sessions.length} sessions running — tap to pick';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _tap(context, sessions),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  Icons.cast_connected,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A session is live',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _tap(context, sessions),
                  child: const Text('Join'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _gameName(LiveSessionAd ad) => gameById(ad.game)?.title ?? 'A game';

  void _tap(BuildContext context, List<LiveSessionAd> sessions) {
    if (sessions.length == 1) {
      _join(context, sessions.first);
    } else {
      _showPicker(context, sessions);
    }
  }

  void _join(BuildContext context, LiveSessionAd ad) {
    unawaited(
      context.push(
        '/join?code=${Uri.encodeComponent(ad.code)}'
        '&game=${Uri.encodeComponent(ad.game)}',
      ),
    );
  }

  void _showPicker(BuildContext context, List<LiveSessionAd> sessions) {
    // The sheet's onTap pops then navigates on THIS (Today) context — long-
    // lived — not the sheet's, which deactivates on pop.
    unawaited(
      showGlassSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Live sessions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              for (final ad in sessions)
                ListTile(
                  leading: const Icon(Icons.cast_connected),
                  title: Text(_gameName(ad)),
                  subtitle: ad.presenter.isEmpty ? null : Text(ad.presenter),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _join(context, ad);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
