import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:differentworld/shared/widgets/route_title.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/surveys` — index of every survey template registered in code.
///
/// One row per template. Tapping drills into the template detail
/// screen with the Start-a-survey button.
class SurveyIndexScreen extends ConsumerWidget {
  const SurveyIndexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const templates = SurveyTemplates.all;
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: ResponsivePage(
        bottomPadding: 32,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(
              title: 'Surveys',
              subtitle: 'Short check-ins kids can answer with smileys',
            ),
          ),
          for (final t in templates) _SurveyTemplateCard(template: t),
        ],
      ),
    );
  }
}

class _SurveyTemplateCard extends ConsumerWidget {
  const _SurveyTemplateCard({required this.template});
  final SurveyTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    final responsesAsync = spaceId == null
        ? const AsyncValue<List<SurveyResponse>>.data([])
        : ref.watch(
            surveyResponsesProvider(
              (spaceId: spaceId, templateId: template.id),
            ),
          );
    final responses = responsesAsync.value ?? const <SurveyResponse>[];
    final completed = responses
        .where((r) => r.status == SurveyResponseStatus.completed)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: FeatureCard(
        onTap: () => context.push('/surveys/${template.id}'),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: const Icon(Icons.poll_outlined),
        ),
        title: template.title,
        subtitle: '${template.year} · ${template.scored.length} questions',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: completed > 0
                    ? scheme.primaryContainer.withValues(alpha: 0.7)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                // Wave 138: anonymous surveys — show only completed
                // count (one row = one response, not one row = one
                // kid). In-progress drafts no longer get separate
                // billing because nobody resumes them; they're just
                // abandoned sessions.
                '$completed',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// `/surveys/:templateId` — Wave 138: simplified anonymous landing.
///
/// Replaces the per-kid roster (which assumed surveys were attributed
/// to individuals) with:
///   * Template title + subtitle
///   * A big "Start a new survey" button (hands the device to a kid)
///   * A small history strip: "N responses recorded · View table"
///
/// No resume — every Start fires a fresh response. The table view is
/// where directors review what's been recorded.
class SurveyTemplateDetailScreen extends ConsumerWidget {
  const SurveyTemplateDetailScreen({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = SurveyTemplates.byId(templateId);
    if (template == null) {
      return const EdgeScaffold(
        body: EmptyState(
          icon: Icons.quiz_outlined,
          title: 'Survey not found',
        ),
      );
    }
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    final responsesAsync = spaceId == null
        ? const AsyncValue<List<SurveyResponse>>.data([])
        : ref.watch(
            surveyResponsesProvider(
              (spaceId: spaceId, templateId: templateId),
            ),
          );

    return RouteTitle(
      title: template.title,
      child: EdgeScaffold(
        backFallbackRoute: '/surveys',
        actions: [
          SecondaryActionButton(
            tooltip: 'Table view',
            icon: Icons.table_chart_outlined,
            onPressed: () => context.push('/surveys/$templateId/table'),
          ),
          const SyncStatusIndicator(),
        ],
        body: responsesAsync.when(
          loading: () => const LoadingSlot(),
          error: (_, _) => ErrorState(
            title: 'Could not load responses',
            onRetry: () => ref.invalidate(
              surveyResponsesProvider(
                (
                  spaceId: spaceId ?? '',
                  templateId: templateId,
                ),
              ),
            ),
          ),
          data: (responses) {
            final completed = responses
                .where((r) => r.status == SurveyResponseStatus.completed)
                .length;
            return _TemplateLanding(
              template: template,
              completed: completed,
              totalRecorded: responses.length,
            );
          },
        ),
      ),
    );
  }
}

class _TemplateLanding extends StatelessWidget {
  const _TemplateLanding({
    required this.template,
    required this.completed,
    required this.totalRecorded,
  });

  final SurveyTemplate template;
  final int completed;
  final int totalRecorded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: const Icon(Icons.poll_outlined, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                template.title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${template.year} · ${template.scored.length} questions',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Responses are anonymous. Each kid picks a reader and '
                'tells us their age, grade, and school — but their '
                'name never gets attached.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () =>
                    context.push('/surveys/${template.id}/take'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start a new survey'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              _HistoryStrip(
                completed: completed,
                totalRecorded: totalRecorded,
                templateId: template.id,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({
    required this.completed,
    required this.totalRecorded,
    required this.templateId,
  });

  final int completed;
  final int totalRecorded;
  final String templateId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (totalRecorded == 0) {
      return Text(
        'No responses yet.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      );
    }
    final label = totalRecorded == 1
        ? '1 response recorded'
        : '$totalRecorded responses recorded';
    final completedLabel = completed == totalRecorded
        ? ''
        : ' · $completed complete';
    return TextButton.icon(
      onPressed: () =>
          GoRouter.of(context).push('/surveys/$templateId/table'),
      icon: const Icon(Icons.table_chart_outlined),
      label: Text('$label$completedLabel · View table'),
    );
  }
}
