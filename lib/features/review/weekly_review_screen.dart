import 'dart:async';

import 'package:differentworld/features/insights/insights_providers.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/progress_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/review` — the framework's structure-layer surface, rendered as
/// one question per page in a swipeable PageView. Same underlying
/// data as `/insights`, different presentation: focused on a single
/// question, with a prominent action and a clear "next."
///
/// Per the framework conversation: this is the medium-tempo (weekly)
/// review surface. Director opens it on a Sunday (or whenever the
/// system prompts), walks through the open questions one at a time,
/// commits a decision per page. No dashboard, no parallel surfaces.
class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  late final PageController _page;
  int _index = 0;

  /// Snapshot of insight IDs at review start. We freeze the list so a
  /// snoozed-out insight doesn't reflow the PageView and disorient the
  /// user mid-review — they just see a "skipped" placeholder and can
  /// keep swiping. New insights that appear *during* the review are
  /// surfaced at the end so the user sees them in the same session.
  List<String> _initialOrder = const [];
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _page = PageController();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _seed(List<Insight> live) {
    if (_seeded) return;
    _initialOrder = live.map((i) => i.id).toList(growable: false);
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(insightsProvider);
    final liveInsights = insightsAsync.value ?? const <Insight>[];
    // Four-states standard: a load error must not masquerade as the
    // "all clear" empty state (it would, since liveInsights is empty on
    // error). Surface it with a retry before we seed the page order.
    if (insightsAsync.hasError && !_seeded) {
      return EdgeScaffold(
        body: ErrorState(
          title: 'Could not load your review',
          onRetry: () => ref.invalidate(insightsProvider),
        ),
      );
    }
    _seed(liveInsights);

    // Build the page list from the frozen initial order — every entry
    // is either the live insight (still active) or a "snoozed away"
    // placeholder. Any insight added after the seed sits at the end
    // so the user finishes the review with whatever the system found
    // along the way.
    final byId = {for (final i in liveInsights) i.id: i};
    final ordered = <_Page>[
      for (final id in _initialOrder)
        if (byId[id] != null) _Page.live(byId[id]!) else _Page.gone(id),
      for (final i in liveInsights)
        if (!_initialOrder.contains(i.id)) _Page.live(i),
    ];

    if (insightsAsync.isLoading && !_seeded) {
      return const EdgeScaffold(body: LoadingSlot());
    }
    if (ordered.isEmpty) {
      return EdgeScaffold(
        body: EmptyState(
          icon: Icons.check_circle_outline,
          title: 'All clear for this week',
          message:
              "Nothing's calling for attention right now. "
              'See you next week.',
          action: FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ),
      );
    }

    final pageCount = ordered.length;
    final atEnd = _index >= pageCount;

    return EdgeScaffold(
      body: Column(
        children: [
          // Shell reserves the top chrome height.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(
              title: 'Weekly review',
              subtitle: atEnd
                  ? "That's everything — close to finish."
                  : 'Question ${_index + 1} of $pageCount',
            ),
          ),
          const SizedBox(height: 8),
          // Progress dots — small visual anchor so the user feels the
          // shape of the review without a percentage bar. Shared widget
          // also used by Surveys (one vocabulary, less learning cost).
          ProgressDots(
            count: pageCount,
            current: _index.clamp(0, pageCount - 1),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PageView.builder(
              controller: _page,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: pageCount + 1,
              itemBuilder: (_, i) {
                if (i == pageCount) {
                  return _CloseoutPage(onClose: () => context.pop());
                }
                final page = ordered[i];
                return page.when(
                  live: (insight) => _ReviewPage(insight: insight),
                  gone: (_) => const _SkippedPage(),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _index == 0
                        ? null
                        : () {
                            unawaited(HapticFeedback.selectionClick());
                            unawaited(
                              _page.previousPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              ),
                            );
                          },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const Spacer(),
                  if (!atEnd)
                    TextButton.icon(
                      onPressed: () {
                        unawaited(HapticFeedback.selectionClick());
                        unawaited(
                          _page.nextPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Finish'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One insight rendered for review-mode. Uses the existing InsightCard
/// (same colors, same prompt, same actions) but inside a larger column
/// so the user feels they're "on" this question, not skimming a list.
class _ReviewPage extends StatelessWidget {
  const _ReviewPage({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    // Cap the review card on desktop/web so it reads as a focused column,
    // not one full-width card floating in a wide PageView page.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Breakpoints.contentMaxWidth,
          ),
          child: InsightCard(insight: insight),
        ),
      ),
    );
  }
}

/// Shown when an insight that was on the original review list has
/// been snoozed (or cleared because the data changed) since the
/// review started. We don't drop the page — that'd renumber every
/// subsequent question — we just mark it as handled and let the
/// user swipe past.
class _SkippedPage extends StatelessWidget {
  const _SkippedPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.primary,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Handled.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'You took care of this one. Swipe for the next.',
              textAlign: TextAlign.center,
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

class _CloseoutPage extends StatelessWidget {
  const _CloseoutPage({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // The PageView's parent state knows the page count but doesn't
    // pass it down; the user already saw the dots, so we lean on the
    // "this week" framing rather than a numeric stat. The yearly link
    // is reframed with timing so it doesn't read as "do another now."
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt,
              color: theme.colorScheme.primary,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              "That's a week.",
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The system will keep watching. Whatever shows up next '
              "week will surface here — you don't have to track it.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onClose, child: const Text('Done')),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push('/review/year'),
              icon: const Icon(Icons.event_note_outlined),
              label: const Text(
                'Open the yearly review (once per academic year)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sealed sum-type for the page list — either a live insight or a
/// placeholder for one that was snoozed/cleared mid-review.
sealed class _Page {
  const _Page();

  factory _Page.live(Insight i) = _LivePage;
  factory _Page.gone(String id) = _GonePage;

  T when<T>({
    required T Function(Insight insight) live,
    required T Function(String id) gone,
  }) {
    final self = this;
    if (self is _LivePage) return live(self.insight);
    if (self is _GonePage) return gone(self.id);
    throw StateError('unreachable');
  }
}

class _LivePage extends _Page {
  const _LivePage(this.insight);
  final Insight insight;
}

class _GonePage extends _Page {
  const _GonePage(this.id);
  final String id;
}
