import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/action_words/verb_roles.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/verb-jobs` — **one vocabulary, three lives.** Each of the 12 verbs is a
/// kid's JOB for the day (with the exact words a helper says), a 3-level
/// MISSION (challenge ideas, NOT the evidence-backed Missions feature), and a
/// 3-level STAFF skill. Pure reference content (bundled JSON).
class VerbJobsScreen extends ConsumerWidget {
  const VerbJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(verbRolesProvider);
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the verb cards re-pack as a responsive
    // grid over the SAME provider data; off keeps the single-column list.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      body: rolesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the verb jobs',
          onRetry: () => ref.invalidate(verbRolesProvider),
        ),
        data: (roles) {
          // The verbs in canonical order, paired with their role.
          final cards = [
            for (final v in kVerbs)
              if (roles[v.id] case final role?) (v, role),
          ];
          if (cards.isEmpty) {
            return const EmptyState(
              icon: Icons.badge_outlined,
              title: 'No verb jobs yet',
              message: 'The verb roles could not be loaded.',
            );
          }
          return bento ? _bentoBody(cards) : _flatBody(cards);
        },
      ),
    );
  }

  /// The default layout — a single-column list of expandable verb cards.
  Widget _flatBody(List<(Verb, VerbRole)> cards) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'Jobs, missions & growth',
          subtitle:
              'Every verb is a job a kid does, a mission they take '
              'on, and a way the grown-ups grow',
        ),
        for (final (verb, role) in cards) _VerbCard(verb: verb, role: role),
      ],
    );
  }

  /// The bento variant — SAME cards, re-packed as a responsive grid. The cards
  /// expand in place to a text-heavy body (jobs + helper-says + a 3-level
  /// mission + staff growth), so they stay FULL-WIDTH on a phone (a half-width
  /// expanded body would crush the narrative) and go 2-up on a tablet, 3-up on
  /// desktop — the [BentoGrid] default span does exactly that. Ragged runs when
  /// one card is open are expected (the bento Wrap tolerates them).
  Widget _bentoBody(List<(Verb, VerbRole)> cards) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'Jobs, missions & growth',
          subtitle:
              'Every verb is a job a kid does, a mission they take '
              'on, and a way the grown-ups grow',
        ),
        const SizedBox(height: 8),
        BentoGrid(
          tiles: [
            for (final (verb, role) in cards)
              BentoTile(
                id: 'verb-${verb.id}',
                // Full-width phone, 2-up tablet, 3-up desktop (the defaults).
                span: const BentoSpan(),
                child: _VerbCard(verb: verb, role: role, inGrid: true),
              ),
          ],
        ),
      ],
    );
  }
}

class _VerbCard extends StatelessWidget {
  const _VerbCard({
    required this.verb,
    required this.role,
    this.inGrid = false,
  });
  final Verb verb;
  final VerbRole role;

  /// In the bento grid the cell owns spacing, so drop the card's own bottom
  /// margin (it'd add a gap inside the tile).
  final bool inGrid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Text(verb.emoji, style: const TextStyle(fontSize: 26)),
        title: Text(
          '${verb.label.toUpperCase()} · ${role.jobTitle}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        subtitle: Text(
          verb.lens,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Jobs', accent),
          for (final job in role.jobs) _JobTile(job: job, accent: accent),
          const SizedBox(height: 8),
          _Label("Today's mission", accent),
          for (var i = 0; i < role.mission.levels.length; i++)
            _LevelRow(
              level: i + 1,
              text: role.mission.levels[i],
              accent: accent,
            ),
          _GuideBox(
            label: 'Helper guide',
            body: role.mission.helperGuide,
            tone: AppColors.growthOf(theme),
          ),
          const SizedBox(height: 10),
          _Label('Staff growth', accent),
          for (final s in role.staffSkills)
            _LevelRow(
              level: s.level,
              text: s.skill,
              sub: s.desc,
              accent: accent,
            ),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.accent});
  final VerbJob job;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.job,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (job.what.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                job.what,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ),
          if (job.helperSays.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: accent.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HELPER SAYS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      letterSpacing: 1.5,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '“${job.helperSays}”',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.text,
    required this.accent,
    this.sub,
  });
  final int level;
  final String text;
  final String? sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.03 * level),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: accent.withValues(alpha: 0.2 + 0.25 * (level - 1)),
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'L$level',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (sub != null && sub!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 26),
              child: Text(
                sub!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideBox extends StatelessWidget {
  const _GuideBox({
    required this.label,
    required this.body,
    required this.tone,
  });
  final String label;
  final String body;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              letterSpacing: 1.5,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 3),
          Text(body, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.accent);
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
