import 'dart:ui' show Rect, Size;

/// A structural snapshot of what's on screen — the "frame instead of a
/// picture" (see docs/SEMANTIC_GRAPH.md). Each [UiNode] is a typed noun
/// with its global rect, state, and afforded actions, computed from the
/// render tree — never rasterized. A frame is a few KB of data; a
/// screenshot is megabytes + a GPU encode.
///
/// Seed scope: a FLAT list of nodes (no parent/child nesting yet) sorted
/// top-to-bottom, left-to-right — the natural reading / focus order.
/// Hierarchy is a follow-up; the flat frame already answers "where is
/// noun X, in what state".
class UiFrame {
  const UiFrame({required this.size, required this.nodes});

  /// The viewport the nodes were laid out in.
  final Size size;

  /// Every mounted, laid-out noun, in reading order.
  final List<UiNode> nodes;

  Iterable<UiNode> whereNoun(String noun) => nodes.where((n) => n.noun == noun);

  /// The node bound to ([noun], [id]), or null if it isn't on screen.
  UiNode? byId(String noun, String id) {
    for (final n in nodes) {
      if (n.noun == noun && n.id == id) return n;
    }
    return null;
  }

  /// PII-safe by construction: carries ids + structural state only, never
  /// names / photos / narrative. Safe to log.
  Map<String, Object?> toJson() => {
    'size': [size.width, size.height],
    'nodes': [for (final n in nodes) n.toJson()],
  };
}

class UiNode {
  const UiNode({
    required this.noun,
    required this.rect,
    this.id,
    this.key,
    this.state = const {},
    this.actions = const [],
  });

  /// The entity type — 'ScheduleBlock', 'OmniboxBar', 'PersonAvatar'.
  final String noun;

  /// The domain row this node is bound to, when any (block.id, etc.).
  /// The frame keys on (noun, id); scroll/resize move [rect], never this.
  final String? id;

  /// The stable ValueKey on the widget, if it carries one.
  final String? key;

  /// Global bounds: `renderBox.localToGlobal(Offset.zero) & size`.
  final Rect rect;

  /// Structural state — {focused, selected, editing, empty, tone…}. Never
  /// content (no names, no narrative).
  final Map<String, Object?> state;

  /// What this noun affords here — ['tap','edit','delete'].
  final List<String> actions;

  Map<String, Object?> toJson() => {
    'noun': noun,
    if (id != null) 'id': id,
    if (key != null) 'key': key,
    'rect': [rect.left, rect.top, rect.width, rect.height],
    if (state.isNotEmpty) 'state': state,
    if (actions.isNotEmpty) 'actions': actions,
  };
}
