import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/certifications/certifications_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/insights/insights_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/review/year` — the framework's Foundation re-grounding surface.
///
/// Per the framework conversation (months-long tempo): a calm,
/// scrollable snapshot of where the program *is* right now. Not a
/// dashboard — no graphs, no sparklines, no live tabs. A director
/// opens this once or twice a year, reads it like a letter, decides
/// what to commit to for the next stretch, and leaves.
///
/// Persistence of "what I decided to commit to" is deliberately
/// out-of-scope for v1 — those reflections go into the Capture inbox
/// (linked at the bottom) where they live alongside every other
/// "I noticed…" thought. When the inbox handles those well, we can
/// promote yearly-reflections to their own kind.
class YearlyReviewScreen extends ConsumerWidget {
  const YearlyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final labels = ref.watch(verticalLabelsProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      return const EdgeScaffold(body: LoadingSlot());
    }

    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final certs = ref.watch(certsInSpaceProvider).value ??
        const <MemberCertification>[];
    final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
    final insights =
        ref.watch(insightsProvider).value ?? const <Insight>[];
    final captures =
        ref.watch(openCapturesProvider).value ?? const <Capture>[];

    final yearLabel = _academicYearLabel(DateTime.now());

    final certBreakdown = _CertBreakdown.from(certs);
    final insightBySeverity = _countBySeverity(insights);

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(
              title: 'Yearly review',
              subtitle: 'A snapshot of where your program is — '
                  'and an invitation to decide what comes next.',
            ),
          ),

          // -- Year label --------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              yearLabel,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // -- Snapshot ----------------------------------------------------
          const _SectionHeader('Right now'),
          _StatGrid(
            stats: [
              _Stat(label: labels.subjectPlural, value: subjects.length),
              _Stat(label: labels.groupPlural, value: groups.length),
              _Stat(label: 'Vehicles', value: vehicles.length),
              _Stat(label: 'Open captures', value: captures.length),
            ],
          ),

          // -- Certifications ---------------------------------------------
          if (certs.isNotEmpty) ...[
            const _SectionHeader('Certifications'),
            _CertStrip(breakdown: certBreakdown),
          ],

          // -- What the system noticed ------------------------------------
          const _SectionHeader('What the system noticed'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              insights.isEmpty
                  ? "The system isn't surfacing any questions right now."
                      ' Quiet is a good place to start the year from.'
                  : '${insights.length} '
                      '${insights.length == 1 ? 'question' : 'questions'} '
                      'open across your data.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (insights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (insightBySeverity[InsightSeverity.urgent]! > 0)
                    _SeverityChip(
                      label:
                          '${insightBySeverity[InsightSeverity.urgent]} urgent',
                      bg: theme.colorScheme.errorContainer,
                      fg: theme.colorScheme.onErrorContainer,
                    ),
                  if (insightBySeverity[InsightSeverity.suggestion]! > 0) ...[
                    if (insightBySeverity[InsightSeverity.urgent]! > 0)
                      const SizedBox(width: 8),
                    _SeverityChip(
                      label:
                          '${insightBySeverity[InsightSeverity.suggestion]} suggestions',
                      bg: theme.colorScheme.tertiaryContainer,
                      fg: theme.colorScheme.onTertiaryContainer,
                    ),
                  ],
                  if (insightBySeverity[InsightSeverity.info]! > 0) ...[
                    const SizedBox(width: 8),
                    _SeverityChip(
                      label:
                          '${insightBySeverity[InsightSeverity.info]} FYI',
                      bg: theme.colorScheme.surfaceContainerHighest,
                      fg: theme.colorScheme.onSurface,
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (insights.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/insights'),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('See insights'),
                  ),
                if (insights.length >= 2)
                  FilledButton.icon(
                    onPressed: () => context.push('/review'),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Weekly walk-through'),
                  ),
              ],
            ),
          ),

          // -- Foundation prompts (reflective questions) ------------------
          const _SectionHeader('Foundation questions'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _FoundationPrompts(),
          ),

          // -- Capture closing reflection ---------------------------------
          const _SectionHeader('Note something'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Anything you want to come back to lives in the capture '
              "inbox. Drop a note here — you'll see it again the next "
              'time the system asks.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.icon(
              onPressed: () => context.push('/captures/new'),
              icon: const Icon(Icons.bolt_outlined),
              label: const Text('Capture a reflection'),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Section header (reused below) ------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// -- Stats grid -------------------------------------------------------------

class _Stat {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: [
          for (final s in stats)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.value}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    s.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

// -- Certs strip ------------------------------------------------------------

class _CertBreakdown {
  const _CertBreakdown({
    required this.valid,
    required this.expiringSoon,
    required this.expired,
  });

  factory _CertBreakdown.from(List<MemberCertification> certs) {
    final today = DateTime.now();
    final soon = today.add(const Duration(days: 30));
    var valid = 0;
    var expiring = 0;
    var expired = 0;
    for (final c in certs) {
      final iso = c.expiresAt;
      if (iso == null || iso.isEmpty) {
        valid++;
        continue;
      }
      final dt = DateTime.tryParse(iso);
      if (dt == null) {
        valid++;
        continue;
      }
      if (dt.isBefore(today)) {
        expired++;
      } else if (dt.isBefore(soon)) {
        expiring++;
      } else {
        valid++;
      }
    }
    return _CertBreakdown(
      valid: valid,
      expiringSoon: expiring,
      expired: expired,
    );
  }

  final int valid;
  final int expiringSoon;
  final int expired;
}

class _CertStrip extends StatelessWidget {
  const _CertStrip({required this.breakdown});
  final _CertBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SeverityChip(
            label: '${breakdown.valid} valid',
            bg: theme.colorScheme.surfaceContainerHighest,
            fg: theme.colorScheme.onSurface,
          ),
          if (breakdown.expiringSoon > 0)
            _SeverityChip(
              label: '${breakdown.expiringSoon} expiring soon',
              bg: theme.colorScheme.tertiaryContainer,
              fg: theme.colorScheme.onTertiaryContainer,
            ),
          if (breakdown.expired > 0)
            _SeverityChip(
              label: '${breakdown.expired} expired',
              bg: theme.colorScheme.errorContainer,
              fg: theme.colorScheme.onErrorContainer,
            ),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// -- Foundation prompts -----------------------------------------------------

/// The yearly review's spine: the three Foundation questions per the
/// framework. These are deliberately open-ended — the director writes
/// the answers in their own head (or in the Capture inbox). We just
/// hold the prompts so the ritual has shape.
class _FoundationPrompts extends StatelessWidget {
  const _FoundationPrompts();

  static const _prompts = [
    (
      'Why does this program exist?',
      'What did you tell yourself, back when you started, that this would be?'
    ),
    (
      'Who do we need on the team?',
      'Roles + capabilities for the kids you have now and the ones coming.'
    ),
    (
      "What's the build?",
      'The single thing you most want to be different a year from now.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, body) in _prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// -- Helpers ---------------------------------------------------------------

/// Academic-year label — programs run a roughly September-to-June
/// calendar, so we label the "current" year by which half of the
/// calendar we're in. Late summer (July / August) still labels as
/// the year that just ended, since rosters typically haven't refreshed.
String _academicYearLabel(DateTime now) {
  // Aug → Dec: this year–next year (e.g. Sep 2025 → "2025–26 program year")
  // Jan → Jul: last year–this year (e.g. Mar 2026 → "2025–26 program year")
  final startYear = now.month >= 8 ? now.year : now.year - 1;
  final endYear = startYear + 1;
  final shortEnd = endYear.toString().substring(2);
  return '$startYear–$shortEnd program year';
}

Map<InsightSeverity, int> _countBySeverity(List<Insight> insights) {
  final out = {
    for (final s in InsightSeverity.values) s: 0,
  };
  for (final i in insights) {
    out[i.severity] = (out[i.severity] ?? 0) + 1;
  }
  return out;
}
