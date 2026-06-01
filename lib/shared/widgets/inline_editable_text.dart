import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Tap-to-edit text that commits itself — the formless-CRUD atom.
///
/// The text edits **in place** — it is never replaced by a copy. Tapping
/// turns the read text into a real `TextField` at the exact same spot,
/// same font, no jump. The only thing that overlays is the **dim**: two
/// full-width gradient bands above and below the field that feather into
/// the lit row and TRACK the field as the keyboard scrolls it. So it
/// reads as "this row stayed lit while everything else softly dimmed" —
/// a highlight, not a new widget (the "tame it / full width / not a new
/// widget" feedback). Tap the dim, blur, or press done to commit.
///
/// No Save button, no draft — extends UX_DECISIONS §1 (auto-save) to
/// text, §4 (optimistic; reconcile via the stream). The committed text
/// is held in `_pending` until the parent's stream re-delivers it (no
/// flash). Local-first writes always reconcile; the parent mutator owns
/// persistence + the failure SnackBar (no rollback here).
///
/// Read-only viewers pass `editable: false` → plain styled text.
class InlineEditableText extends StatefulWidget {
  const InlineEditableText({
    required this.value,
    required this.onCommit,
    this.placeholder = '',
    this.editable = true,
    this.clearable = true,
    this.style,
    this.placeholderStyle,
    this.maxLines = 1,
    this.semanticLabel,
    this.textCapitalization = TextCapitalization.sentences,
    this.hintText,
    super.key,
  });

  final String value;
  final String placeholder;
  final bool editable;

  /// When false, committing an empty field is a no-op — the prior value
  /// is kept rather than written as an empty string. Use for fields that
  /// should always carry a name (a block title falls back to its
  /// activity label, never to blank). Default true preserves
  /// clear-to-empty (e.g. a child's free-text Notes).
  final bool clearable;

  /// Called with the trimmed new text whenever it differs from [value].
  /// The parent's mutator should write optimistically (local-first) and
  /// surface a SnackBar on failure — do NOT throw to roll back the UI.
  final Future<void> Function(String) onCommit;

  final TextStyle? style;
  final TextStyle? placeholderStyle;

  /// 1 = single line (commits on done/blur/dim-tap). >1 = multiline
  /// (commits on blur/dim-tap; Enter inserts a newline).
  final int maxLines;

  final String? semanticLabel;
  final TextCapitalization textCapitalization;

  /// Hint inside the field in edit mode (defaults to [placeholder]).
  final String? hintText;

  @override
  State<InlineEditableText> createState() => _InlineEditableTextState();
}

class _InlineEditableTextState extends State<InlineEditableText> {
  bool _editing = false;
  TextEditingController? _ctl;
  FocusNode? _focus;
  OverlayEntry? _dim;

  /// On the editing TextField so the dim overlay can read its live rect.
  final GlobalKey _fieldKey = GlobalKey();

  /// The just-committed text, shown until the parent's stream delivers a
  /// new `value` — then dropped in didUpdateWidget. Prevents a 1-frame
  /// flash of the pre-edit value.
  String? _pending;

  @override
  void didUpdateWidget(InlineEditableText old) {
    super.didUpdateWidget(old);
    // Drop the optimistic `_pending` only once the parent's stream has
    // caught up to exactly what we committed. Clearing on ANY value
    // change would, during a rapid second edit, snap the display back to
    // the first write while the second is still in flight.
    if (_pending != null && widget.value == _pending) _pending = null;
  }

  @override
  void dispose() {
    // Order matters: detach the listener + null `_dim` (clears `_editing`)
    // before removing the overlay, so a teardown focus-lost can't
    // re-enter _commitAndExit/setState mid-dispose.
    final dim = _dim;
    _dim = null;
    _focus?.removeListener(_onFocusChange);
    dim?.remove();
    _focus?.dispose();
    _ctl?.dispose();
    super.dispose();
  }

  String get _displayValue => _pending ?? widget.value;

