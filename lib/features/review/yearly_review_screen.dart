import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/certifications/certifications_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/insights/insights_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
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

    final subjectsAsync = ref.watch(subjectsInSpaceProvider);
    final groupsAsync = ref.watch(groupsProvider);
    // Don't collapse LOADING into "0 children / 0 cohorts" — a year-end
    // review rendering confident zeros mid-first-sync reads as data loss.
    // The two core streams gate the whole snapshot; the rest degrade to 0
    // gracefully once these are live.
    if (subjectsAsync.isLoading || groupsAsync.isLoading) {
      return const EdgeScaffold(
        body: LoadingSlot(variant: LoadingVariant.cards),
      );
    }
    final subjects = subjectsAsync.value ?? const <Subject>[];
    final groups = groupsAsync.value ?? const <Group>[];
    final certs =
        ref.watch(certsInSpaceProvider).value ?? const <MemberCertification>[];
    final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
    final insights = ref.watch(insightsProvider).value ?? const <Insight>[];
    final captures = ref.watch(openCapturesProvider).value ?? const <Capture>[];

    final yearLabel = _academicYearLabel(DateTime.now());

    final certBreakdown = _CertBreakdown.from(certs);
    final insightBySeverity = _countBySeverity(insights);

    final stats = [
      _Stat(label: labels.subjectPlural, value: subjects.length),
      _Stat(label: labels.groupPlural, value: groups.length),
      _Stat(label: 'Vehicles', value: vehicles.length),
      _Stat(label: 'Open captures', value: captures.length),
    ];

    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the snapshot re-lays so the four "right
    // now" counts pack 2-up on a phone while the narrative sections (cert
    // strip, what-we-noticed, foundation prompts, the closing reflection) stay
    // full-width; off keeps the existing single-column scroll. Same providers,
    // same taps.
    final bento = bentoEnabled(ref, perScreen: null);

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: bento
          ? _bentoBody(
              context: context,
              theme: theme,
              yearLabel: yearLabel,
              stats: stats,
              certs: certs,
              certBreakdown: certBreakdown,
              insights: insights,
              insightBySeverity: insightBySeverity,
            )
          : _flatBody(
              context: context,
              theme: theme,
              yearLabel: yearLabel,
              stats: stats,
              certs: certs,
              certBreakdown: certBreakdown,
              insights: insights,
              insightBySeverity: insightBySeverity,
            ),
    );
  }

  /// The shared page opening — title + subtitle, then the year label —
  /// identical in both layouts except the label's bottom padding.
  List<Widget> _headerBlock(
    ThemeData theme,
    String yearLabel, {
    required double labelBottomPad,
  }) {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ContentHeader(
          title: 'Yearly review',
          subtitle:
              'A snapshot of where your program is — '
              'and an invitation to decide what comes next.',
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, labelBottomPad),
        child: Text(
          yearLabel,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ];
  }

  /// The default layout — one calm single-column scroll, read top to bottom
  /// like a letter.
  Widget _flatBody({
    required BuildContext context,
    required ThemeData theme,
    required String yearLabel,
    required List<_Stat> stats,
    required List<MemberCertification> certs,
    required _CertBreakdown certBreakdown,
    required List<Insight> insights,
    required Map<InsightSeverity, int> insightBySeverity,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      children: [
        ..._headerBlock(theme, yearLabel, labelBottomPad: 16),

        // -- Snapshot ----------------------------------------------------
        const _SectionHeader('Right now'),
        _StatGrid(stats: stats),

        // -- Certifications ---------------------------------------------
        if (certs.isNotEmpty) ...[
          const _SectionHeader('Certifications'),
          _CertStrip(breakdown: certBreakdown),
        ],

        // -- What the system noticed ------------------------------------
        const _SectionHeader('What the system noticed'),
        _NoticedSection(
          insights: insights,
          insightBySeverity: insightBySeverity,
        ),

        // -- Foundation prompts (reflective questions) ------------------
        const _SectionHeader('Foundation questions'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _FoundationPrompts(),
        ),

        // -- Capture closing reflection ---------------------------------
        const _SectionHeader('Note something'),
        // `_CaptureReflection` carries its own 20dp gutter (horizontalInset
        // default) — don't wrap it in another, or it double-insets.
        const _CaptureReflection(),
      ],
    );
  }

  /// The bento variant — SAME content, re-laid as a modular grid. The four
  /// "right now" counts become individual `phone: 1` stat tiles (2-up on a
  /// phone, 3-up on desktop); each narrative section is a full-width banner
  /// tile, headed by the same section label. Every tile carries a stable id,
  /// and every tile body shrink-wraps (no Spacer/Expanded) so an unbounded
  /// bento cell never throws (docs/GRID.md).
  Widget _bentoBody({
    required BuildContext context,
    required ThemeData theme,
    required String yearLabel,
    required List<_Stat> stats,
    required List<MemberCertification> certs,
    required _CertBreakdown certBreakdown,
    required List<Insight> insights,
    required Map<InsightSeverity, int> insightBySeverity,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      children: [
        ..._headerBlock(theme, yearLabel, labelBottomPad: 12),
        // The grid carries the same 20dp gutter the flat sections use, so the
        // stat tiles + full-width banners line up with the year label above.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BentoGrid(
            tiles: [
              // "Right now" label spans the row above the counts.
              const BentoTile(
                id: 'yearly-right-now-label',
                span: BentoSpan.wide(),
                child: _BentoSectionLabel('Right now'),
              ),
              // Four short stat tiles — 2-up on a phone, 3-up on desktop.
              for (var i = 0; i < stats.length; i++)
                BentoTile(
                  id: 'yearly-stat-${stats[i].label}',
                  span: const BentoSpan(phone: 1),
                  child: _StatTile(
                    key: ValueKey('yearly-stat-tile-${stats[i].label}'),
                    stat: stats[i],
                  ),
                ),
              // Certifications — narrative chips, full-width. The section
              // widgets render flush (`horizontalInset: 0`) because the grid's
              // 20dp Padding already owns the gutter.
              if (certs.isNotEmpty) ...[
                const BentoTile(
                  id: 'yearly-certs-label',
                  span: BentoSpan.wide(),
                  child: _BentoSectionLabel('Certifications'),
                ),
                BentoTile(
                  id: 'yearly-certs',
                  span: const BentoSpan.wide(),
                  child: _CertStrip(
                    breakdown: certBreakdown,
                    horizontalInset: 0,
                  ),
                ),
              ],
              // What the system noticed — prose + chips + actions, full-width.
              const BentoTile(
                id: 'yearly-noticed-label',
                span: BentoSpan.wide(),
                child: _BentoSectionLabel('What the system noticed'),
              ),
              BentoTile(
                id: 'yearly-noticed',
                span: const BentoSpan.wide(),
                child: _NoticedSection(
                  insights: insights,
                  insightBySeverity: insightBySeverity,
                  horizontalInset: 0,
                ),
              ),
              // Foundation questions — reflective prose cards, full-width.
              const BentoTile(
                id: 'yearly-foundation-label',
                span: BentoSpan.wide(),
                child: _BentoSectionLabel('Foundation questions'),
              ),
              const BentoTile(
                id: 'yearly-foundation',
                span: BentoSpan.wide(),
                child: _FoundationPrompts(),
              ),
              // Closing reflection — full-width.
              const BentoTile(
                id: 'yearly-note-label',
                span: BentoSpan.wide(),
                child: _BentoSectionLabel('Note something'),
              ),
              const BentoTile(
                id: 'yearly-note',
                span: BentoSpan.wide(),
                child: _CaptureReflection(horizontalInset: 0),
              ),
            ],
          ),
        ),
      ],
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
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Section label for the bento variant — same uppercase eyebrow as
/// [_SectionHeader] but with NO horizontal inset (the BentoGrid already owns
/// the page margin, so the label aligns with the tiles below it).
class _BentoSectionLabel extends StatelessWidget {
  const _BentoSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// "What the system noticed" — the prose line, the severity chip row, and the
/// See-insights / Weekly-walk-through actions. Extracted from the inline body
/// so the flat scroll AND the bento tile render the identical content + taps.
/// Shrink-wraps (`mainAxisSize.min`) so it sits safely in an unbounded bento
/// cell (docs/GRID.md).
class _NoticedSection extends StatelessWidget {
  const _NoticedSection({
    required this.insights,
    required this.insightBySeverity,
    this.horizontalInset = 20,
  });

