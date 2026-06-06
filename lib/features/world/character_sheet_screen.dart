import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/world/character_sheet_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/subjects/:id/me` — the **Me** screen: a child's persistent in-world self
/// (Different World; docs/WORLD.md). The drawn avatar + the chosen name. The
/// first window onto the summer-long identity; crew, dream, world, words, and
/// age (= dailies) join it in later slices.
///
/// Reached from the subject's detail screen. Staff-facing for now (the two
/// age surfaces — soft for 4–6, full for 7–12 — come later).
class CharacterSheetScreen extends ConsumerWidget {
  const CharacterSheetScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetAsync = ref.watch(characterSheetForSubjectProvider(subjectId));
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    return EdgeScaffold(
      body: SafeArea(
        child: sheetAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            title: "Couldn't load the world self",
            detail: '$e',
          ),
          data: (sheet) => _Body(
            subjectId: subjectId,
            sheet: sheet,
            subject: subject,
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.subjectId,
    required this.sheet,
    required this.subject,
  });

  final String subjectId;
  final CharacterSheet? sheet;
  final Subject? subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firstName = subject?.firstName;
    final chosen = sheet?.chosenName;
    final hasName = chosen != null && chosen.trim().isNotEmpty;
    final displayName = hasName ? chosen.trim() : (firstName ?? '?');
    final hasDrawing = sheet?.avatarUrl != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            ContentHeader(
              title: 'World self',
              subtitle: firstName != null
                  ? "$firstName's summer identity"
                  : 'Draw and name your world self',
            ),
            const SizedBox(height: 8),
            Center(
              child: PersonAvatar(
                name: displayName,
                photoUrl: sheet?.avatarUrl,
                radius: 76,
                onTap: () => _goDraw(context, hasName ? chosen.trim() : firstName),
              ),
            ),
            const SizedBox(height: 24),
            // The chosen name (or a prompt to choose one).
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => unawaited(_editName(context, ref, chosen)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            hasName ? chosen.trim() : 'Choose a name',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: hasName
                                  ? null
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () =>
                    _goDraw(context, hasName ? chosen.trim() : firstName),
                icon: Icon(hasDrawing ? Icons.brush : Icons.brush_outlined),
                label: Text(
                  hasDrawing ? 'Redraw myself' : 'Draw myself',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (!hasDrawing) ...[
              const SizedBox(height: 16),
              Text(
                'Hand the device over and let them draw — their first picture '
                'of themselves becomes their face in the world.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _goDraw(BuildContext context, String? greetingName) {
    unawaited(context.push('/subjects/$subjectId/draw', extra: greetingName));
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    try {
      final saved = await showDialog<String?>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Choose a name'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: const InputDecoration(
                hintText: 'Your world-self name',
              ),
              onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      if (saved == null) return; // cancelled
      await ref.read(characterSheetActionsProvider).setChosenName(
            subjectId: subjectId,
            name: saved,
          );
    } finally {
      controller.dispose();
    }
  }
}
