import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/game_content/content_kinds.dart';
import 'package:differentworld/features/game_content/our_content.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/library/ours` — every kind of thing this program can write for itself,
/// with how many of each it has written (docs/CONDITIONS.md route 3).
///
/// The index is generated from [authorableKinds]; a new content kind appears
/// here the moment it has a spec.
class OurContentLibraryScreen extends ConsumerWidget {
  const OurContentLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guarded at the SCREEN, not only at the entry points — /library/ours is a
    // deep link, and a hidden button is not a gate (CLAUDE.md).
    if (ref.watch(viewerProvider) is GuardianViewer) {
      return const EdgeScaffold(
        body: NoAccess(
          title: 'This is for the team',
          message: "Activity content is written by the program's staff.",
        ),
      );
    }
    return EdgeScaffold(
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: authorableKinds.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const ContentHeader(
              title: 'Our own',
              subtitle:
                  'Everything here plays alongside what came with the app.',
            );
          }
          if (i == authorableKinds.length + 1) {
            return const _PicturesRow(key: ValueKey('ours-pictures'));
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _KindRow(spec: authorableKinds[i - 1]),
          );
        },
      ),
    );
  }
}

class _KindRow extends ConsumerWidget {
  const _KindRow({required this.spec});

  final ContentKindSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync = ref.watch(ourContentCountProvider(spec.kind));
    // A failed read must never render as a confident "none yet" — that is an
    // invitation to duplicate work the teacher can't see.
    final trailing = countAsync.when(
      loading: () => const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => Icon(
        Icons.cloud_off,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      data: (n) => Text(
        n == 0 ? 'None yet' : '$n',
        style: theme.textTheme.labelLarge?.copyWith(
          color: n == 0
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurface,
        ),
      ),
    );
    return FeatureCard(
      leading: Icon(spec.icon, color: theme.colorScheme.primary),
      title: spec.title,
      subtitle: spec.blurb,
      trailing: trailing,
      onTap: () => context.push('/library/ours/${spec.kind}'),
    );
  }
}

/// Pictures keep their own camera-shaped library — the payload is an upload,
/// not typed fields — but they belong in the same index or nobody finds them.
class _PicturesRow extends StatelessWidget {
  const _PicturesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FeatureCard(
      leading: Icon(
        Icons.photo_camera_outlined,
        color: theme.colorScheme.primary,
      ),
      title: 'Pictures',
      subtitle: 'Your own photos, played in the picture games.',
      onTap: () => context.push('/games/pictures'),
    );
  }
}
