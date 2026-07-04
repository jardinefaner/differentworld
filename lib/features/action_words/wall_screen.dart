import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/wall.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the wall's short sticky notes re-lay as
    // a dense responsive grid (2-up on a phone) over the SAME provider data;
    // off keeps the existing free-flowing Wrap.
    final bento = bentoEnabled(ref, perScreen: null);

    if (world == null) {
      return const EdgeScaffold(
        body: EmptyState(
          icon: Icons.dashboard_customize_outlined,
          title: 'The Wall opens with the journey',
          message:
              'Once this week’s world is set, the room’s Wall — its '
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
          return bento
              ? _bentoBody(context, ref, world.name, notes)
              : _flatBody(context, ref, world.name, notes);
        },
      ),
    );
  }

  /// The default layout — header + banner + a free-flowing [Wrap] of
  /// fixed-width sticky notes.
  Widget _flatBody(
    BuildContext context,
    WidgetRef ref,
    String worldName,
    List<WallNote> notes,
  ) {
    return ResponsivePage(
      children: [
        ContentHeader(
          title: 'The Wall · $worldName',
          subtitle: 'The room’s notes for this world — no names',
        ),
        const _QuestionOfTheDayBanner(),
        if (notes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: EmptyState(
              icon: Icons.sticky_note_2_outlined,
              title: 'The wall is bare',
              message:
                  'Add the first note — a Problem this world is '
                  'working on, or a Dream for it.',
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final n in notes)
                SizedBox(
                  width: 168,
                  child: _NoteCard(
                    note: n,
                    onDelete: () => _delete(context, ref, n),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// The bento variant — SAME notes, re-laid as a dense responsive grid. The
  /// header + question banner stay full-width (text-heavy); the short notes
  /// pack into a `GridView.builder` that's 2-up on a phone (≈180dp cells),
  /// more across wider screens. One room's wall is a small bounded set, so a
  /// shrink-wrapped grid (the present-hub pattern) is fine — no virtualization
  /// needed; the builder still constructs cells on demand.
  Widget _bentoBody(
    BuildContext context,
    WidgetRef ref,
    String worldName,
    List<WallNote> notes,
  ) {
    return ResponsivePage(
      children: [
        ContentHeader(
          title: 'The Wall · $worldName',
          subtitle: 'The room’s notes for this world — no names',
        ),
        const _QuestionOfTheDayBanner(),
        const SizedBox(height: 4),
        if (notes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: EmptyState(
              icon: Icons.sticky_note_2_outlined,
              title: 'The wall is bare',
              message:
                  'Add the first note — a Problem this world is '
                  'working on, or a Dream for it.',
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            primary: false,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              // Sticky notes grow with their text; a generous min keeps the
              // 2-up phone cells from clipping the body + timestamp.
              mainAxisExtent: 132,
            ),
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final n = notes[i];
              return _NoteCard(
                key: ValueKey('wall-note-${n.id}'),
                note: n,
                onDelete: () => _delete(context, ref, n),
              );
            },
          ),
      ],
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
    // `restore` re-inserts the whole row, so capture the full Entry (matched by
    // id from the same provider the screen watches) before deleting.
    Entry? entry;
    for (final e in ref.read(wallNotesProvider).value ?? const <Entry>[]) {
      if (e.id == n.id) {
        entry = e;
        break;
      }
    }
    if (entry == null) {
      await ref.read(entryActionsProvider).delete(n.id);
      return;
    }
    final row = entry;
    await deleteWithUndo(
      context,
      label: 'note',
      onDelete: () => ref.read(entryActionsProvider).delete(row.id),
      onUndo: () => ref.read(entryActionsProvider).restore(row),
    );
  }
}

/// The day's authored question from the 50-day journey, shown as the framing
/// prompt the room's notes answer today. Renders nothing when the journey
/// isn't active. Day-aware (one of the block's ten questions per day).
class _QuestionOfTheDayBanner extends ConsumerWidget {
  const _QuestionOfTheDayBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(todaysWallQuestionProvider);
    final day = ref.watch(currentProgramDayProvider);
    final block = ref.watch(currentBlockProvider);
    if (question == null || day == null || block == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final accent = block.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(
                  'TODAY’S QUESTION · DAY $day',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '“$question”',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Write it big on the wall. The notes below are the room’s answers.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _toneFor(WallNoteType t, ColorScheme s) => switch (t) {
  WallNoteType.problem => s.errorContainer,
  WallNoteType.dream => s.tertiaryContainer,
  WallNoteType.feeling => s.secondaryContainer,
  WallNoteType.free => s.surfaceContainerHighest,
};

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onDelete, super.key});
  final WallNote note;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPress: () => unawaited(onDelete()),
      child: Container(
        // Width comes from the caller — a fixed `SizedBox(168)` in the flat
        // Wrap, the grid cell in the bento variant. Height is intrinsic in the
        // Wrap; the bento grid caps it, so the body flexes + ellipsises.
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _toneFor(note.type, theme.colorScheme),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${note.type.emoji} ${note.type.label}',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                note.text,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 4,
              ),
            ),
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
                  await ref
                      .read(entryActionsProvider)
                      .createWallNote(
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
