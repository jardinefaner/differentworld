import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/game_content/content_kinds.dart';
import 'package:differentworld/features/game_content/custom_pictures.dart';
import 'package:differentworld/features/game_content/our_content.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/section_eyebrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/library/ours` — what this room has written for itself
/// (docs/CONDITIONS.md route 3).
///
/// **Leads with what exists, not with the catalogue.** The first version
/// listed all sixteen kinds flat, fifteen of them reading "None yet" — the
/// same wall of rows the drawer-slim removed, and a screen that says almost
/// nothing fifteen times. A teacher opening this wants to see their own work,
/// or, on day one, one way in. The full set lives one tap away, grouped by
/// what a teacher is trying to DO rather than by what the code calls a row.
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

    final mine = <(ContentKindSpec, int)>[
      for (final spec in authorableKinds)
        if (ref.watch(ourContentCountProvider(spec.kind)).value case final n?)
          if (n > 0) (spec, n),
    ];
    final pictures = ref.watch(customPicturesProvider).value?.length ?? 0;

    return EdgeScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const ContentHeader(
            title: 'Ours',
            subtitle: 'Played alongside what came with the app.',
          ),
          if (mine.isEmpty && pictures == 0)
            const _NothingYet()
          else ...[
            for (final (spec, n) in mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FeatureCard(
                  leading: Icon(
                    spec.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: spec.title,
                  subtitle: spec.blurb,
                  trailing: Text(
                    '$n',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  onTap: () => context.push('/library/ours/${spec.kind}'),
                ),
              ),
            if (pictures > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FeatureCard(
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: 'Pictures',
                  subtitle: 'Your own photos, played in the picture games.',
                  trailing: Text(
                    '$pictures',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  onTap: () => context.push('/games/pictures'),
                ),
              ),
            const SizedBox(height: 8),
            _WriteSomethingElse(),
          ],
        ],
      ),
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: EmptyState(
        icon: Icons.edit_note_outlined,
        title: 'Nothing of yours yet',
        message:
            'Your own questions, pairs and riddles play alongside the ones '
            'that came with the app — and a question your room wrote is '
            'usually the better one.',
        action: FilledButton.icon(
          onPressed: () => context.push('/library/ours/new'),
          icon: const Icon(Icons.add),
          label: const Text('Write something'),
        ),
      ),
    );
  }
}

class _WriteSomethingElse extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FeatureCard(
      leading: Icon(Icons.add, color: theme.colorScheme.primary),
      title: 'Write something else',
      subtitle: 'Fifteen other kinds, grouped by what they are for.',
      onTap: () => context.push('/library/ours/new'),
    );
  }
}

/// `/library/ours/new` — the full set, grouped by purpose. Only reached
/// deliberately, which is why it can afford to be a list.
class OurContentPickerScreen extends ConsumerWidget {
  const OurContentPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(viewerProvider) is GuardianViewer) {
      return const EdgeScaffold(
        body: NoAccess(
          title: 'This is for the team',
          message: "Activity content is written by the program's staff.",
        ),
      );
    }
    final theme = Theme.of(context);
    return EdgeScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const ContentHeader(title: 'What would you like to write?'),
          for (final purpose in ContentPurpose.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: SectionEyebrow(purpose.label),
            ),
            for (final spec in authorableKinds.where(
              (s) => s.purpose == purpose,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FeatureCard(
                  leading: Icon(spec.icon, color: theme.colorScheme.primary),
                  title: spec.title,
                  subtitle: spec.blurb,
                  onTap: () => context.push('/library/ours/${spec.kind}'),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FeatureCard(
              leading: Icon(
                Icons.photo_camera_outlined,
                color: theme.colorScheme.primary,
              ),
              title: 'Pictures',
              subtitle: 'Your own photos, played in the picture games.',
              onTap: () => context.push('/games/pictures'),
            ),
          ),
        ],
      ),
    );
  }
}