  void _enterEdit() {
    if (!widget.editable || _editing) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _ctl = TextEditingController(text: _displayValue);
    _focus = FocusNode()..addListener(_onFocusChange);
    _dim = OverlayEntry(
      builder: (_) => _DimAround(fieldKey: _fieldKey, onDismiss: _commitAndExit),
    );
    overlay.insert(_dim!);
    setState(() => _editing = true);
    // `autofocus` raises the keyboard, but force it (CLAUDE.md invariant
    // #4: requestFocus alone can skip the Android IME).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      _focus?.requestFocus();
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    });
  }

  void _onFocusChange() {
    if (_editing && !(_focus?.hasFocus ?? false)) _commitAndExit();
  }

  void _commitAndExit() {
    // Load-bearing dedup: dim-tap, blur, and "done" all funnel here;
    // nulling `_dim` below clears `_editing` so the rest no-op.
    if (!_editing) return;
    final text = (_ctl?.text ?? '').trim();
    // When the field must keep a value (clearable == false), an empty
    // commit is a no-op: exit edit, keep the prior text. Stops a
    // select-all-delete from silently wiping a name.
    final emptyNoop = !widget.clearable && text.isEmpty;
    final changed = !emptyNoop && text != _displayValue.trim();

    final dim = _dim;
    final ctl = _ctl;
    final focus = _focus;
    _dim = null;
    _ctl = null;
    _focus = null;

    setState(() {
      _editing = false;
      if (changed) _pending = text;
    });

    if (changed) {
      // Fire-and-forget; the parent mutator persists (local-first).
      // ignore: discarded_futures
      widget.onCommit(text);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      dim?.remove();
      focus?.removeListener(_onFocusChange);
      focus?.dispose();
      ctl?.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = widget.style ?? theme.textTheme.bodyMedium;

    if (_editing) {
      final single = widget.maxLines <= 1;
      return TextField(
        key: _fieldKey,
        controller: _ctl,
        focusNode: _focus,
        autofocus: true,
        style: baseStyle,
        minLines: 1,
        maxLines: single ? 1 : widget.maxLines,
        textCapitalization: widget.textCapitalization,
        textInputAction: single ? TextInputAction.done : null,
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText ?? widget.placeholder,
          border: InputBorder.none,
          // Mirror the read affordance's vertical padding so the text
          // lands on the same baseline (no jump on enter).
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
        ),
        onSubmitted: single ? (_) => _commitAndExit() : null,
      );
    }

    final isEmpty = _displayValue.trim().isEmpty;
    final placeholderStyle = widget.placeholderStyle ??
        baseStyle?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        );
    final content = Text(
      isEmpty ? widget.placeholder : _displayValue,
      style: isEmpty ? placeholderStyle : baseStyle,
    );

    if (!widget.editable) {
      return Semantics(label: widget.semanticLabel, child: content);
    }

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: InkWell(
        onTap: _enterEdit,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: content),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dim while editing: two full-width gradient bands above and below
/// the live field, feathered into the lit row. A ticker re-reads the
/// field's rect every frame so the dim TRACKS it when the keyboard
/// scrolls the field. Tapping a band commits.
class _DimAround extends StatefulWidget {
  const _DimAround({required this.fieldKey, required this.onDismiss});

  final GlobalKey fieldKey;
  final VoidCallback onDismiss;

  @override
  State<_DimAround> createState() => _DimAroundState();
}

class _DimAroundState extends State<_DimAround>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _fade = 0;

  // The field's last sampled rect on screen. Cached in state (not re-read
  // in build) so a rebuild that isn't a real move is free, and so the
  // tick can compare against it to decide whether anything changed.
  Offset? _origin;
  double? _height;

  // Tamed peak dim (the rows farthest from the field). The gradient
  // feathers this to nothing at the lit band, so the edit row keeps its
  // own brightness and the transition blends instead of cropping.
  static const double _peak = 0.5;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    unawaited(_ticker.start());
  }

  void _tick(Duration elapsed) {
    final t = (elapsed.inMilliseconds / 160).clamp(0.0, 1.0);
    final box =
        widget.fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final hasBox = box != null && box.hasSize;
    final origin = hasBox ? box.localToGlobal(Offset.zero) : null;
    final height = hasBox ? box.size.height : null;
    // The ticker runs every frame so the dim TRACKS the field while the
    // keyboard animates it up (a hard stop at t==1 would freeze the dim
    // mid-rise, then it'd lag the field). But only rebuild when the fade
    // or the field's rect actually changes — once both settle, setState
    // stops firing and the gradient bands cost nothing per frame. The
    // bare tick (geometry read + compare, no allocation) is negligible.
    if (t == _fade && origin == _origin && height == _height) return;
    setState(() {
      _fade = t;
      _origin = origin;
      _height = height;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final origin = _origin;
    final height = _height;
    if (origin == null || height == null) return const SizedBox.shrink();
    final bandTop = origin.dy;
    final bandBottom = origin.dy + height;
    final alpha = _peak * _fade;

    Widget band({required bool above}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                // Dark at the screen edge, feathering to transparent as
                // it approaches the lit band.
                begin: above ? Alignment.topCenter : Alignment.bottomCenter,
                end: above ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: alpha),
                  Colors.black.withValues(alpha: alpha),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.65, 1.0],
              ),
            ),
          ),
        );

    // RepaintBoundary isolates the gradient repaint from the route
    // content underneath during the fade / keyboard-track frames.
    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bandTop,
            child: band(above: true),
          ),
          Positioned(
            top: bandBottom,
            left: 0,
            right: 0,
            bottom: 0,
            child: band(above: false),
          ),
        ],
      ),
    );
  }
}