  final List<Insight> insights;
  final Map<InsightSeverity, int> insightBySeverity;

  /// Horizontal page gutter — 20dp in the flat scroll, 0 in the bento tile
  /// (the grid's own Padding owns the gutter there).
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = horizontalInset;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(h, 0, h, 8),
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
            padding: EdgeInsets.symmetric(horizontal: h),
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
                    label: '${insightBySeverity[InsightSeverity.info]} FYI',
                    bg: theme.colorScheme.surfaceContainerHighest,
                    fg: theme.colorScheme.onSurface,
                  ),
                ],
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(h, 12, h, 0),
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
      ],
    );
  }
}

/// The closing "Note something" reflection — the prose line + the
/// Capture-a-reflection action. Extracted so the flat scroll and the bento
/// tile share the identical content + tap. Shrink-wraps for the bento cell.
class _CaptureReflection extends StatelessWidget {
  const _CaptureReflection({this.horizontalInset = 20});

  /// Horizontal page gutter — 20dp in the flat scroll, 0 in the bento tile.
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = horizontalInset;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(h, 0, h, 16),
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
          padding: EdgeInsets.symmetric(horizontal: h),
          child: FilledButton.icon(
            onPressed: () => context.push('/captures/new'),
            icon: const Icon(Icons.bolt_outlined),
            label: const Text('Capture a reflection'),
          ),
        ),
      ],
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
          for (final s in stats) _StatTile(stat: s),
        ],
      ),
    );
  }
}

/// One stat cell — a big number over its label. Extracted so the bento
/// variant can pack the SAME cells 2-up on a phone (the grid read) instead
/// of the flat 2-column [GridView]. Shrink-wraps vertically (`mainAxisSize.min`)
/// so it sits safely in an unbounded bento cell (docs/GRID.md).
class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, super.key});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flexible so the pill degrades rather than throwing when both
          // lines double. w700 not w800 — BRAND.md law 4 keeps the heavy
          // weights on the raw stages; the size already carries the emphasis.
          Flexible(
            child: Text(
              '${stat.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              stat.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
  const _CertStrip({required this.breakdown, this.horizontalInset = 20});
  final _CertBreakdown breakdown;

  /// Horizontal page gutter — 20dp in the flat scroll, 0 in the bento tile.
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
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
      'What did you tell yourself, back when you started, that this would be?',
    ),
    (
      'Who do we need on the team?',
      'Roles + capabilities for the kids you have now and the ones coming.',
    ),
    (
      "What's the build?",
      'The single thing you most want to be different a year from now.',
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
