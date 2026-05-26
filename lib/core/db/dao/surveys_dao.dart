import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'surveys_dao.g.dart';

/// Drift mutators for survey responses.
///
/// Wave 138: surveys are anonymous. Each "Start a survey" creates a
/// fresh row keyed by `id` (a client-generated UUID); there is no
/// resume mechanism, so we no longer key by (subject, template) and
/// the (subject_id, template_id) findForSubject lookup is gone.
/// Identity (age_band / grade / school) is captured on the first
/// page of the take flow.
///
/// Templates themselves are Dart-defined constants in
/// `lib/features/surveys/survey_templates.dart`; only the *answers*
/// land in the DB, keyed by question_key inside the `answers` JSONB.
@DriftAccessor(tables: [SurveyResponses, SurveyPickerOptions])
class SurveysDao extends DatabaseAccessor<AppDatabase>
    with _$SurveysDaoMixin {
  SurveysDao(super.attachedDatabase);

  /// All responses in the space for one template — used by the
  /// template detail screen (history strip) and the table view
  /// (one row per response).
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
          ..orderBy([
            (r) => OrderingTerm(
                  expression: r.updatedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  /// Wave 138: the single in-progress response for the take screen.
  /// The screen generates the response id in initState and watches
  /// this stream to seed itself with whatever has been autosaved so
  /// far. On a fresh launch the row doesn't exist yet (returns null)
  /// — the screen flushes its first autosave to create it.
  Stream<SurveyResponse?> watchById(String id) {
    return (select(surveyResponses)..where((r) => r.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<SurveyResponse?> findById(String id) {
    return (select(surveyResponses)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  /// Wave 138: upsert by `id`. Used by the take-screen autosave +
  /// final submit. The first call inserts; subsequent calls update.
  /// All callers pass the same id for the duration of one take
  /// session.
  Future<String> upsert({
    required String id,
    required String spaceId,
    required String templateId,
    required String answersJson,
    required String status,
    String? recordedBy,
    DateTime? completedAt,
    String? voiceId,
    String? ageBand,
    String? grade,
    String? school,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await findById(id);
    final completedIso = completedAt?.toUtc().toIso8601String();
    if (existing == null) {
      await into(surveyResponses).insert(
        SurveyResponsesCompanion.insert(
          id: id,
          spaceId: spaceId,
          templateId: templateId,
          // Wave 138: subjectId is nullable; anonymous rows leave
          // it absent.
          status: status,
          recordedBy: Value(recordedBy),
          answers: answersJson,
          startedAt: now,
          completedAt: Value(completedIso),
          voiceId: Value(voiceId),
          ageBand: Value(ageBand),
          grade: Value(grade),
          school: Value(school),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return id;
    }
    await (update(surveyResponses)..where((r) => r.id.equals(existing.id)))
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
        ageBand: ageBand == null ? const Value.absent() : Value(ageBand),
        grade: grade == null ? const Value.absent() : Value(grade),
        school: school == null ? const Value.absent() : Value(school),
        updatedAt: Value(now),
      ),
    );
    return existing.id;
  }

  Future<void> deleteById(String id) async {
    await (delete(surveyResponses)..where((r) => r.id.equals(id))).go();
  }

  // === Wave 135 — picker options catalog ===

  /// Stream every picker option for a program + dimension, sorted by
  /// the user's chosen sort_order then created_at. Used by the
  /// identity-capture page to render the existing chips.
  Stream<List<SurveyPickerOption>> watchPickerOptions({
    required String spaceId,
    required String dimension,
  }) {
    return (select(surveyPickerOptions)
          ..where(
            (o) => o.spaceId.equals(spaceId) & o.dimension.equals(dimension),
          )
          ..orderBy([
            (o) => OrderingTerm(expression: o.sortOrder),
            (o) => OrderingTerm(expression: o.createdAt),
          ]))
        .watch();
  }

  /// Insert (or upsert by unique(space_id, dimension, label)) a new
  /// option. The "+" button on the identity-capture page calls this.
  Future<String> addPickerOption({
    required String id,
    required String spaceId,
    required String dimension,
    required String label,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final trimmed = label.trim();
    // Idempotent if the label already exists for this program +
    // dimension. The server-side unique(space_id, dimension, label)
    // constraint also guards against a race; we check locally first
    // to avoid a wasted insert.
    final existing = await (select(surveyPickerOptions)
          ..where(
            (o) =>
                o.spaceId.equals(spaceId) &
                o.dimension.equals(dimension) &
                o.label.equals(trimmed),
          ))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    await into(surveyPickerOptions).insert(
      SurveyPickerOptionsCompanion.insert(
        id: id,
        spaceId: spaceId,
        dimension: dimension,
        label: trimmed,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }
}
