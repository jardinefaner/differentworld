import 'package:flutter/foundation.dart';

/// One of a world's three rules. Every kid hears all three; the rule whose
/// [verbs] overlap a kid's daily picks is THEIRS this week — "Leah picked
/// WAIT, so 'the slow things outlast the fast' is her rule" (docs/WORLD.md).
/// The world sets the rules; the verbs decide which one matters most to whom.
@immutable
class WorldRule {
  const WorldRule(this.text, this.verbs);
  final String text;

  /// The verb ids this rule speaks to.
  final List<String> verbs;
}

/// Three rules per curriculum world (keyed by the world id in
/// ten_worlds.json), each tagged to the verbs it emphasizes.
const Map<String, List<WorldRule>> kWorldRules = {
  'me': [
    WorldRule('You are a whole country — know yourself', ['watch', 'shine']),
    WorldRule('Your habits are your culture', ['build', 'carry']),
    WorldRule('Name it to claim it', ['spark', 'shine']),
  ],
  'stories': [
    WorldRule('The hero tries three times before they succeed', ['wait', 'solve']),
    WorldRule('Something has to change', ['spark', 'build']),
    WorldRule('Every story needs a problem', ['solve', 'watch']),
  ],
  'nature': [
    WorldRule('Everything is connected', ['help', 'echo']),
    WorldRule('Nothing is wasted', ['carry', 'build']),
    WorldRule('The slow things outlast the fast things', ['wait', 'watch']),
  ],
  'water': [
    WorldRule('Take the shape of whatever holds you', ['flow', 'echo']),
    WorldRule('Don’t fight the obstacle — go around it', ['flow', 'solve']),
    WorldRule('Be patient enough to carve a canyon', ['wait', 'watch']),
  ],
  'music': [
    WorldRule('The silence matters as much as the notes', ['wait', 'listen']),
    WorldRule('The rhythm holds everything together', ['build', 'carry']),
    WorldRule('You can’t make a mistake if you keep playing', ['play', 'flow']),
  ],
  'space': [
    WorldRule('Everything orbits something', ['help', 'echo']),
    WorldRule('Some things travel for years before they land', ['wait', 'spark']),
    WorldRule('The dark is full of things we haven’t found', ['watch', 'shine']),
  ],
  'dreams': [
    WorldRule('Impossible is normal', ['spark', 'play']),
    WorldRule('Anything can happen', ['flow', 'spark']),
    WorldRule('The scariest dreams teach you the most', ['watch', 'solve']),
  ],
  'time': [
    WorldRule('It only goes forward', ['flow', 'wait']),
    WorldRule('Everyone gets the same amount each day', ['carry', 'help']),
    WorldRule('The things that last were built slowly', ['build', 'wait']),
  ],
  'feelings': [
    WorldRule('All feelings are real', ['listen', 'shine']),
    WorldRule('No feeling lasts forever', ['wait', 'flow']),
    WorldRule('Name it — don’t pretend it isn’t there', ['shine', 'help']),
  ],
  'us': [
    WorldRule('Pick three verbs, do them, discover who you are', ['spark', 'build']),
    WorldRule('There are no strangers here', ['help', 'echo']),
    WorldRule('The practice travels with you', ['carry', 'shine']),
  ],
};

List<WorldRule> rulesForWorld(String worldId) =>
    kWorldRules[worldId] ?? const [];

/// The kid's rule this week: of the world's three rules, the one whose verbs
/// best overlap their [picks]. Ties break toward the earlier rule; no
/// overlap → null (none claimed yet — every kid still hears all three).
WorldRule? ruleForVerbs(String worldId, Iterable<String> picks) {
  final rules = rulesForWorld(worldId);
  if (rules.isEmpty) return null;
  final pickSet = picks.toSet();
  WorldRule? best;
  var bestOverlap = 0;
  for (final rule in rules) {
    final overlap = rule.verbs.where(pickSet.contains).length;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      best = rule;
    }
  }
  return best;
}
