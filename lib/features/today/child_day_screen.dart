import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/journey_day_sheet.dart';
import 'package:differentworld/features/action_words/mood.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/world_arc.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/child_day_bento_setting.dart';
import 'package:differentworld/features/world/character_sheet_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// `/subjects/:id/day` — the per-child **daily bundle**: one page that gathers
/// everything scattered across the app for ONE kid today. Their drawn avatar up
/// top, then today's three words (tap to mark done), their mood, the room's
/// focus + wall question (the "for all" layer), a one-tap photo that
/// auto-tags the current day/world, and an edge-to-edge multi-size gallery of
/// their moments. The teacher stops hunting; one kid, one page.
class ChildDayScreen extends ConsumerStatefulWidget {
  const ChildDayScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  ConsumerState<ChildDayScreen> createState() => _ChildDayScreenState();
}

class _ChildDayScreenState extends ConsumerState<ChildDayScreen> {
  bool _uploading = false;
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(subjectByIdProvider(widget.subjectId)).value;
    if (subject == null) {
      return const EdgeScaffold(
        body: EmptyState(
          icon: Icons.person_outline,
          title: 'Child not found',
        ),
      );
    }
    final bento = bentoEnabled(
      ref,
      perScreen: ref.watch(childDayBentoProvider).value,
    );
    return EdgeScaffold(
      actions: [
        IconButton(
          tooltip: 'Their story',
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () =>
              unawaited(context.push('/growth/${widget.subjectId}')),
        ),
      ],
      body: bento ? _bentoBody(subject) : _flatBody(subject),
    );
  }

  /// The classic stacked layout — the default.
  Widget _flatBody(Subject subject) {
    return ResponsivePage(
      children: [
        _Header(subject: subject),
        const SizedBox(height: 20),
        _TodaysWords(subjectId: subject.id, groupId: subject.groupId),
        const SizedBox(height: 20),
        const _TodaysMissions(),
        _MoodRow(subjectId: subject.id, groupId: subject.groupId),
        const SizedBox(height: 20),
        const _RoomToday(),
        const SizedBox(height: 20),
        _AddPhoto(
          subject: subject,
          uploading: _uploading,
          onTap: () => unawaited(_addPhoto(subject)),
        ),
        const SizedBox(height: 16),
        _Gallery(subjectId: subject.id),
      ],
    );
  }

  /// The opt-in **bento** — identity / words / mood as tiles (the words + mood
  /// taps stay LIVE inside their own tile, not a single-tap navigation), then
  /// missions / room / photo / gallery full-width below (each collapses when
  /// its journey isn't active, so no empty tiles). Same providers as
  /// [_flatBody]; pure re-layout, reversible from Settings.
  Widget _bentoBody(Subject subject) {
    return ResponsivePage(
      children: [
        BentoGrid(
          tiles: [
            BentoTile(
              id: 'identity',
              span: const BentoSpan.wide(),
              child: _DayTile(child: _Header(subject: subject)),
            ),
            BentoTile(
              id: 'words',
              span: const BentoSpan(),
              child: _DayTile(
                child: _TodaysWords(
                  subjectId: subject.id,
                  groupId: subject.groupId,
                ),
              ),
            ),
            BentoTile(
              id: 'mood',
              span: const BentoSpan(),
              child: _DayTile(
                child: _MoodRow(
                  subjectId: subject.id,
                  groupId: subject.groupId,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _TodaysMissions(),
        const _RoomToday(),
        const SizedBox(height: 20),
        _AddPhoto(
          subject: subject,
          uploading: _uploading,
          onTap: () => unawaited(_addPhoto(subject)),
        ),
        const SizedBox(height: 16),
        _Gallery(subjectId: subject.id),
      ],
    );
  }

  /// The auto-tag: caption the photo with the live day/world so it lands in
  /// context ("Day 23 · World of Water"), falling back to today's date.
  String _contextCaption() {
    final day = ref.read(currentProgramDayProvider);
    final block = ref.read(currentBlockProvider);
    if (day != null && block != null) {
      return 'Day $day · ${block.name}';
    }
    return todayKey();
  }

  Future<void> _addPhoto(Subject subject) async {
    // Re-entrancy guard set synchronously — covers the pick phase (two awaits
    // before _uploading flips), so a rapid double-tap can't run two captures.
    if (_picking || _uploading) return;
    _picking = true;
    try {
      final source = await _pickSource();
      if (source == null || !mounted) return;
      final picked = await ref.read(photoServiceProvider).pickPhoto(source);
      if (picked == null || !mounted) return;
      setState(() => _uploading = true);
      // Pre-generate the attachment id so an offline `pending:` upload's queue
      // patches THIS row (the CLAUDE.md attachment-id gotcha).
      final attId = const Uuid().v4();
      final url = await ref
          .read(photoServiceProvider)
          .uploadOnly(
            entityKind: 'attachment',
            entityId: attId,
            picked: picked,
          );
      if (!mounted) return;
      await ref
          .read(attachmentActionsProvider)
          .add(
            id: attId,
            entityKind: 'subject',
            entityId: subject.id,
            url: url,
            caption: _contextCaption(),
          );
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Couldn’t add the photo — try again.')),
      );
    } finally {
      _picking = false;
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<ImageSource?> _pickSource() => showGlassSheet<ImageSource>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from library'),
            onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// The drawn-self avatar + name + emerging title + day-of-program.
class _Header extends ConsumerWidget {
  const _Header({required this.subject});
  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fullName = '${subject.firstName} ${subject.lastName}'.trim();
    final sheet = ref.watch(characterSheetForSubjectProvider(subject.id)).value;
    final title = ref
        .watch(actionWordsCollectionProvider(subject.id))
        .value
        ?.emergingTitle;
    final day = ref.watch(currentProgramDayProvider);
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(
              context.push(
                '/subjects/${subject.id}/draw',
                extra: subject.firstName,
              ),
            );
          },
          child: PersonAvatar(
            name: fullName,
            photoUrl: sheet?.avatarUrl ?? subject.photoUrl,
            radius: 56,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          fullName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        if (day != null) ...[
          const SizedBox(height: 4),
          Text(
            'Day $day of 50',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Today's three words — tap each to mark it done. Picks-empty → a CTA.
class _TodaysWords extends ConsumerWidget {
  const _TodaysWords({required this.subjectId, this.groupId});
  final String subjectId;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = todayKey();
    final day = ref
        .watch(actionWordsForDayProvider((subjectId: subjectId, date: date)))
        .value;
    final picks = day?.verbPicks ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Today’s words'),
        const SizedBox(height: 8),
        if (picks.isEmpty)
          OutlinedButton.icon(
            onPressed: () =>
                unawaited(context.push('/action-words/pick/$subjectId')),
            icon: const Icon(Icons.add),
            label: const Text('Pick 3 words'),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final v in verbsByIds(picks))
                _VerbChip(
                  verb: v,
                  done: day!.done.contains(v.id),
                  onTap: () => unawaited(
                    ref
                        .read(actionWordsActionsProvider)
                        .toggleDone(
                          subjectId: subjectId,
                          date: date,
                          verbId: v.id,
                          groupId: groupId,
                        ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _VerbChip extends StatelessWidget {
  const _VerbChip({
    required this.verb,
    required this.done,
    required this.onTap,
  });
  final Verb verb;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: done ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(verb.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                verb.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: done ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                done ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: done
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current world's missions — a focused few of today's daily missions
/// ("pick 1-2"), with a "see all" into the full world arc (daily + weekly +
/// project). The kid-as-player "things to do" layer. Renders nothing until the
/// journey is active.
class _TodaysMissions extends ConsumerWidget {
  const _TodaysMissions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arc = ref.watch(currentWorldArcProvider);
    final day = ref.watch(currentProgramDayProvider);
    if (arc == null || day == null || arc.missions.daily.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final picks = dailyMissionsForDay(arc.missions.daily, day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _Label(text: 'Missions · pick 1-2')),
            TextButton(
              onPressed: () => unawaited(_showMissionsSheet(context, arc)),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final m in picks)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.bolt_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

Future<void> _showMissionsSheet(BuildContext context, WorldArc arc) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      Widget bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.bolt_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Missions',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const _Label(text: 'Daily · pick 1-2 each day'),
              const SizedBox(height: 8),
              for (final m in arc.missions.daily) bullet(m),
              if (arc.missions.weekly.isNotEmpty) ...[
                const SizedBox(height: 14),
                const _Label(text: 'This week'),
                const SizedBox(height: 8),
                for (final m in arc.missions.weekly) bullet(m),
              ],
              if (arc.missions.project.isNotEmpty) ...[
                const SizedBox(height: 14),
                const _Label(text: 'The project'),
                const SizedBox(height: 8),
                Text(arc.missions.project, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// The five-emoji mood row; today's pick highlighted.
class _MoodRow extends ConsumerWidget {
  const _MoodRow({required this.subjectId, this.groupId});
  final String subjectId;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = watchTodayMood(ref, subjectId)?.level;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Mood'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final m in MoodLevel.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      unawaited(
                        ref
                            .read(entryActionsProvider)
                            .recordMood(
                              subjectId: subjectId,
                              value: m.value,
                              groupId: groupId,
                            ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: current == m
                            ? m.color.withValues(alpha: 0.30)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: current == m
                            ? Border.all(color: m.color, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          m.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The "for all" layer — what the whole room is doing today: the day's focus +
/// the wall question. Tap to open the full day sheet. Hidden when the journey
/// isn't active.
class _RoomToday extends ConsumerWidget {
  const _RoomToday();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref.watch(currentProgramDayProvider);
    final journeyDay = ref.watch(todaysJourneyDayProvider);
    final block = ref.watch(currentBlockProvider);
    final wallQuestion = ref.watch(todaysWallQuestionProvider);
    if (day == null || journeyDay == null || block == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'The room today'),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: block.color.withValues(alpha: 0.10),
          child: InkWell(
            onTap: () => unawaited(
              showJourneyDaySheet(
                context,
                day: day,
                journeyDay: journeyDay,
                block: block,
                wallQuestion: wallQuestion,
                isToday: true,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Text(block.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          journeyDay.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (wallQuestion != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '“$wallQuestion”',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The one-tap photo button — captures + auto-tags the current day/world.
class _AddPhoto extends StatelessWidget {
  const _AddPhoto({
    required this.subject,
    required this.uploading,
    required this.onTap,
  });
  final Subject subject;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: uploading ? null : onTap,
        icon: uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_a_photo_outlined),
        label: Text(uploading ? 'Adding…' : 'Add a photo'),
      ),
    );
  }
}

/// Edge-to-edge, multi-size gallery of the child's moments. Newest first.
class _Gallery extends ConsumerWidget {
  const _Gallery({required this.subjectId});
  final String subjectId;

  // A repeating set of tile heights → a varied, masonry feel without needing
  // each photo's stored aspect ratio.
  static const _heights = [180.0, 240.0, 150.0, 210.0, 270.0, 170.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments =
        ref
            .watch(
              attachmentsForEntityProvider(
                (kind: 'subject', id: subjectId),
              ),
            )
            .value ??
        const <Attachment>[];
    if (attachments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: EmptyState(
          icon: Icons.photo_library_outlined,
          title: 'No moments yet',
          message: 'Tap “Add a photo” to start their day’s gallery.',
        ),
      );
    }
    // Newest first, capped — this masonry is shrink-wrapped inside the page
    // scroll (eager layout), so an unbounded season of photos would jank.
    // The recent window is the daily-hub's job; the full archive is the book.
    const cap = 40;
    final all = attachments.reversed.toList(growable: false);
    final photos = all.take(cap).toList(growable: false);
    final hidden = all.length - photos.length;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Moments'),
        const SizedBox(height: 10),
        MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          itemBuilder: (context, i) {
            final a = photos[i];
            return _GalleryTile(
              attachment: a,
              height: _heights[i % _heights.length],
            );
          },
        ),
        if (hidden > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Showing the latest $cap · $hidden earlier moments in their book',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.attachment, required this.height});
  final Attachment attachment;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: PersonPhotoNetwork(
              urlOrPath: attachment.thumbUrl ?? attachment.url,
              placeholderBuilder: (_) => ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          if ((attachment.caption ?? '').isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Over-photo caption scrim (the family_today pattern).
                    colors: [Colors.transparent, Colors.black54], // raw-canvas
                  ),
                ),
                child: Text(
                  attachment.caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white, // raw-canvas
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A plain bento tile surface for the daily-hub bento — holds an INTERACTIVE
/// section (words / mood) whose own tap targets stay live, so it's NOT a
/// single-tap `BentoModule`. Flat themed surface; the child shrink-wraps.
class _DayTile extends StatelessWidget {
  const _DayTile({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}
