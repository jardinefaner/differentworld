import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worlds.dart';

/// Builds the copy-pasteable parent message from a child's day (the
/// brief's Send screen). Pure + testable — no Riverpod, no context.
///
/// [world] is the RESOLVED match (the caller runs `resolveWorld` so the
/// message honors a world the class invented). Pass `day.world` for the
/// catalog-only resolution.
///
/// Shape (lines omitted when their data is absent):
///   {Name} was 🐬 Dolphin today.
///   They practiced play, echo, flow.
///   Word of the day: curious.
///   Note: built a tall tower with Mia.
///   Ask at dinner: What game did you play with a friend today?
String buildParentMessage({
  required String childName,
  required ActionWordsDay day,
  required WorldMatch? world,
}) {
  final lines = <String>[];
  final match = world;
  final w = match?.world;

  if (w != null) {
    lines.add('$childName was ${w.emoji} ${w.name} today.');
  } else if (match != null) {
    // A fresh world the class named (or hasn't yet).
    final named = day.worldName;
    lines.add(
      (named == null || named.isEmpty)
          ? '$childName discovered a brand-new world today.'
          : '$childName was 🌟 $named today.',
    );
  }

  final verbs = verbsByIds(day.verbPicks);
  if (verbs.isNotEmpty) {
    final list = verbs.map((v) => v.label.toLowerCase()).join(', ');
    lines.add('They practiced $list.');
  }

  if (day.wordOfDay != null) {
    lines.add('Word of the day: ${day.wordOfDay}.');
  }
  if (day.note != null) {
    lines.add('Note: ${day.note}');
  }

  final question = w?.dinnerQuestion ?? _freshDinnerQuestion(verbs);
  if (question != null) {
    lines.add('Ask at dinner: $question');
  }

  return lines.join('\n');
}

/// A sensible dinner question for a fresh world — built from the kid's
/// strongest verb so the family still gets a conversation starter.
String? _freshDinnerQuestion(List<Verb> verbs) {
  if (verbs.isEmpty) return null;
  const byVerb = <String, String>{
    'carry': 'What did you carry or move today?',
    'listen': 'Who did you really listen to today?',
    'play': 'What was the most fun thing you played today?',
    'spark': 'What gave you a big idea today?',
    'flow': 'What did you go with the flow on today?',
    'build': 'What did you build today?',
    'watch': 'What did you notice today that nobody else saw?',
    'wait': 'What did you wait patiently for today?',
    'solve': 'What tricky problem did you solve today?',
    'help': 'Who did you help today?',
    'echo': 'What did you repeat or remember today?',
    'shine': 'How did you shine today?',
  };
  return byVerb[verbs.first.id];
}
