import 'package:differentworld/features/surveys/survey_templates.dart';

/// Wave 149: in-flight UI strings for the survey-take screens that
/// need to follow the language toggle. Kept inline rather than going
/// through full `flutter gen-l10n` because (a) the surveys feature is
/// the only place we currently need bilingual UI, and (b) the strings
/// are tiny + read-only.
///
/// When we ship Spanish across the rest of the app (Lauren persona),
/// graduate these into `lib/l10n/*.arb` + the standard gen-l10n
/// pipeline. The shape mirrors what a single ARB file would say so
/// the migration is mechanical.
// ignore: use_enums
class SurveyStrings {
  const SurveyStrings._({
    required this.aboutYouTitle,
    required this.aboutYouSubtitle,
    required this.language,
    required this.reader,
    required this.ageBand,
    required this.grade,
    required this.school,
    required this.startReady,
    required this.startNeeds,
    required this.volume,
    required this.tapToHearAgain,
    required this.back,
    required this.next,
    required this.finish,
    required this.allDoneTitle,
    required this.allDoneBody,
    required this.almostThereTitle,
    required this.almostThereBody,
    required this.required,
    required this.practiceBadge,
  });

  static SurveyStrings of(SurveyLanguage lang) =>
      lang == SurveyLanguage.es ? _es : _en;

  final String aboutYouTitle;
  final String aboutYouSubtitle;
  final String language;
  final String reader;
  final String ageBand;
  final String grade;
  final String school;
  final String startReady;
  final String startNeeds;
  final String volume;
  final String tapToHearAgain;
  final String back;
  final String next;
  final String finish;
  final String allDoneTitle;
  final String allDoneBody;
  final String almostThereTitle;
  final String almostThereBody;

  /// Shown when a kid taps Next on a question they haven't answered
  /// yet. Soft, kid-friendly nudge.
  final String required;
  final String practiceBadge;

  static const _en = SurveyStrings._(
    aboutYouTitle: 'A few things about you',
    aboutYouSubtitle: 'Pick a language and reader, tell us a little, '
        'then tap Start.',
    language: 'Language',
    reader: 'Reader',
    ageBand: 'Age band',
    grade: 'Grade',
    school: 'School',
    startReady: 'Start',
    startNeeds: 'Choose a reader, age, grade, and school first',
    volume: 'Volume',
    tapToHearAgain: 'Tap to hear it again',
    back: 'Back',
    next: 'Next',
    finish: 'Finish',
    allDoneTitle: 'All done!',
    allDoneBody: 'Great job. Tap Finish to save your answers.',
    almostThereTitle: "You're almost there!",
    almostThereBody: 'Tap Back to look at any question again, or '
        "Finish to save what you've answered.",
    required: 'Tap a smiley first.',
    practiceBadge: 'PRACTICE',
  );

  static const _es = SurveyStrings._(
    aboutYouTitle: 'Un poco sobre ti',
    aboutYouSubtitle: 'Elige un idioma y un lector, cuéntanos un '
        'poco y luego presiona Empezar.',
    language: 'Idioma',
    reader: 'Lector',
    ageBand: 'Grupo de edad',
    grade: 'Grado',
    school: 'Escuela',
    startReady: 'Empezar',
    startNeeds: 'Elige un lector, edad, grado y escuela primero',
    volume: 'Volumen',
    tapToHearAgain: 'Toca para escucharlo otra vez',
    back: 'Atrás',
    next: 'Siguiente',
    finish: 'Terminar',
    allDoneTitle: '¡Listo!',
    allDoneBody: '¡Buen trabajo! Presiona Terminar para guardar '
        'tus respuestas.',
    almostThereTitle: '¡Ya casi!',
    almostThereBody: 'Toca Atrás para revisar cualquier pregunta, '
        'o Terminar para guardar lo que ya respondiste.',
    required: 'Toca una carita primero.',
    practiceBadge: 'PRÁCTICA',
  );
}
