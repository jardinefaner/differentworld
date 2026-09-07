import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/game_content/content_kinds.dart';
import 'package:differentworld/features/game_content/our_content.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:differentworld/features/speak/speak_immersive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Which content kinds each activity route plays, so the "add ours" door can
/// sit on the activity itself rather than only in a library nobody opens
/// (docs/CONDITIONS.md route 1, "authoring by playing").
///
/// One map, read by [OursStrip]. An activity that draws on two kinds lists
/// both; the strip shows the first and offers the rest behind it.
const Map<String, List<String>> activityAuthorKinds = {
  '/activity/this-or-that': [ContentKind.thisOrThat],
  '/activity/do-it': [ContentKind.doIt],
  '/activity/penny': [ContentKind.question],
  '/activity/riddles': [ContentKind.riddle],
  '/activity/fact-or-fib': [ContentKind.factOrFib],
  '/activity/story': [ContentKind.storyStarter, ContentKind.storyTwist],
  '/activity/rhyme-time': [ContentKind.rhymeWord],
  '/activity/fill-blank': [ContentKind.fillBlank],
  '/activity/letters': [ContentKind.writePrompt],
  '/activity/as-if': [ContentKind.asIf, ContentKind.line],
  '/activity/starts-with': [ContentKind.category],
  '/activity/charades': [ContentKind.charades],
  '/activity/scattergories': [ContentKind.category],
};

/// Game ids whose route doesn't match `/activity/<id>` — the same override
/// the game registry keeps, for the same reason (`LetterWordsGame.id` is
/// `letter-words` but it runs at `/activity/starts-with`).
const Map<String, String> _idRoutes = {'letter-words': '/activity/starts-with'};

/// The kinds an activity plays, or empty when it plays none. Accepts either
/// a route (`/activity/this-or-that`) or a game id (`this-or-that`) so both
/// the screen surfaces and the game scaffold can ask the same question.
List<String> authorKindsFor(String idOrRoute) {
  final direct = activityAuthorKinds[idOrRoute];
  if (direct != null) return direct;
  final mapped = _idRoutes[idOrRoute];
  if (mapped != null) return activityAuthorKinds[mapped] ?? const <String>[];
  return activityAuthorKinds['/activity/$idOrRoute'] ?? const <String>[];
}

/// A quiet line on an activity that says how much of what it plays is the
/// room's own, and offers to add more.
///
/// Deliberately act ONE, not act two: this belongs on the surface a teacher
/// reads BEFORE the block starts, never mid-play — nobody authors while
/// thirty children wait (docs/CONDITIONS.md). Keep it off live stages.
class OursStrip extends ConsumerWidget {
  const OursStrip({
    required this.route,
    this.builtInCount,
    this.compact = false,
    super.key,
  });

  /// Render as the button alone — for a `Row` that has no width to spare
  /// (the wide control bar). The count line is dropped, not shrunk.
  final bool compact;

  /// The activity's route or game id — the key into [activityAuthorKinds].
  final String route;

  /// How many items the activity ships with, when the caller knows. Shown as
  /// context ("40 ready · 2 yours") so the count means something.
  final int? builtInCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Never offer authoring on a surface the room is watching: the door leads
    // OUT of the activity. Kid mode is the locked case; the cast + speak
    // immersive flags are the projected ones. Guarded in the widget rather
    // than at each call site so a future screen can't reintroduce the hole.
    if (ref.watch(kidModeProvider) ||
        ref.watch(castImmersiveProvider) ||
        ref.watch(speakImmersiveProvider)) {
      return const SizedBox.shrink();
    }
    final kinds = authorKindsFor(route);
    if (kinds.isEmpty) return const SizedBox.shrink();
    final spec = specForKind(kinds.first);
    if (spec == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final countAsync = ref.watch(ourContentCountProvider(spec.kind));

    // A failed read renders as nothing rather than as "none yours" — the
    // strip's whole job is to be truthful about what the room has.
    final label = countAsync.when(
      loading: () => null,
      error: (_, _) => null,
      data: (n) {
        final built = builtInCount;
        if (n == 0) {
          return built == null
              ? 'None of these are yours yet'
              : '$built ready · none of them yours';
        }
        final mine = '$n ${n == 1 ? spec.one : spec.many} yours';
        return built == null ? mine : '$built ready · $mine';
      },
    );

    final button = TextButton.icon(
      onPressed: () => context.push('/library/ours/${spec.kind}'),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add ours'),
    );
    if (compact) {
      return Padding(padding: const EdgeInsets.only(left: 8), child: button);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          if (label != null)
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            const Spacer(),
          button,
        ],
      ),
    );
  }
}

/// Wraps a screen body so the "add ours" line sits at its bottom edge, above
/// the omnibox reservation. For the activities that are their OWN screen
/// rather than a `GameDefinition` — Do It, Penny, Fill in the blank, Letters —
/// which is why they were the four the game scaffold's door could not reach.
///
/// Renders nothing extra when the route has no authorable kind, so wrapping a
/// screen is always safe.
class OursFooter extends StatelessWidget {
  const OursFooter({required this.route, required this.child, super.key});

  final String route;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (authorKindsFor(route).isEmpty) return child;
    return Column(
      children: [
        Expanded(child: child),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OursStrip(route: route),
          ),
        ),
      ],
    );
  }
}
