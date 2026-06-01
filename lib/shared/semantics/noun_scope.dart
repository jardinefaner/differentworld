import 'package:differentworld/shared/semantics/ui_frame.dart';
import 'package:flutter/widgets.dart';

/// The frame system (see docs/SEMANTIC_GRAPH.md). Wrap any domain entity
/// in a [NounScope] to declare it as a typed noun; a [NounRegistry]
/// provided by a [NounRegistryScope] ancestor can then [NounRegistry.capture]
/// a structural [UiFrame] of every mounted noun — where each one is, in
/// what state, with what actions — without ever taking a screenshot.
///
/// ```dart
/// NounScope(
///   noun: 'ScheduleBlock',
///   id: block.id,
///   actions: const ['tap', 'edit'],
///   state: {'editing': editing},
///   child: _BlockTile(...),
/// )
/// ```
///
/// NounScope is a pure passthrough — it adds no RenderObject and renders
/// exactly its child, so wrapping a widget never changes layout or
/// paint. Its only job is to register/deregister itself and expose its
/// child's live rect.

/// A mutable handle the registry holds for one mounted [NounScope]. Kept
/// mutable so state/actions updates don't churn the registry's Set.
class _NounHandle {
  _NounHandle(this.renderObject);

  String noun = '';
  String? id;
  String? key;
  List<String> actions = const [];
  Map<String, Object?> state = const {};

  /// Reads the scope's child render box live at capture time (null when
  /// the scope is unmounted / not yet laid out).
  final RenderObject? Function() renderObject;
}

class NounRegistry {
  final Set<_NounHandle> _handles = <_NounHandle>{};

  void _add(_NounHandle h) => _handles.add(h);
  void _remove(_NounHandle h) => _handles.remove(h);

  /// How many nouns are currently registered (mounted). Test-facing.
  @visibleForTesting
  int get count => _handles.length;

  /// Build a structural frame from every mounted [NounScope]. Reads each
  /// scope's RenderBox geometry — no rasterize, no repaint, no image
  /// buffer. Scopes that aren't attached or haven't been laid out are
  /// skipped (off-screen / not-yet-sized).
  UiFrame capture({Size viewport = Size.zero}) {
    final nodes = <UiNode>[];
    for (final h in _handles) {
      final ro = h.renderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final origin = ro.localToGlobal(Offset.zero);
      nodes.add(
        UiNode(
          noun: h.noun,
          id: h.id,
          key: h.key,
          rect: origin & ro.size,
          state: h.state,
          actions: h.actions,
        ),
      );
    }
    // Reading order: top-to-bottom, then left-to-right. Stable + matches
    // the logical focus order, so frame assertions read naturally.
    nodes.sort((a, b) {
      final dy = a.rect.top.compareTo(b.rect.top);
      return dy != 0 ? dy : a.rect.left.compareTo(b.rect.left);
    });
    return UiFrame(size: viewport, nodes: nodes);
  }
}

/// Provides a [NounRegistry] to the subtree. Place one above any region
/// you want to capture frames from (a screen body now; the app root once
/// more screens adopt NounScope).
class NounRegistryScope extends InheritedWidget {
  const NounRegistryScope({
    required this.registry,
    required super.child,
    super.key,
  });

  final NounRegistry registry;

  static NounRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NounRegistryScope>()?.registry;

  @override
  bool updateShouldNotify(NounRegistryScope old) => registry != old.registry;
}

class NounScope extends StatefulWidget {
  const NounScope({
    required this.noun,
    required this.child,
    this.id,
    this.nounKey,
    this.actions = const [],
    this.state = const {},
    super.key,
  });

  final String noun;
  final String? id;

  /// A stable identifier surfaced in the frame as [UiNode.key] — distinct
  /// from the widget [key]. Optional.
  final String? nounKey;

  final List<String> actions;
  final Map<String, Object?> state;
  final Widget child;

  @override
  State<NounScope> createState() => _NounScopeState();
}

class _NounScopeState extends State<NounScope> {
  _NounHandle? _handle;
  NounRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Non-subscribing read: the registry instance is stable, so we don't
    // need to rebuild when the InheritedWidget updates — we just need the
    // one post-initState call to register.
    final reg = NounRegistryScope.maybeOf(context);
    if (reg == _registry) {
      _syncHandle();
      return;
    }
    // Registry changed (or first mount): move our handle across.
    if (_handle != null && _registry != null) _registry!._remove(_handle!);
    _registry = reg;
    if (reg != null) {
      _handle ??= _NounHandle(
        () => mounted ? context.findRenderObject() : null,
      );
      _syncHandle();
      reg._add(_handle!);
    }
  }

  void _syncHandle() {
    final h = _handle;
    if (h == null) return;
    h
      ..noun = widget.noun
      ..id = widget.id
      ..key = widget.nounKey
      ..actions = widget.actions
      ..state = widget.state;
  }

  @override
  void didUpdateWidget(NounScope old) {
    super.didUpdateWidget(old);
    _syncHandle();
  }

  @override
  void dispose() {
    if (_handle != null && _registry != null) _registry!._remove(_handle!);
    _handle = null;
    _registry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
