import 'dart:async';

import 'package:differentworld/features/action_words/wall.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/wall` — the room's **Wall** for this week's world: anonymous sticky
/// notes for the world's Problems and Dreams (docs/WORLD.md — "sticky notes
/// on the wall"). Space-level, no names. New `wall_note` entries; no table.
class WallScreen extends ConsumerWidget {
  const WallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(currentWorldProvider);
    final notesAsync = ref.watch(wallNotesProvider);

    if (world == null) {
      return const EdgeScaffold(
        body: EmptyState(
          icon: Icons.dashboard_customize_outlined,
          title: 'The Wall opens with the journey',
          message: 'Once this week’s world is set, the room’s Wall — its '
              'Problems and Dreams — lives here.',
        ),
      );
    }

    return EdgeScaffold(
      actions: [
        PrimaryActionButton(
          tooltip: 'Add a note',
          icon: Icons.add,
          onPressed: () => _add(context, ref, world.id),
        ),
      ],
      body: notesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const EmptyState(
          icon: Icons.dashboard_customize_outlined,
          title: 'The Wall',
          message: 'Could not load the wall right now.',
        ),
        data: (entries) {
          final notes = wallNotesForWorld(entries, world.id);
          return ResponsivePage(
            children: [
              ContentHeader(
                title: 'The Wall · ${world.name}',
                subtitle: 'The room’s notes for this world — no names',
              ),
              if (notes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    title: 'The wall is bare',
                    message: 'Add the first note — a Problem this world is '
                        'working on, or a Dream for it.',
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final n in notes)
                      _NoteCard(
                        note: n,
                        onDelete: () => _delete(context, ref, n),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, String worldId) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddNoteSheet(worldId: worldId),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WallNote n) async {
    final ok = await confirmDestructive(
      context,
      title: 'Take this note off the wall?',
      message: n.text,
    );
    if (!ok || !context.mounted) return;
    await ref.read(entryActionsProvider).delete(n.id);
  }
}

Color _toneFor(WallNoteType t, ColorScheme s) => switch (t) {
      WallNoteType.problem => s.errorContainer,
      WallNoteType.dream => s.tertiaryContainer,
      WallNoteType.feeling => s.secondaryContainer,
      WallNoteType.free => s.surfaceContainerHighest,
    };

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onDelete});
  final WallNote note;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPress: () => unawaited(onDelete()),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _toneFor(note.type, theme.colorScheme),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${note.type.emoji} ${note.type.label}',
                style: theme.textTheme.labelSmall),
            const SizedBox(height: 6),
            Text(note.text, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              relativeTimeAgo(
                DateTime.tryParse(note.recordedAt)?.toLocal() ?? DateTime.now(),
              ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet({required this.worldId});
  final String worldId;

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  WallNoteType _type = WallNoteType.problem;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add to the wall', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in WallNoteType.values)
                    ChoiceChip(
                      label: Text('${t.emoji} ${t.label}'),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _type.prompt,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final text = _text.text.trim();
                  if (text.isEmpty) return;
                  final nav = Navigator.of(context);
                  await ref.read(entryActionsProvider).createWallNote(
                        text: text,
                        worldId: widget.worldId,
                        noteType: _type.name,
                      );
                  if (!mounted) return;
                  nav.pop();
                },
                child: const Text('Pin it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
