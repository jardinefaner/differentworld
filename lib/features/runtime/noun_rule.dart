/// The noun/rule/action value types for the semantic-graph runtime
/// (docs/SEMANTIC_GRAPH.md §1). Everything here is plain data — a rule is
/// a row, not code — so rules can eventually be authored by users and
/// synced like any other noun.
///
/// SEED SCOPE: pure value types + a closed, NON-Turing-complete condition
/// vocabulary. No persistence, no Drift wiring, no synced table yet — the
/// RuleEngine is proven against the hardcoded live-block tag first. The
/// reactive adapter (fire when a Drift stream emits) and the
/// six-place synced-table checklist come only once the feel is proven.
library;

/// A typed entity snapshot the runtime reasons over — the in-memory shape
/// of a noun (an Entry, a ScheduleBlock…). Carries id + a flat prop bag.
class Noun {
  const Noun(this.type, this.id, [this.props = const {}]);

  final String type;
  final String id;
  final Map<String, Object?> props;

  /// `read('id')` returns the id; any other path reads [props].
  Object? read(String path) => path == 'id' ? id : props[path];
}

/// The world an event happens in: the [subject] the event is about (the
/// new Entry) plus named [context] nouns a condition/action can reference
/// (e.g. `'liveBlock'`). A context entry may be null (no block is live).
class World {
  const World({required this.subject, this.context = const {}});

  final Noun subject;
  final Map<String, Noun?> context;

  /// Resolve a reference name to a noun. `'subject'` is the event's
  /// subject; everything else is a [context] lookup.
  Noun? resolve(String ref) => ref == 'subject' ? subject : context[ref];
}

/// What makes a rule fire: a noun type + an event on it, e.g.
/// `(Entry, created)`. The engine indexes rules by [key].
class Trigger {
  const Trigger({required this.nounType, required this.event});

  final String nounType;
  final String event;

  String get key => '$nounType/$event';
}

/// A closed condition vocabulary — intentionally NOT Turing-complete (the
/// guard against the inner-platform effect, docs/SEMANTIC_GRAPH.md §2). A
/// rule that needs real computation is a hardcoded capability, not data.
sealed class Condition {
  const Condition();
  bool eval(World world);
}

class Always extends Condition {
  const Always();
  @override
  bool eval(World world) => true;
}

/// True when the referenced context noun is present (e.g. a block is live).
class Exists extends Condition {
  const Exists(this.ref);
  final String ref;
  @override
  bool eval(World world) => world.resolve(ref) != null;
}

/// True when `ref.path` equals [value].
class Eq extends Condition {
  const Eq(this.ref, this.path, this.value);
  final String ref;
  final String path;
  final Object? value;
  @override
  bool eval(World world) => world.resolve(ref)?.read(path) == value;
}

class And extends Condition {
  const And(this.parts);
  final List<Condition> parts;
  @override
  bool eval(World world) => parts.every((c) => c.eval(world));
}

class Not extends Condition {
  const Not(this.inner);
  final Condition inner;
  @override
  bool eval(World world) => !inner.eval(world);
}

/// An action as data: copy `from.fromPath` into `target.path`. Resolved
/// by the engine against the [World] into a concrete [Effect] the caller
/// applies through the normal DAO layer (so every action stays a
/// local-first Drift write).
class SetProp {
  const SetProp({
    required this.targetRef,
    required this.path,
    required this.fromRef,
    required this.fromPath,
  });

  final String targetRef; // e.g. 'subject'
  final String path; // e.g. 'scheduleBlockId'
  final String fromRef; // e.g. 'liveBlock'
  final String fromPath; // e.g. 'id'
}

/// The concrete mutation the engine emits — "set Entry e1's
/// scheduleBlockId to b1". A record, so it has structural equality (the
/// test can assert an effect equals the hardcoded path's output).
typedef Effect = ({
  String targetType,
  String targetId,
  String path,
  Object? value,
});

/// A rule: WHEN [when] fires, IF [condition] holds, THEN apply [actions].
/// Plain data — the live-block auto-tag is one of these.
class Rule {
  const Rule({
    required this.id,
    required this.when,
    required this.actions,
    this.condition = const Always(),
  });

  final String id;
  final Trigger when;
  final Condition condition;
  final List<SetProp> actions;
}
