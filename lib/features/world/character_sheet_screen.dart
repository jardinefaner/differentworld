import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/mood.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/week_log.dart';
import 'package:differentworld/features/action_words/widgets/thinking_game_sheet.dart';
import 'package:differentworld/features/action_words/world_arc.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/entities/linkified_text.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/world/character_sheet_providers.dart';
import 'package:differentworld/features/world/crews.dart';
import 'package:differentworld/features/world/skill_measure.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/cap_picker_sheet.dart';
import 'package:differentworld/shared/widgets/collapsible_section.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/scale_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// The section widgets composed by _Body live in this part (split for size);
// they share this library's imports and stay private.
part 'character_sheet_sections.dart';

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
          loading: () => const LoadingSlot(variant: LoadingVariant.spinner),
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

    // The rest of the sheet, assembled from data that already exists.
    final collection = ref
        .watch(actionWordsCollectionProvider(subjectId))
        .value;
    final entries =
        ref
            .watch(
              entriesForSubjectProvider(
                (subjectId: subjectId, kind: null),
              ),
            )
            .value ??
        const <Entry>[];
    final week = ref.watch(currentCurriculumWeekProvider);
    final world = ref.watch(currentWorldProvider);
    final start = ref.watch(programStartDateProvider);
    final worlds = ref.watch(curriculumWorldsProvider).value ?? const [];
    final ageDays = _participationDays(entries);
    final visitedWeeks = _visitedWeeks(entries, start);
    final practiced = collection?.verbTotals ?? const <String, int>{};
    final title = collection?.emergingTitle;

    // designed-empty: a brand-new kid's sheet IS the designed zero state —
    // avatar placeholder + "Choose a name" + the draw prompt invite the
    // first action; there is no blank page to guard.
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
                onTap: () =>
                    _goDraw(context, hasName ? chosen.trim() : firstName),
              ),
            ),
            const SizedBox(height: 24),
            // The chosen name (or a prompt to choose one). Intentionally an
            // inline tap-to-edit affordance (not a FeatureCard row) — it's a
            // centred headline, not a list item; the InkWell gives it a 48 dp
            // ripple target.
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
                              fontWeight: FontWeight.w700,
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
            // TITLE — emerges from verb patterns ("The Owl Who Listens").
            if (title != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
            // CREW — the one CHOSEN element of the identity (the title above
            // is EARNED). A closed catalog; tap to pick.
            _Crew(subject: subject, subjectId: subjectId),
            const SizedBox(height: 14),
            // AGE · SEASON · MAP.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _Chip(icon: Icons.cake_outlined, label: 'Day $ageDays'),
                if (week != null)
                  _Chip(
                    icon: Icons.calendar_today_outlined,
                    label: 'Week $week',
                  ),
                if (world != null) _Chip(emoji: world.emoji, label: world.name),
              ],
            ),
            const SizedBox(height: 24),
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
                    fontWeight: FontWeight.w700,
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
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),
            _Weather(subjectId: subjectId),
            const SizedBox(height: 22),
            const _WorldStage(),
            // The data sections (abilities → links) folded behind one
            // disclosure so the sheet leads with the identity hero + the live
            // RPG stage, not ~9 stacked sections (character_sheet was the
            // app's least-intuitive screen, 9/5 — docs/CLARITY_RUBRIC.md).
            // The reward detail is one tap away.
            const SizedBox(height: 8),
            CollapsibleSection(
              title: 'The full sheet',
              icon: Icons.auto_awesome_outlined,
              collapsedSummary: 'abilities · skills · spells · quests',
              initiallyExpanded: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    label: 'Abilities · the 12 verbs',
                    systemId: 'abilities',
                    child: _Verbs(practiced: practiced),
                  ),
                  const SizedBox(height: 22),
                  // Skills — the RPG "stats that grow". The one synthesis piece
                  // with new data: the line going up is the proof a brain grew.
                  _Skills(
                    entries: entries,
                    subjectId: subjectId,
                    firstName: firstName ?? 'this child',
                    groupId: subject?.groupId,
                  ),
                  const SizedBox(height: 22),
                  // Spells — the kid's earned vocabulary, from weekly logs.
                  _Spells(entries: entries),
                  const SizedBox(height: 22),
                  _Section(
                    label: 'Collection · worlds visited',
                    systemId: 'collection',
                    child: _Worlds(worlds: worlds, visited: visitedWeeks),
                  ),
                  const SizedBox(height: 22),
                  // Quests — the long game made visible (project-length).
                  _Quests(
                    visited: visitedWeeks,
                    worldCount: worlds.length,
                    days: ageDays,
                    week: week,
                  ),
                  const SizedBox(height: 22),
                  // Allies — the party, from the weekly logs (staff-side, full
                  // names; export scrubs other-child names — see summer_book).
                  _Allies(entries: entries),
                  const SizedBox(height: 22),
                  _Milestones(entries: entries),
                  const SizedBox(height: 22),
                  _Links(subjectId: subjectId),
                ],
              ),
            ),
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
      await ref
          .read(characterSheetActionsProvider)
          .setChosenName(
            subjectId: subjectId,
            name: saved,
          );
    } finally {
      controller.dispose();
    }
  }

  /// AGE = distinct days the child shows up in any captured moment.
  int _participationDays(List<Entry> entries) {
    final days = <String>{};
    for (final e in entries) {
      final local = DateTime.tryParse(e.recordedAt)?.toLocal();
      if (local != null) days.add(dateKey(local));
    }
    return days.length;
  }

  Set<int> _visitedWeeks(List<Entry> entries, DateTime? start) {
    final weeks = <int>{};
    if (start == null) return weeks;
    for (final e in entries) {
      final local = DateTime.tryParse(e.recordedAt)?.toLocal();
      if (local == null) continue;
      final w = curriculumWeekFor(start, local);
      if (w != null) weeks.add(w);
    }
    return weeks;
  }
}
