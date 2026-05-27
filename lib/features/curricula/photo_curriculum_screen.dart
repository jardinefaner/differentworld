import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/curricula/photo_curriculum.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/settings/curricula/photo` — "Through My Eyes," the 3-week / 6-
/// session photography curriculum for ages 5-7.
///
/// **Visual contract.** Built from the same primitives as the rest of
/// the app — `EdgeScaffold` + `ContentHeader` + `SectionCard`s with
/// semantic tones (featured for the takeaway/game, neutral for body
/// blocks, danger never — this content is celebratory). Session color
/// lives only as small accents: a left rail on the active session
/// number, a chip tint on the vocabulary terms, the active underline
/// on the session selector. The body's typography is the app's;
/// Material 3 colorScheme handles light/dark.
///
/// **Two surfaces in one screen.**
///   1. **Session Plan** — pick a session 1–6, read its setup, game,
///      looking-together discussion, end ritual, takeaway. AI label
///      examples expand on tap.
///   2. **Vocabulary Journey** — the same 30 photography terms
///      grouped by which session they surface in. Closes with the
///      "they discovered ~30 terms" hero + a sample certificate.
class PhotoCurriculumScreen extends StatefulWidget {
  const PhotoCurriculumScreen({super.key});

  @override
  State<PhotoCurriculumScreen> createState() => _PhotoCurriculumScreenState();
}

enum _CurriculumView { sessions, vocabulary }

class _PhotoCurriculumScreenState extends State<PhotoCurriculumScreen> {
  /// Currently shown session index (0..5). Persisted only in widget
  /// state — opening the screen always starts at session 1.
  int _sessionIndex = 0;

  /// Top-level toggle between the session navigator and the vocab
  /// journey view.
  _CurriculumView _view = _CurriculumView.sessions;

  /// Stable per-mount expansion state for AI example cards. Keyed by
  /// "sessionSlug::exampleIndex" so it survives session switches and
  /// doesn't leak across mounts.
  final Set<String> _expandedAi = <String>{};

  PhotoSession get _activeSession => photoCurriculum[_sessionIndex];

  void _toggleAi(String key) {
    setState(() {
      if (!_expandedAi.remove(key)) _expandedAi.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      backFallbackRoute: '/settings',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const ContentHeader(
            title: 'Through My Eyes',
            subtitle:
                'Six games. One gallery. Ages 5–7 · 3 weeks · 6 sessions. '
                "They don't know they're learning photography. By Session 6 "
                "they're standing next to their photos saying \"it's a "
                'candid."',
          ),
          _SessionDots(
            activeIndex: _sessionIndex,
            onPick: (i) => setState(() {
              _sessionIndex = i;
              _view = _CurriculumView.sessions;
            }),
          ),
          const SizedBox(height: 14),
          _ViewToggle(
            view: _view,
            activeColor: _activeSession.color,
            onChanged: (v) => setState(() => _view = v),
          ),
          const SizedBox(height: 14),
          if (_view == _CurriculumView.sessions)
            _SessionBody(
              session: _activeSession,
              expandedAi: _expandedAi,
              onToggleAi: _toggleAi,
            )
          else
            const _VocabBody(),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Session selector — six numbered dots, color-progressed
// ───────────────────────────────────────────────────────────────────

class _SessionDots extends StatelessWidget {
  const _SessionDots({required this.activeIndex, required this.onPick});

  final int activeIndex;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          for (var i = 0; i < photoCurriculum.length; i++) ...[
            _SessionDot(
              session: photoCurriculum[i],
              active: i == activeIndex,
              done: i < activeIndex,
              onTap: () => onPick(i),
            ),
            if (i < photoCurriculum.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: i < activeIndex
                      ? photoCurriculum[i].color.withValues(alpha: 0.4)
                      : theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SessionDot extends StatelessWidget {
  const _SessionDot({
    required this.session,
    required this.active,
    required this.done,
    required this.onTap,
  });

  final PhotoSession session;
  final bool active;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = active ? 40.0 : 32.0;
    final bg = active
        ? session.color.withValues(alpha: 0.18)
        : done
            ? session.color.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerLow;
    final borderColor = active
        ? session.color
        : done
            ? session.color.withValues(alpha: 0.4)
            : theme.colorScheme.outlineVariant;
    final fg = active
        ? session.color
        : done
            ? session.color.withValues(alpha: 0.7)
            : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'Session ${session.number}, ${session.title}',
      button: true,
      selected: active,
      child: Material(
        color: bg,
        shape: CircleBorder(side: BorderSide(color: borderColor, width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Text(
                '${session.number}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Sessions / Vocabulary toggle — colored underline on active tab
// ───────────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.view,
    required this.activeColor,
    required this.onChanged,
  });

  final _CurriculumView view;
  final Color activeColor;
  final ValueChanged<_CurriculumView> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_CurriculumView>(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: activeColor.withValues(alpha: 0.16),
        selectedForegroundColor: activeColor,
      ),
      segments: const [
        ButtonSegment(
          value: _CurriculumView.sessions,
          icon: Icon(Icons.calendar_view_day_outlined),
          label: Text('Session plan'),
        ),
        ButtonSegment(
          value: _CurriculumView.vocabulary,
          icon: Icon(Icons.text_fields_outlined),
          label: Text('Vocabulary'),
        ),
      ],
      selected: {view},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Session view body — setup, game, looking, AI examples, ritual, takeaway
// ───────────────────────────────────────────────────────────────────

class _SessionBody extends StatelessWidget {
  const _SessionBody({
    required this.session,
    required this.expandedAi,
    required this.onToggleAi,
  });

  final PhotoSession session;
  final Set<String> expandedAi;
  final ValueChanged<String> onToggleAi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Session intro — color rail + glyph + week/day + title + big idea
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: session.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: session.color, width: 4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text(
                  session.glyph,
                  style: const TextStyle(fontSize: 30),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEK ${session.week} · DAY ${session.day} · '
                      'SESSION ${session.number}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: session.color,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.bigIdea,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          icon: Icons.checklist_outlined,
          title: 'Setup',
          child: _Paragraph(session.setup),
        ),
        SectionCard(
          tone: SectionCardTone.featured,
          icon: Icons.sports_esports_outlined,
          title: session.gameName,
          trailing: Text(
            session.gameDuration,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer
                  .withValues(alpha: 0.8),
            ),
          ),
          child: _Paragraph(
            session.gameRules,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        SectionCard(
          icon: Icons.visibility_outlined,
          title: 'Looking together',
          child: _Paragraph(session.lookingTogether),
        ),
        SectionCard(
          icon: Icons.smart_toy_outlined,
          title: 'AI label examples',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tap any photo to read the label and see the '
                    'terms that attach.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                for (var i = 0; i < session.aiExamples.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == session.aiExamples.length - 1 ? 0 : 8,
                    ),
                    child: _AiExampleCard(
                      example: session.aiExamples[i],
                      color: session.color,
                      expanded: expandedAi.contains('${session.slug}::$i'),
                      onToggle: () => onToggleAi('${session.slug}::$i'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SectionCard(
          icon: Icons.auto_awesome_outlined,
          title: 'End ritual',
          child: _Paragraph(session.endRitual),
        ),
        SectionCard(
          tone: SectionCardTone.featured,
          icon: Icons.lightbulb_outline,
          title: 'Takeaway',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SelectableText(
              session.takeaway,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ),
        SectionCard(
          icon: Icons.inventory_2_outlined,
          title: 'Materials',
          child: _Paragraph(
            session.materials,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        _ScheduleSessionCta(session: session),
      ],
    );
  }
}

/// Primary CTA at the bottom of every session detail — "Schedule
/// this session." Tapping it opens a glass bottom sheet that lists
/// the program's cohorts; picking one pushes the block-edit screen
/// with the session slug prefilled. The new block lands on TODAY by
/// default at 2pm; the user picks the time / location / lead from
/// the standard block-edit form.
///
/// Wave 166 will turn this into a richer "Apply curriculum starting
/// `date` on `days`" bulk flow that spawns all 6 sessions at once;
/// today it's one-at-a-time.
class _ScheduleSessionCta extends ConsumerWidget {
  const _ScheduleSessionCta({required this.session});

  final PhotoSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () => _open(context, ref),
      icon: const Icon(Icons.event_outlined),
      label: const Text('Schedule this session'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final groups = ref.read(groupsProvider).value ?? const <Group>[];
    if (groups.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Add a cohort first, then come back to schedule the session.',
          ),
        ),
      );
      return;
    }
    final pickedGroupId = await showGlassSheet<String>(
      context: context,
      builder: (sheetCtx) => _CohortPicker(groups: groups, session: session),
    );
    if (pickedGroupId == null || !context.mounted) return;
    // Default to today at 2pm — the most common after-school hour for
    // this curriculum. The user can change it in the form.
    final now = DateTime.now();
    final defaultStart = DateTime(now.year, now.month, now.day, 14);
    unawaited(
      context.push<void>(
        '/schedule/block',
        extra: (
          groupId: pickedGroupId,
          defaultStart: defaultStart,
          existing: null,
          prefillCurriculumSlug: session.slug,
        ),
      ),
    );
  }
}

/// Bottom-sheet cohort picker for the schedule CTA. Lists each cohort
/// once, vertically. Tapping a row pops with the group id.
class _CohortPicker extends StatelessWidget {
  const _CohortPicker({required this.groups, required this.session});

  final List<Group> groups;
  final PhotoSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                'Schedule for which cohort?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                '${session.title} · Session ${session.number} · '
                'Through My Eyes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final g in groups)
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: session.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: ExcludeSemantics(
                    child: Text(
                      session.glyph,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: session.color,
                      ),
                    ),
                  ),
                ),
                title: Text(g.name),
                subtitle: Text(
                  'Lands as a block at 2pm today',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(g.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color ?? theme.colorScheme.onSurface,
          height: 1.6,
        ),
      ),
    );
  }
}

class _AiExampleCard extends StatelessWidget {
  const _AiExampleCard({
    required this.example,
    required this.color,
    required this.expanded,
    required this.onToggle,
  });

  final PhotoAiExample example;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: expanded
          ? color.withValues(alpha: 0.08)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: color.withValues(alpha: expanded ? 1.0 : 0.4),
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      example.photo,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !expanded
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              example.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final term in example.terms)
                                  _TermChip(term: term, color: color),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermChip extends StatelessWidget {
  const _TermChip({required this.term, required this.color});
  final String term;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        term,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Vocabulary journey body — 6 stops + total + sample certificate
// ───────────────────────────────────────────────────────────────────

class _VocabBody extends StatelessWidget {
  const _VocabBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Total term count — sum of every stop, deduplicated across the
    // whole journey so a word that appears in two sessions doesn't
    // double-count. The "~30" claim in the editorial pitch lines up
    // with the actual count today.
    final allTerms = <String>{};
    for (final stop in vocabJourney) {
      allTerms.addAll(stop.terms);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Text(
            'They never studied these words. They heard them while '
            "laughing at their own photos. That's how vocabulary "
            'sticks at this age — attached to joy and surprise.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ),
        for (var i = 0; i < vocabJourney.length; i++)
          _VocabStopCard(
            session: photoCurriculum[i],
            stop: vocabJourney[i],
          ),
        const SizedBox(height: 4),
        SectionCard(
          tone: SectionCardTone.featured,
          icon: Icons.auto_awesome_outlined,
          title: 'Total vocabulary',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '~${allTerms.length}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'photography terms absorbed across 6 sessions.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Not one was taught. Every one was played.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.85),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        _SampleCertificate(),
      ],
    );
  }
}

class _VocabStopCard extends StatelessWidget {
  const _VocabStopCard({required this.session, required this.stop});

  final PhotoSession session;
  final VocabStop stop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: session.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${session.number}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: session.color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              session.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final term in stop.terms)
                  _TermChip(term: term, color: session.color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              stop.naturalNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SampleCertificate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = photoCurriculum.last.color; // session-6 magenta
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            'SAMPLE CERTIFICATE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'PHOTOGRAPHER',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Maya, age 6',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "You have a photographer's eye. You discovered:",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final term in ['close-up', 'candid', 'warm light'])
                _TermChip(term: term, color: accent),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Keep looking. Keep clicking.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
