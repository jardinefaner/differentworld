import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// All responses in the signed-in user's space for a given template.
typedef SurveyResponsesKey = ({String spaceId, String templateId});

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final surveyResponsesProvider = StreamProvider.autoDispose
    .family<List<SurveyResponse>, SurveyResponsesKey>((ref, key) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.surveysDao.watchForTemplate(
    spaceId: key.spaceId,
    templateId: key.templateId,
  );
});

/// The single response (if any) for a (template, subject) pair.
typedef SurveyResponseKey = ({String templateId, String subjectId});

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final surveyResponseProvider = StreamProvider.autoDispose
    .family<SurveyResponse?, SurveyResponseKey>((ref, key) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.surveysDao.watchForSubject(
    templateId: key.templateId,
    subjectId: key.subjectId,
  );
});

/// Status discriminator for `survey_responses.status`.
class SurveyResponseStatus {
  static const String draft = 'draft';
  static const String completed = 'completed';
}

/// In-memory representation of one kid's answers. The renderer holds
/// one of these as local state while the kid is taking the survey;
/// `SurveyActions.upsert` round-trips it to the DB as the JSONB blob.
class SurveyAnswers {
  SurveyAnswers([Map<String, dynamic>? raw])
      : _raw = raw == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(raw);

  factory SurveyAnswers.fromJson(String? json) {
    if (json == null || json.isEmpty) return SurveyAnswers();
    try {
      var decoded = jsonDecode(json);
      // Heal rows that landed on the server before the connector
      // started jsonDecoding 'answers' (pre-fix): jsonb stored a
      // string literal, so the first jsonDecode returns a String.
      // Decode once more and accept the result if it's a Map.
      if (decoded is String) {
        try {
          decoded = jsonDecode(decoded);
        } on FormatException {
          // Genuine string blob — fall through to empty.
        }
      }
      if (decoded is Map<String, dynamic>) return SurveyAnswers(decoded);
      if (decoded is Map) {
        return SurveyAnswers({
          for (final e in decoded.entries) e.key.toString(): e.value,
        });
      }
    } on FormatException {
      // fall through
    }
    return SurveyAnswers();
  }

  final Map<String, dynamic> _raw;

  /// Returns `0`, `1`, or `2` for an agree3 answer, or null if unset.
  int? agree3(String key) {
    final v = _raw[key];
    if (v is int) return (v >= 0 && v <= 2) ? v : null;
    return null;
  }

  /// Returns the option keys selected on a multiselect question.
  List<String> multiselect(String key) {
    final v = _raw[key];
    if (v is List) {
      return v.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  /// Returns the text typed for a text question; empty when unset.
  String text(String key) {
    final v = _raw[key];
    if (v is String) return v;
    return '';
  }

  void setAgree3(String key, int? value) {
    if (value == null) {
      _raw.remove(key);
    } else {
      _raw[key] = value.clamp(0, 2);
    }
  }

  void setMultiselect(String key, List<String> values) {
    if (values.isEmpty) {
      _raw.remove(key);
    } else {
      _raw[key] = values;
    }
  }

  void setText(String key, String value) {
    if (value.isEmpty) {
      _raw.remove(key);
    } else {
      _raw[key] = value;
    }
  }

  /// Whether a question has any answer recorded. For agree3 / text
  /// "answered" means non-null; for multiselect even an empty list is
  /// treated as "answered" once the user explicitly cleared it.
  bool isAnswered(SurveyQuestion q) {
    switch (q.kind) {
      case SurveyQuestionKind.agree3:
        return agree3(q.key) != null;
      case SurveyQuestionKind.multiselect:
        // multiselect is allowed to be empty intentionally — but the
        // question still needs a deliberate "I'm done" tap, which
        // the renderer requires before advancing.
        return _raw.containsKey(q.key);
      case SurveyQuestionKind.text:
        return text(q.key).trim().isNotEmpty;
    }
  }

  String toJson() => jsonEncode(_raw);
}

class SurveyActions {
  SurveyActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  /// Save the (possibly partial) answers under (templateId, subjectId).
  /// If `complete` is true, mark the response as completed; otherwise
  /// it stays a draft the kid can re-open later.
  Future<void> save({
    required String templateId,
    required String subjectId,
    required SurveyAnswers answers,
    required bool complete,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      throw StateError('No Space — cannot save a survey response.');
    }
    final db = await _ref.read(appDatabaseProvider.future);
    await db.surveysDao.upsert(
      id: _uuid.v4(),
      spaceId: spaceId,
      templateId: templateId,
      subjectId: subjectId,
      answersJson: answers.toJson(),
      status: complete ? 'completed' : 'draft',
      recordedBy: viewer.memberId,
      completedAt: complete ? DateTime.now() : null,
    );
  }

  /// Drop a response entirely (e.g. start fresh).
  Future<void> reset({
    required String templateId,
    required String subjectId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final existing = await db.surveysDao.findForSubject(
      templateId: templateId,
      subjectId: subjectId,
    );
    if (existing == null) return;
    await db.surveysDao.deleteById(existing.id);
  }
}

final surveyActionsProvider = Provider<SurveyActions>(SurveyActions.new);
