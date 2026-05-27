import 'package:flutter/foundation.dart';

/// Stable, code-defined survey templates. The DB stores one
/// `survey_responses` row per (subject, template_id); the questions
/// themselves live here so the analyzer can see the shapes and we
/// don't pay a migration to add a new question.
///
/// Promote to DB tables if/when a director wants to author surveys
/// in-app — until then this is the canonical shape.

/// Kinds of question the survey renderer knows how to render.
enum SurveyQuestionKind {
  /// Three smiley choice: Disagree / Kind of agree / Agree. Stored as
  /// int 0..2. Practice questions also use this kind.
  agree3,

  /// Multi-select checklist. Stored as `List<String>` (option keys).
  multiselect,

  /// Free-form text. Stored as `String` (may be empty). The UI shows
  /// a "say out loud" hint — for K-3rd, the instructor often types
  /// what the kid said.
  text,
}

/// A single question in a survey.
@immutable
class SurveyQuestion {
  const SurveyQuestion({
    required this.key,
    required this.kind,
    required this.prompt,
    this.options = const [],
    this.isPractice = false,
  });

  /// Stable string ID — answers are keyed by this in the JSONB blob.
  /// Renaming a question is fine; changing its key strands old
  /// answers, so don't.
  final String key;
  final SurveyQuestionKind kind;
  final String prompt;

  /// For [SurveyQuestionKind.multiselect], the list of options the
  /// user can pick. Each option has a stable key and a display label.
  final List<SurveyOption> options;

  /// Practice questions don't count toward the response's completion
  /// status; they're a warm-up so the kid understands the smileys.
  final bool isPractice;
}

@immutable
class SurveyOption {
  const SurveyOption({required this.key, required this.label});
  final String key;
  final String label;
}

/// A self-contained survey definition. The title shows on the entry
/// screen; the year on the list of past surveys.
@immutable
class SurveyTemplate {
  const SurveyTemplate({
    required this.id,
    required this.title,
    required this.year,
    required this.subtitle,
    required this.questions,
  });

  final String id;
  final String title;
  final String year;
  final String subtitle;
  final List<SurveyQuestion> questions;

  /// Real (non-practice) questions — used for completion progress.
  Iterable<SurveyQuestion> get scored =>
      questions.where((q) => !q.isPractice);
}

/// Registered survey templates. Add new ones here; the route + list
/// screen auto-pick them up.
abstract final class SurveyTemplates {
  static const basecamp2025 = SurveyTemplate(
    id: 'basecamp_2025_26',
    title: 'BASECamp Student Survey',
    year: '2025–26',
    subtitle: 'TK–3rd grade. Read each line out loud, '
        'kid picks a smiley.',
    questions: _basecampQuestions,
  );

  static const List<SurveyTemplate> all = [basecamp2025];

  static SurveyTemplate? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}

const _basecampQuestions = <SurveyQuestion>[
  // --- Practice (not scored) ---
  SurveyQuestion(
    key: 'practice_feeling',
    kind: SurveyQuestionKind.agree3,
    prompt: 'Today, I am feeling…',
    isPractice: true,
  ),
  SurveyQuestion(
    key: 'practice_pineapple',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I like pizza with pineapple on it.',
    isPractice: true,
  ),

  // --- Core agreement scale ---
  SurveyQuestion(
    key: 'made_friends',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I made new friends in program this year.',
  ),
  SurveyQuestion(
    key: 'friends_help',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I have friends here who help me if I am having a hard time.',
  ),
  SurveyQuestion(
    key: 'fun_learning',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I have fun learning at BASECamp.',
  ),
  SurveyQuestion(
    key: 'teachers_care',
    kind: SurveyQuestionKind.agree3,
    prompt: 'My BASECamp teachers care about me.',
  ),
  SurveyQuestion(
    key: 'teachers_greet',
    kind: SurveyQuestionKind.agree3,
    prompt: 'My BASECamp teachers greet me.',
  ),
  SurveyQuestion(
    key: 'happy_here',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I am happy to be here.',
  ),
  SurveyQuestion(
    key: 'feel_safe',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I feel safe here.',
  ),

  // --- Activities checklist ---
  SurveyQuestion(
    key: 'activities',
    kind: SurveyQuestionKind.multiselect,
    prompt: 'Check any of the activities you did this year in BASECamp.',
    options: [
      // Wave 145: option labels rewritten as full "Did you...?"
      // questions. Each option page renders this label as the main
      // prompt + auto-plays it via TTS, so the kid hears a complete
      // question instead of a sentence fragment. The same string
      // appears as the column header in the table-view CSV export.
      SurveyOption(
        key: 'handed_supplies',
        label: 'Did you help hand out supplies?',
      ),
      SurveyOption(
        key: 'asked_friends',
        label: 'Did you ask friends to join an activity with you?',
      ),
      SurveyOption(
        key: 'line_leader',
        label: 'Did you volunteer to be a line leader?',
      ),
      SurveyOption(
        key: 'chose_activity',
        label: 'Did you choose a group activity for everyone to do?',
      ),
      SurveyOption(
        key: 'helped_friend',
        label: 'Did you help a friend when they were having a bad day?',
      ),
      SurveyOption(
        key: 'shared_things',
        label: 'Did you share your things with others?',
      ),
      SurveyOption(
        key: 'reminded_rules',
        label: 'Did you remind others of the rules?',
      ),
    ],
  ),

  // --- More agreement scale ---
  SurveyQuestion(
    key: 'kept_learning_hard',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I kept learning even when it was hard.',
  ),
  SurveyQuestion(
    key: 'asked_questions',
    kind: SurveyQuestionKind.agree3,
    prompt: "I felt comfortable asking questions when I didn't understand "
        'something.',
  ),
  SurveyQuestion(
    key: 'tried_healthy_food',
    kind: SurveyQuestionKind.agree3,
    prompt: 'Because of BASECamp, I tried new food choices that '
        'were healthy for me.',
  ),
  SurveyQuestion(
    key: 'more_physical_activity',
    kind: SurveyQuestionKind.agree3,
    prompt: 'Because of BASECamp, I participate in more physical activity '
        '& movement (like sports, capoeira, etc.)',
  ),

  // --- Open-ended ---
  SurveyQuestion(
    key: 'something_learned_health',
    kind: SurveyQuestionKind.text,
    prompt: 'At BASECamp this year, something I learned about being '
        'healthy is…',
  ),
];
