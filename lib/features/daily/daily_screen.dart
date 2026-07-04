import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/daily/daily_providers.dart';
import 'package:differentworld/features/daily/response_edit_screen.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/accent_edge_card.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// `/daily` — the **Daily** ritual (docs/VISION.md 2026-06-19): the day's
/// Question, Quote, and Mission, host-presented in sequence, each answered with
/// a captured response (a sentence or a drawing) that becomes part of the
/// record — "document the now… these are the things they'll write in their
/// books." Mission reuses the Do It bank, so doing it writes a `did_it` row.
///
/// Teacher-paced; gated on `dailyEnabledProvider` at the discovery layer.
class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({this.groupId, super.key});

  /// The room doing it, when launched from a cohort (records are group-scoped).
  final String? groupId;

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen> {
  bool _missionSaving = false;

  Future<void> _respond(String promptKind, String promptText) async {
    // Writing the answer is a task → a deep-linkable page, not a sheet
    // (CLAUDE.md "No modal is a task"). The page pops a [DailyResponse] back;
    // we own the upload + persistence here. Cohort rides in `?group=` to mirror
    // the `/daily` route; the prompt prose rides in `extra`.
    final groupId = widget.groupId;
    final route = groupId == null
        ? '/daily/response'
        : '/daily/response?group=$groupId';
    final result = await context.push<DailyResponse>(route, extra: promptText);
    if (result == null || !mounted) return;
    final text = result.text?.trim();
    final hasText = text != null && text.isNotEmpty;
    if (!hasText && result.photo == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(entryActionsProvider);
    unawaited(HapticFeedback.selectionClick());
    try {
      var urls = const <String>[];
      var ids = const <String>[];
      final photo = result.photo;
      if (photo != null) {
        final attId = const Uuid().v4();
        final url = await ref
            .read(photoServiceProvider)
            .uploadOnly(
              entityKind: 'attachment',
              entityId: attId,
              picked: photo,
            );
        urls = <String>[url];
        ids = <String>[attId];
      }
      await actions.recordDailyResponse(
        promptKind: promptKind,
        promptText: promptText,
        subjectId: result.subjectId,
        groupId: widget.groupId,
        responseText: text,
        photoUrls: urls,
        photoIds: ids,
      );
      if (!mounted) return;
      final who = result.subjectName;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              who == null
                  ? 'Saved to today’s record.'
                  : 'Saved to $who’s book.',
            ),
          ),
        );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[daily] response save failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save — try again.")),
      );
    }
  }

  Future<void> _missionDone(ContentItem mission) async {
    if (_missionSaving) return;
    setState(() => _missionSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref
          .read(entryActionsProvider)
          .recordDidIt(
            instruction: (mission.payload['text'] as String?) ?? '',
            verb: (mission.payload['verb'] as String?) ?? 'do',
            groupId: widget.groupId,
          );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Nice — the room did it!')),
        );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[daily] mission save failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save — try again.")),
      );
    } finally {
      if (mounted) setState(() => _missionSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trio = ref.watch(todaysDailyProvider);
    final question = trio.question;
    final quote = trio.quote;
    final mission = trio.mission;
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the same three prompt cards re-lay as
    // importance-weighted bento tiles over the SAME provider; off keeps the
    // existing stacked list. The respond / mission flows are untouched.
    final bento = bentoEnabled(ref, perScreen: null);

    if (question == null && quote == null && mission == null) {
      return const EdgeScaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: 'Nothing for today yet',
            message: 'The day’s question, quote, and mission will appear here.',
          ),
        ),
      );
    }

    // The three cards, shared by both layouts so they never drift. In bento
    // they drop their bottom margin (the grid's run-spacing handles the gap).
    Widget questionCard({required bool margin}) => _PromptCard(
      eyebrow: 'question of the day',
      icon: Icons.help_outline,
      accent: ActivityPalette.purple,
      text: (question!.payload['text'] as String?) ?? '',
      margin: margin,
      onRespond: () => unawaited(
        _respond(
          ContentKind.question,
          (question.payload['text'] as String?) ?? '',
        ),
      ),
    );
    Widget quoteCard({required bool margin}) => _PromptCard(
      eyebrow: 'quote of the day',
      icon: Icons.format_quote_outlined,
      accent: ActivityPalette.amber,
      text: _quoteText(quote!),
      margin: margin,
      onRespond: () =>
          unawaited(_respond(ContentKind.quote, _quoteText(quote))),
    );
    Widget missionCard() => _MissionCard(
      text: (mission!.payload['text'] as String?) ?? '',
      saving: _missionSaving,
      onDone: () => unawaited(_missionDone(mission)),
    );

    return EdgeScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const ContentHeader(
              title: 'Today',
              subtitle: 'Answer in your own way — a sentence or a drawing',
            ),
            if (bento)
              BentoGrid(
                tiles: [
                  // Question leads as the hero ("what matters now"): full on
                  // phone, two-thirds on desktop, two rows tall. Quote pairs
                  // beside it; Mission is the full-width action band below
                  // (its CTA is a full-width button — wants the room).
                  if (question != null)
                    BentoTile(
                      id: 'question',
                      span: const BentoSpan.hero(),
                      child: questionCard(margin: false),
                    ),
                  if (quote != null)
                    BentoTile(
                      id: 'quote',
                      span: const BentoSpan(tablet: 4, rows: 2),
                      child: quoteCard(margin: false),
                    ),
                  if (mission != null)
                    BentoTile(
                      id: 'mission',
                      span: const BentoSpan.wide(),
                      child: missionCard(),
                    ),
                ],
              )
            else ...[
              if (question != null) questionCard(margin: true),
              if (quote != null) quoteCard(margin: true),
              if (mission != null) missionCard(),
            ],
          ],
        ),
      ),
    );
  }

  String _quoteText(ContentItem quote) {
    final text = (quote.payload['text'] as String?) ?? '';
    final author = (quote.payload['author'] as String?)?.trim();
    return (author == null || author.isEmpty) ? text : '$text — $author';
  }
}

/// A Question / Quote card — the prompt + a "respond" affordance.
class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.eyebrow,
    required this.icon,
    required this.accent,
    required this.text,
    required this.onRespond,
    this.margin = true,
  });

  final String eyebrow;
  final IconData icon;
  final Color accent;
  final String text;
  final VoidCallback onRespond;

  /// Bottom margin between stacked cards in the list layout. The bento layout
  /// drops it (the grid's run-spacing handles the gap) so the tile fills its
  /// cell cleanly.
  final bool margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AccentEdgeCard(
      accent: accent,
      eyebrow: eyebrow,
      eyebrowIcon: icon,
      margin: margin ? const EdgeInsets.only(bottom: 14) : EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      children: [
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onRespond,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Add a response'),
          ),
        ),
      ],
    );
  }
}

/// The Mission card — a Do It action; "We did it!" writes a `did_it` record.
class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.text,
    required this.saving,
    required this.onDone,
  });

  final String text;
  final bool saving;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AccentEdgeCard(
      accent: ActivityPalette.green,
      eyebrow: 'mission of the day',
      eyebrowIcon: Icons.flag_outlined,
      children: [
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: saving ? null : onDone,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('We did it!'),
          ),
        ),
      ],
    );
  }
}
