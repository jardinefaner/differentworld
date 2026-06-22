import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/recap/recap_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/recap` — the **daily parent recap** composer (docs/VISION.md 2026-06-19).
/// The system assembles today's draft from the room's day (schedule + the
/// Daily) and each child's own moments (their hero, their answer); staff glance,
/// add a one-line moment, and tap Send. Send writes one scrubbed recap entry per
/// child (see `EntryActions.recordRecap`), which each family receives on Family
/// Today. Gated on `recapEnabledProvider` at the discovery layer.
class RecapComposerScreen extends ConsumerStatefulWidget {
  const RecapComposerScreen({this.groupId, super.key});

  /// Optional starting cohort (from `?group=`); otherwise the first.
  final String? groupId;

  @override
  ConsumerState<RecapComposerScreen> createState() =>
      _RecapComposerScreenState();
}

class _RecapComposerScreenState extends ConsumerState<RecapComposerScreen> {
  String? _groupId;
  final TextEditingController _moment = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
  }

  @override
  void dispose() {
    _moment.dispose();
    super.dispose();
  }

  Future<void> _send(RecapDraft draft, String groupId, String date) async {
    if (_sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(entryActionsProvider);
    unawaited(HapticFeedback.mediumImpact());
    try {
      final note = _moment.text.trim();
      await actions.recordRecap(
        groupId: groupId,
        date: date,
        activities: draft.activities,
        question: draft.question,
        momentNote: note.isEmpty ? null : note,
        children: draft.children,
      );
      if (!mounted) return;
      final n = draft.children.length;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Sent home to $n ${n == 1 ? 'family' : 'families'}.'),
          ),
        );
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't send — try again. ($e)")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    if (groups.isEmpty) {
      return const EdgeScaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.cottage_outlined,
            title: 'No cohorts yet',
            message:
                'Create a classroom and add children, then you can send their '
                'families a daily recap.',
          ),
        ),
      );
    }
    final selected = groups.firstWhere(
      (g) => g.id == _groupId,
      orElse: () => groups.first,
    );
    final date = todayKey();
    final draftAsync = ref.watch(
      recapDraftProvider((groupId: selected.id, date: date)),
    );

    return EdgeScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ContentHeader(
                title: 'Today’s recap',
                subtitle: 'What each family will see',
              ),
            ),
            if (groups.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final g in groups)
                      ChoiceChip(
                        label: Text(g.name),
                        selected: g.id == selected.id,
                        onSelected: (_) => setState(() => _groupId = g.id),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: draftAsync.when(
                loading: () => const LoadingSlot(),
                error: (e, _) => ErrorState(
                  title: 'Could not gather today’s recap',
                  detail: '$e',
                  onRetry: () => ref.invalidate(
                    recapDraftProvider((groupId: selected.id, date: date)),
                  ),
                ),
                data: (draft) => _composer(draft, selected, date),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(RecapDraft draft, Group group, String date) {
    if (draft.children.isEmpty) {
      return EmptyState(
        icon: Icons.group_outlined,
        title: 'No children in ${group.name} yet',
        message: 'Add children to this room to send their families a recap.',
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _RoomCard(activities: draft.activities, question: draft.question),
              if (draft.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PhotosCard(urls: draft.photos),
              ],
              const SizedBox(height: 12),
              _MomentField(controller: _moment),
              const SizedBox(height: 12),
              const _PrivacyNote(),
              const SizedBox(height: 16),
              _ChildrenPreview(draft: draft),
            ],
          ),
        ),
        _SendBar(
          count: draft.children.length,
          withMoments: draft.withMoments,
          sending: _sending,
          onSend: () => unawaited(_send(draft, group.id, date)),
        ),
      ],
    );
  }
}

/// The shared room day — activities + the day's question.
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.activities, required this.question});

  final List<String> activities;
  final String? question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: const Border(
          left: BorderSide(color: ActivityPalette.green, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'what the room did',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (activities.isEmpty)
            Text(
              'Nothing planned yet — the day’s activities will show here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final a in activities) _Chip(label: a)],
            ),
          if (question != null && question!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'question of the day',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              question!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The day's pictures, on the staff preview — the full set the day produced
/// (room moments + each child's own). Image-only thumbnails; tap opens the
/// full-screen viewer. Each family receives only their own scoped subset on
/// send (see `RecapChildInput.photoUrls`); a footnote says so.
class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: const Border(
          left: BorderSide(color: ActivityPalette.green, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'today’s pictures · ${urls.length}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                // Opaque so the 72x72 tap stays live even before the image
                // loads (a transparent placeholder would defer hit-testing).
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    PhotoViewer.open(context, urls: urls, initialIndex: i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: PersonPhotoNetwork(
                      urlOrPath: urls[i],
                      errorBuilder: (_) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Room photos go to every family; a photo of one child goes only to '
            'their family.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(label, style: theme.textTheme.bodyMedium),
    );
  }
}

/// The optional shared "a moment" line staff add.
class _MomentField extends StatelessWidget {
  const _MomentField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 2,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'A moment (optional)',
        hintText: 'e.g. We brewed lavender potions in the garden.',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }
}

/// The trust line — this is why the per-child send + scrub exists.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Each family sees only their own child’s name — others are hidden.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Per-child preview — what each family will get beyond the shared room day.
class _ChildrenPreview extends StatelessWidget {
  const _ChildrenPreview({required this.draft});

  final RecapDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'each child’s own moments · ${draft.withMoments} of '
          '${draft.children.length}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final c in draft.children)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PersonAvatar(name: c.firstName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.firstName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _momentLine(c.heroName, c.answer),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _momentLine(String? hero, String? answer) {
    final parts = <String>[
      if (hero != null && hero.isNotEmpty) 'Hero: $hero',
      if (answer != null && answer.isNotEmpty) '“$answer”',
    ];
    return parts.isEmpty ? 'Today’s room day' : parts.join(' · ');
  }
}

/// The pinned Send footer.
class _SendBar extends StatelessWidget {
  const _SendBar({
    required this.count,
    required this.withMoments,
    required this.sending,
    required this.onSend,
  });

  final int count;
  final int withMoments;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton.icon(
          onPressed: sending ? null : onSend,
          icon: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(
            sending
                ? 'Sending…'
                : 'Send to $count ${count == 1 ? 'family' : 'families'}',
          ),
        ),
      ),
    );
  }
}
