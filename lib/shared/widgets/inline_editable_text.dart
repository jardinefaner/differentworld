import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tap-to-edit text that commits itself — the formless-CRUD atom.
///
/// Display mode renders [value] (or [placeholder] when empty) as read
/// content with a subtle edit affordance. Tapping enters a **spotlight**
/// edit mode (UX_DECISIONS §10 + the "immersive, not noisy" feedback):
/// an overlay scrim dims the rest of the screen to ~40% while the field
/// stays at its own position, rendered LIT above the scrim — so editing
/// one note doesn't fight the whole busy screen for attention. There is
/// no Save button and no draft (extends §1 to text; §4 optimistic).
///
/// The field stays where it lives; it only lifts to clear the keyboard
/// when it would otherwise be covered. Commit on keyboard "done"
/// (single-line), on blur, or by tapping the dimmed area. The committed
/// text is held in `_pending` until the parent's stream re-delivers it
/// (no flash). Local-first writes always reconcile; the parent mutator
/// owns persistence + the failure SnackBar (no rollback here).
///
/// Read-only viewers pass `editable: false` → plain styled text, no
/// affordance, no tap target.
class InlineEditableText extends StatefulWidget {
  const InlineEditableText({
    required this.value,
    required this.onCommit,
    this.placeholder = '',
    this.editable = true,
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

  /// Called with the trimmed new text whenever it differs from [value].
  /// The parent's mutator should write optimistically (local-first) and
  /// surface a SnackBar on failure — do NOT throw to roll back the UI.
  final Future<void> Function(String) onCommit;

  final TextStyle? style;
  final TextStyle? placeholderStyle;

  /// 1 = single line (commits on done/blur/scrim-tap). >1 = multiline
  /// (commits on blur/scrim-tap; Enter inserts a newline).
  final int maxLines;

  final String? semanticLabel;
  final TextCapitalization textCapitalization;

  /// Hint inside the field in edit mode (defaults to [placeholder]).
  final String? hintText;

  @override
  State<InlineEditableText> createState() => _InlineEditableTextState();
}

class _InlineEditableTextState extends State<InlineEditableText> {
  OverlayEntry? _overlay;
  TextEditingController? _ctl;
  FocusNode? _focus;

  /// The just-committed text, shown until the parent's stream delivers a
  /// new `value` — then dropped in `didUpdateWidget`. Prevents a 1-frame
  /// flash of the pre-edit value between the optimistic write and the
  /// Drift watch re-emitting.
  String? _pending;

  bool get _editing => _overlay != null;

  @override
  void didUpdateWidget(InlineEditableText old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) _pending = null;
  }

  @override
  void dispose() {
    // If still editing when torn down (e.g. parent route popped), pull
    // the overlay + dispose synchronously. ORDER MATTERS: null `_overlay`
    // (which clears `_editing`) and remove the focus listener BEFORE
    // removing the overlay, so the focus-lost event from its teardown
    // can't re-enter _commitAndExit / setState mid-dispose.
    final entry = _overlay;
    _overlay = null;
    _focus?.removeListener(_onFocusChange);
    entry?.remove();
    _focus?.dispose();
    _ctl?.dispose();
    super.dispose();
  }

  String get _displayValue => _pending ?? widget.value;

  void _enterEdit() {
    if (!widget.editable || _editing) return;
    final box = context.findRenderObject() as RenderBox?;
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (box == null || !box.hasSize || overlayState == null) return;

    final anchor = box.localToGlobal(Offset.zero) & box.size;
    _ctl = TextEditingController(text: _displayValue);
    _focus = FocusNode()..addListener(_onFocusChange);

    _overlay = OverlayEntry(
      builder: (ctx) => _SpotlightEditor(
        anchorRect: anchor,
        controller: _ctl!,
        focusNode: _focus!,
        style: widget.style ?? Theme.of(context).textTheme.bodyMedium,
        maxLines: widget.maxLines,
        hintText: widget.hintText ?? widget.placeholder,
        textCapitalization: widget.textCapitalization,
        onDismiss: _commitAndExit,
      ),
    );
    overlayState.insert(_overlay!);
    setState(() {}); // refresh the affordance (purely cosmetic)
  }

  void _onFocusChange() {
    if (_editing && !(_focus?.hasFocus ?? false)) _commitAndExit();
  }

  void _commitAndExit() {
    // Load-bearing dedup: all three dismiss paths (scrim tap, blur,
    // keyboard "done") funnel here; nulling `_overlay` below clears
    // `_editing` so the trailing calls no-op.
    if (!_editing) return;
    final text = (_ctl?.text ?? '').trim();
    final changed = text != _displayValue.trim();

    // Detach everything to locals, null the fields immediately (so a
    // fast re-tap can't be clobbered), then dispose next frame —
    // disposing a FocusNode inside its own listener is a footgun, and
    // removing an OverlayEntry mid-build can assert.
    final entry = _overlay;
    final ctl = _ctl;
    final focus = _focus;
    _overlay = null;
    _ctl = null;
    _focus = null;

    setState(() {
      if (changed) _pending = text;
    });

    if (changed) {
      // Fire-and-forget; the parent mutator persists (local-first) and
      // owns error reporting. The stream reconciles `_pending` away.
      // ignore: discarded_futures
      widget.onCommit(text);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      entry?.remove();
      focus?.removeListener(_onFocusChange);
      focus?.dispose();
      ctl?.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = widget.style ?? theme.textTheme.bodyMedium;

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

/// The overlay shown while a field is being edited: a tap-to-commit
/// scrim that dims the page to ~40%, plus the field itself rendered LIT
/// at its anchored position (lifted above the keyboard only when it
/// would otherwise be covered). Lives in the root Overlay so it floats
/// above the whole route.
class _SpotlightEditor extends StatefulWidget {
  const _SpotlightEditor({
    required this.anchorRect,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.maxLines,
    required this.hintText,
    required this.textCapitalization,
    required this.onDismiss,
  });

  final Rect anchorRect;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle? style;
  final int maxLines;
  final String? hintText;
  final TextCapitalization textCapitalization;
  final VoidCallback onDismiss;

  @override
  State<_SpotlightEditor> createState() => _SpotlightEditorState();
}

class _SpotlightEditorState extends State<_SpotlightEditor> {
  @override
  void initState() {
    super.initState();
    // `autofocus` raises the IME on this fresh field's first mount, but
    // force it explicitly too — programmatic focus alone can skip the
    // Android keyboard (CLAUDE.md interaction invariant #4).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.focusNode.requestFocus();
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final single = widget.maxLines <= 1;

    // Estimate the lit field's height so we can keep it clear of the
    // keyboard. Generous; the field scrolls internally past it.
    final lineH = (widget.style?.fontSize ?? 14) * 1.45;
    final estHeight = (widget.maxLines.clamp(1, 6)) * lineH + 28;
    final topSafe = media.padding.top + 8;
    final maxTop = media.size.height - media.viewInsets.bottom - estHeight - 12;

    var top = widget.anchorRect.top - 6; // offset the lit container padding
    if (top > maxTop) top = maxTop;
    if (top < topSafe) top = topSafe;

    return Stack(
      children: [
        // Dim scrim — fades in, tap anywhere to commit + dismiss.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 160),
              builder: (_, t, _) => ColoredBox(
                color: Colors.black.withValues(alpha: 0.6 * t),
              ),
            ),
          ),
        ),
        // The lit field, anchored at its place (nudged for the keyboard).
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          left: widget.anchorRect.left,
          top: top,
          width: widget.anchorRect.width,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                autofocus: true,
                style: widget.style,
                minLines: 1,
                maxLines: single ? 1 : widget.maxLines,
                textCapitalization: widget.textCapitalization,
                textInputAction: single ? TextInputAction.done : null,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.hintText,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: single ? (_) => widget.onDismiss() : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
