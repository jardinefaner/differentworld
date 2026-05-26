import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_grid.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:differentworld/shared/widgets/route_title.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/surveys` — index of every survey template registered in code.
///
/// One row per template. Tapping drills into the per-template list
/// of children with their completion status.
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
    final inProgress = responses
        .where((r) => r.status == SurveyResponseStatus.draft)
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$completed',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (inProgress > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 1,
                      height: 12,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$inProgress…',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.tertiary,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
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

/// `/surveys/:templateId` — every student in the space with their
/// completion status for the chosen template. Tap a row → start (or
/// resume) the survey for that kid.
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
    final subjectsAsync = ref.watch(subjectsInSpaceProvider);
    final responsesAsync = spaceId == null
        ? const AsyncValue<List<SurveyResponse>>.data([])
        : ref.watch(
            surveyResponsesProvider(
              (spaceId: spaceId, templateId: templateId),
            ),
          );

    // Compute the "next unsurveyed kid" so the primary action can
    // jump straight to them. When everyone's done, pivots to "redo"
    // for the first kid.
    final subjectsList = subjectsAsync.value ?? const <Subject>[];
    final responsesList = responsesAsync.value ?? const <SurveyResponse>[];
    final completedIds = <String>{
      for (final r in responsesList)
        if (r.status == SurveyResponseStatus.completed) r.subjectId,
    };
    final nextSubject = subjectsList.isEmpty
        ? null
        : subjectsList.firstWhere(
            (s) => !completedIds.contains(s.id),
            orElse: () => subjectsList.first,
          );
    final allDone =
        subjectsList.isNotEmpty && completedIds.length >= subjectsList.length;

    // Wave 113: dynamic tab title — the survey template's name.
    return RouteTitle(
      title: template.title,
      child: EdgeScaffold(
      backFallbackRoute: '/surveys',
      actions: [
        if (nextSubject != null)
          PrimaryActionButton(
            tooltip: allDone
                ? 'Redo · ${nextSubject.firstName}'
                : 'Survey · ${nextSubject.firstName}',
            icon: allDone ? Icons.replay : Icons.arrow_forward,
            onPressed: () => context.push(
              '/surveys/$templateId/take/${nextSubject.id}',
            ),
          ),
        SecondaryActionButton(
          tooltip: 'Table view',
          icon: Icons.table_chart_outlined,
          onPressed: () => context.push('/surveys/$templateId/table'),
        ),
        const SyncStatusIndicator(),
      ],
      body: subjectsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load students',
          onRetry: () => ref.invalidate(subjectsInSpaceProvider),
        ),
        data: (subjects) {
          if (subjects.isEmpty) {
            return const EmptyState(
              icon: Icons.child_care_outlined,
              title: 'No students yet',
              message: 'Add students before running the survey.',
            );
          }
          final responses = responsesAsync.value ?? const <SurveyResponse>[];
          final statusBySubjectId = <String, String>{
            for (final r in responses) r.subjectId: r.status,
          };
          final completed = responses
              .where((r) => r.status == SurveyResponseStatus.completed)
              .length;
          // Wave 116: ResponsiveGrid at tablet+. A roster of 24 kids
          // each in a wide-and-short status row stretched edge-to-
          // edge on a 1920px screen; 2-3 columns fits more on
          // screen + makes the "tap a kid to start their survey"
          // affordance feel like an interactive board.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: template.title,
                  subtitle:
                      '${template.year} · $completed / ${subjects.length} '
                      'completed',
                ),
              ),
              Expanded(
                child: ResponsiveGrid(
                  itemCount: subjects.length,
                  // Status rows are short — avatar + name + status
                  // chip. Wide-and-short reads as scannable.
                  aspectRatio: 3,
                  itemMaxWidth: 320,
                  itemBuilder: (_, i) {
                    final subject = subjects[i];
                    final status = statusBySubjectId[subject.id];
                    return _SubjectStatusRow(
                      subject: subject,
                      status: status,
                      templateId: template.id,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
    );
  }
}

class _SubjectStatusRow extends StatelessWidget {
  const _SubjectStatusRow({
    required this.subject,
    required this.status,
    required this.templateId,
  });

  final Subject subject;
  final String? status;
  final String templateId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = '${subject.firstName} ${subject.lastName}';
    final (statusLabel, statusColor) = switch (status) {
      'completed' => (
        'Done',
        theme.colorScheme.primary,
      ),
      'draft' => (
        'In progress',
        theme.colorScheme.tertiary,
      ),
      _ => (
        'Not started',
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return ListTile(
      leading: PersonAvatar(name: fullName, photoUrl: subject.photoUrl),
      title: Text(fullName),
      subtitle: Text(
        statusLabel,
        style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
      ),
      trailing: Icon(
        status == SurveyResponseStatus.completed
            ? Icons.replay
            : Icons.arrow_forward,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () => context.push('/surveys/$templateId/take/${subject.id}'),
    );
  }
}
