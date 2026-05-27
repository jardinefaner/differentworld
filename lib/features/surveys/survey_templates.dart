import 'package:flutter/foundation.dart';

/// Stable, code-defined survey templates. The DB stores one
/// `survey_responses` row per take session; the questions themselves
/// live here so the analyzer can see the shapes and we don't pay a
/// migration to add a new question.
///
/// Wave 149: every question + option carries a Spanish translation
/// alongside the English one, so the kid can switch language at the
/// About-you page and have both text + TTS narration follow.
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

/// Language toggle for survey presentation + TTS playback.
enum SurveyLanguage {
  en('en', 'English', 'EN'),
  es('es', 'Español', 'ES');

  const SurveyLanguage(this.code, this.displayName, this.short);
  final String code;
  final String displayName;
  final String short;
}

/// A single question in a survey.
@immutable
class SurveyQuestion {
  const SurveyQuestion({
    required this.key,
    required this.kind,
    required this.prompt,
    required this.promptEs,
    this.options = const [],
    this.isPractice = false,
  });

  /// Stable string ID — answers are keyed by this in the JSONB blob.
  /// Renaming a question is fine; changing its key strands old
  /// answers, so don't.
  final String key;
  final SurveyQuestionKind kind;

  /// English prompt — the on-screen text + the TTS narration when the
  /// kid picks an English reader voice.
  final String prompt;

  /// Spanish prompt — paired with a Spanish Aura voice when the kid
  /// has the language toggle set to ES.
  final String promptEs;

  /// For [SurveyQuestionKind.multiselect], the list of options the
  /// user can pick. Each option has a stable key and a display label.
  final List<SurveyOption> options;

  /// Practice questions don't count toward the response's completion
  /// status; they're a warm-up so the kid understands the smileys.
  /// They're also exempt from the required-answer gate (Wave 149).
  final bool isPractice;

  /// Display + spoken text in the requested language. Falls back to
  /// English when the Spanish translation is empty (defensive — every
  /// shipped question has both).
  String promptFor(SurveyLanguage lang) {
    if (lang == SurveyLanguage.es && promptEs.isNotEmpty) return promptEs;
    return prompt;
  }
}

@immutable
class SurveyOption {
  const SurveyOption({
    required this.key,
    required this.label,
    required this.labelEs,
  });
  final String key;
  final String label;
  final String labelEs;

  String labelFor(SurveyLanguage lang) {
    if (lang == SurveyLanguage.es && labelEs.isNotEmpty) return labelEs;
    return label;
  }
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
    promptEs: 'Hoy me siento…',
    isPractice: true,
  ),
  SurveyQuestion(
    key: 'practice_pineapple',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I like pizza with pineapple on it.',
    promptEs: 'Me gusta la pizza con piña.',
    isPractice: true,
  ),

  // --- Belonging + relationships ---
  SurveyQuestion(
    key: 'made_friends',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I made new friends in program this year.',
    promptEs: 'Hice nuevos amigos en el programa este año.',
  ),
  SurveyQuestion(
    key: 'friends_help',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I have friends here who help me if I am having a hard time.',
    promptEs: 'Tengo amigos aquí que me ayudan si estoy pasando por un mal momento.',
  ),
  SurveyQuestion(
    key: 'fun_learning',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I have fun learning at BASECamp.',
    promptEs: 'Me divierto aprendiendo en BASECamp.',
  ),
  SurveyQuestion(
    key: 'teachers_care',
    kind: SurveyQuestionKind.agree3,
    prompt: 'My BASECamp teachers care about me.',
    promptEs: 'Mis maestros de BASECamp se preocupan por mí.',
  ),
  SurveyQuestion(
    key: 'teachers_greet',
    kind: SurveyQuestionKind.agree3,
    prompt: 'My BASECamp teachers greet me.',
    promptEs: 'Mis maestros de BASECamp me saludan.',
  ),
  SurveyQuestion(
    key: 'happy_here',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I am happy to be here.',
    promptEs: 'Estoy feliz de estar aquí.',
  ),
  SurveyQuestion(
    key: 'feel_safe',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I feel safe here.',
    promptEs: 'Me siento seguro aquí.',
  ),

  // --- Activities checklist ---
  SurveyQuestion(
    key: 'activities',
    kind: SurveyQuestionKind.multiselect,
    prompt: 'Check any of the activities you did this year in BASECamp.',
    promptEs: 'Marca cualquiera de las actividades que hiciste este año en BASECamp.',
    options: [
      // Wave 145 + 149: full "Did you...?" questions in both languages.
      SurveyOption(
        key: 'handed_supplies',
        label: 'Did you help hand out supplies?',
        labelEs: '¿Ayudaste a repartir materiales?',
      ),
      SurveyOption(
        key: 'asked_friends',
        label: 'Did you ask friends to join an activity with you?',
        labelEs: '¿Invitaste a tus amigos a hacer una actividad contigo?',
      ),
      SurveyOption(
        key: 'line_leader',
        label: 'Did you volunteer to be a line leader?',
        labelEs: '¿Te ofreciste para ser el líder de la fila?',
      ),
      SurveyOption(
        key: 'chose_activity',
        label: 'Did you choose a group activity for everyone to do?',
        labelEs: '¿Elegiste una actividad de grupo para que todos hicieran?',
      ),
      SurveyOption(
        key: 'helped_friend',
        label: 'Did you help a friend when they were having a bad day?',
        labelEs: '¿Ayudaste a un amigo cuando estaba pasando un mal día?',
      ),
      SurveyOption(
        key: 'shared_things',
        label: 'Did you share your things with others?',
        labelEs: '¿Compartiste tus cosas con los demás?',
      ),
      SurveyOption(
        key: 'reminded_rules',
        label: 'Did you remind others of the rules?',
        labelEs: '¿Le recordaste las reglas a los demás?',
      ),
    ],
  ),

  // --- More agreement scale ---
  SurveyQuestion(
    key: 'kept_learning_hard',
    kind: SurveyQuestionKind.agree3,
    prompt: 'I kept learning even when it was hard.',
    promptEs: 'Seguí aprendiendo incluso cuando era difícil.',
  ),
  SurveyQuestion(
    key: 'asked_questions',
    kind: SurveyQuestionKind.agree3,
    prompt: "I felt comfortable asking questions when I didn't understand "
        'something.',
    promptEs: 'Me sentí cómodo haciendo preguntas cuando no entendía algo.',
  ),
  SurveyQuestion(
    key: 'tried_healthy_food',
    kind: SurveyQuestionKind.agree3,
    prompt: 'Because of BASECamp, I tried new food choices that '
        'were healthy for me.',
    promptEs: 'Por BASECamp, probé nuevas comidas que eran saludables para mí.',
  ),
  SurveyQuestion(
    key: 'more_physical_activity',
    kind: SurveyQuestionKind.agree3,
    prompt: 'Because of BASECamp, I participate in more physical activity '
        '& movement (like sports, capoeira, etc.)',
    promptEs: 'Por BASECamp, participo en más actividad física y movimiento '
        '(como deportes, capoeira, etc.).',
  ),

  // --- Open-ended ---
  SurveyQuestion(
    key: 'something_learned_health',
    kind: SurveyQuestionKind.text,
    prompt: 'At BASECamp this year, something I learned about being '
        'healthy is…',
    promptEs: 'En BASECamp este año, algo que aprendí sobre estar saludable es…',
  ),
];
