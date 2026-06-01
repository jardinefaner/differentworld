import 'package:differentworld/features/runtime/noun_rule.dart';

/// The reactive, indexed rule evaluator (docs/SEMANTIC_GRAPH.md §1/§2).
///
/// Rules are indexed by `(nounType, event)` at construction, so a fired
/// event consults only the handful of matching rules — never the whole
/// set. This is the non-negotiable performance property: a ruleset that
/// grows must not slow a single write.
///
/// SEED SCOPE: [fire] is the pure core — given an event + the world it
/// happened in, it returns the [Effect]s to apply. In the real app a thin
/// adapter calls [fire] when a Drift change stream emits, and the caller
/// applies the effects through the DAO (keeping every action a
/// local-first, optimistic, offline-safe write). That adapter is the next
/// step; the pure core is proven first.
class RuleEngine {
  RuleEngine(List<Rule> rules) {
    for (final r in rules) {
      (_byTrigger[r.when.key] ??= <Rule>[]).add(r);
    }
  }

  final Map<String, List<Rule>> _byTrigger = {};

  /// How many rule conditions have been evaluated, ever. Test-facing —
  /// proves indexing (an unrelated trigger must not bump this).
  int rulesEvaluated = 0;

  /// Fire [event] in [world]. Returns the effects to apply, in order.
  ///
  /// [budget] caps how many effects one event may emit — a runaway /
  /// cyclic rule cannot wedge the evaluator (docs/SEMANTIC_GRAPH.md §3:
  /// "a malformed rule cannot wedge the evaluator").
  List<Effect> fire(Trigger event, World world, {int budget = 32}) {
    final candidates = _byTrigger[event.key] ?? const <Rule>[];
    final effects = <Effect>[];
    for (final rule in candidates) {
      rulesEvaluated++;
      if (!rule.condition.eval(world)) continue;
      for (final action in rule.actions) {
        if (effects.length >= budget) return effects;
        final from = world.resolve(action.fromRef);
        final target = world.resolve(action.targetRef);
        if (from == null || target == null) continue;
        effects.add((
          targetType: target.type,
          targetId: target.id,
          path: action.path,
          value: from.read(action.fromPath),
        ));
      }
    }
    return effects;
  }
}

/// Apply [effects] to a noun's mutable prop map — the seed's stand-in for
/// the DAO write. Returns the new props. In the app, each effect routes
/// through the matching DAO `update_` (local-first, uuid client-side).
Map<String, Object?> applyEffects(Noun noun, List<Effect> effects) {
  final next = Map<String, Object?>.of(noun.props);
  for (final e in effects) {
    if (e.targetType == noun.type && e.targetId == noun.id) {
      next[e.path] = e.value;
    }
  }
  return next;
}
