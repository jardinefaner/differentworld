import 'package:differentworld/features/live_session/cast_session_controller.dart';
import 'package:differentworld/features/live_session/live_session.dart'
    show LiveStatus;
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The app-wide cast affordance (docs/LIVE_SESSIONS.md — "the anchor"). Lives
/// in AppShell's top chrome on every staff route. Two faces, both reading the
/// persistent [castSessionProvider]:
///
/// - **Idle** → a quiet cast icon; tap opens the launcher (`/cast`).
/// - **Casting** → a live pill showing the **join code**, on EVERY screen, so
///   you can always read it to the room and jump back to the controls. The
///   session itself persists in the provider, so navigating away never drops
///   the cast.
///
/// Auto-hidden in immersive / kid-mode because the whole top chrome is.
class CastChromeButton extends ConsumerWidget {
  const CastChromeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(castSessionProvider);
    if (!snap.active) {
      return SecondaryActionButton(
        tooltip: 'Cast to a screen',
        icon: Icons.cast,
        onPressed: () => context.push('/cast'),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    // A wedged Realtime is otherwise INVISIBLE. The pill would keep showing
    // "Casting · CODE" in its confident primary tint while the channel was
    // dead, so a teacher reads the code to the room and nothing arrives, with
    // nothing anywhere in the app saying why. The sync-health sheet behind the
    // cloud pill covers PowerSync only; this is the whole of Realtime's
    // on-device health surface, which is why it belongs in the chrome that is
    // already on every screen.
    final failed = snap.status == LiveStatus.error;
    if (failed) {
      return Tooltip(
        message: "The screen isn't connected. Tap to retry or stop.",
        child: Material(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: () => context.push('/cast'),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 40,
              constraints: const BoxConstraints(minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cast_outlined,
                    size: 18,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Not connected',
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Tooltip(
      message: 'Casting — code ${snap.code}. Tap to control or stop.',
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => context.push('/cast'),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 40,
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cast_connected,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 7),
                Text(
                  snap.code ?? '',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
