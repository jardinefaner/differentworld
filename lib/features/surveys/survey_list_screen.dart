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
import 'package:differentworld/shared/widgets/person_avatar.dart';
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(
              title: 'Surveys',
              subtitle: 'Short check-ins kids can answer with smileys',
            ),
          ),
          for (final t in templates)
            _SurveyTemplateCard(template: t),
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
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    final responsesAsync = spaceId == null
        ? const AsyncValue<List<SurveyResponse>>.data([])
        : ref.watch(surveyResponsesProvider(
            (spaceId: spaceId, templateId: template.id),
          ));
    final responses = responsesAsync.value ?? const <SurveyResponse>[];
    final completed =
        responses.where((r) => r.status == 'completed').length;
    final inProgress =
        responses.where((r) => r.status == 'draft').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/surveys/${template.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.poll_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${template.year} · ${template.scored.length} questions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completed completed'
                        '${inProgress > 0 ? ' · $inProgress in progress' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
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
        body: Center(child: Text('Survey not found.')),
      );
    }
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    final subjectsAsync = ref.watch(subjectsInSpaceProvider);
    final responsesAsync = spaceId == null
        ? const AsyncValue<List<SurveyResponse>>.data([])
        : ref.watch(surveyResponsesProvider(
            (spaceId: spaceId, templateId: templateId),
          ));

    return EdgeScaffold(
      backFallbackRoute: '/surveys',
      actions: const [SyncStatusIndicator()],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/surveys/$templateId/table'),
        icon: const Icon(Icons.table_chart_outlined),
        label: const Text('Table view'),
      ),
      body: subjectsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load students',
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
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: subjects.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                final completed = responses
                    .where((r) => r.status == 'completed')
                    .length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: template.title,
                    subtitle:
                        '${template.year} · $completed / ${subjects.length} '
                        'completed',
                  ),
                );
              }
              final subject = subjects[i - 1];
              final status = statusBySubjectId[subject.id];
              return _SubjectStatusRow(
                subject: subject,
                status: status,
                templateId: template.id,
              );
            },
          );
        },
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
        status == 'completed' ? Icons.replay : Icons.arrow_forward,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () => context.push('/surveys/$templateId/take/${subject.id}'),
    );
  }
}
