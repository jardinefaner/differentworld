import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'surveys_dao.g.dart';

/// Drift mutators for survey responses (one row per subject+template).
///
/// Templates themselves are Dart-defined constants in
/// `lib/features/surveys/survey_templates.dart`; only the *answers*
/// land in the DB, keyed by question_key inside the `answers` JSONB.
@DriftAccessor(tables: [SurveyResponses])
class SurveysDao extends DatabaseAccessor<AppDatabase>
    with _$SurveysDaoMixin {
  SurveysDao(super.attachedDatabase);

  /// All responses in the space for one template — used by the survey
  /// list screen to render per-child completion status.
  Stream<List<SurveyResponse>> watchForTemplate({
    required String spaceId,
    required String templateId,
  }) {
    return (select(surveyResponses)
          ..where(
            (r) =>
                r.spaceId.equals(spaceId) &
                r.templateId.equals(templateId),
          )
          ..orderBy([(r) => OrderingTerm(expression: r.updatedAt)]))
        .watch();
  }

  /// The (at most one) response for a given subject + template.
  Stream<SurveyResponse?> watchForSubject({
    required String templateId,
    required String subjectId,
  }) {
    return (select(surveyResponses)
          ..where(
            (r) =>
                r.templateId.equals(templateId) &
                r.subjectId.equals(subjectId),
          ))
        .watchSingleOrNull();
  }

  Future<SurveyResponse?> findForSubject({
    required String templateId,
    required String subjectId,
  }) {
    return (select(surveyResponses)
          ..where(
            (r) =>
                r.templateId.equals(templateId) &
                r.subjectId.equals(subjectId),
          ))
        .getSingleOrNull();
  }

  Future<String> upsert({
    required String id,
    required String spaceId,
    required String templateId,
    required String subjectId,
    required String answersJson,
    required String status,
    String? recordedBy,
    DateTime? completedAt,
    String? voiceId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await findForSubject(
      templateId: templateId,
      subjectId: subjectId,
    );
    final completedIso = completedAt?.toUtc().toIso8601String();
    if (existing == null) {
      await into(surveyResponses).insert(
        SurveyResponsesCompanion.insert(
          id: id,
          spaceId: spaceId,
          templateId: templateId,
          subjectId: subjectId,
          status: status,
          recordedBy: Value(recordedBy),
          answers: answersJson,
          startedAt: now,
          completedAt: Value(completedIso),
          voiceId: Value(voiceId),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return id;
    }
    await (update(surveyResponses)
          ..where((r) => r.id.equals(existing.id)))
        .write(
      SurveyResponsesCompanion(
        status: Value(status),
        answers: Value(answersJson),
        recordedBy: recordedBy == null
            ? const Value.absent()
            : Value(recordedBy),
        completedAt: Value(completedIso),
        // voice id is opt-in on update: absent value = leave alone,
        // explicit value (including null) overwrites.
        voiceId: voiceId == null ? const Value.absent() : Value(voiceId),
        updatedAt: Value(now),
      ),
    );
    return existing.id;
  }

  Future<void> deleteById(String id) async {
    await (delete(surveyResponses)..where((r) => r.id.equals(id))).go();
  }
}
