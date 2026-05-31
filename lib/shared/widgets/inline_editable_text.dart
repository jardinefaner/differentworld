import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tap-to-edit text that commits itself — the formless-CRUD atom.
///
/// Display mode renders [value] (or [placeholder] when empty) as read
/// content with a subtle edit affordance. Tapping enters edit mode: an
/// inline `TextField` seeded with the current value, styled identically
/// (WYSIWYG — the display format IS the input). The edit COMMITS on
/// done/blur via [onCommit]; there is no Save button and no draft. This
/// extends `docs/UX_DECISIONS §1` (auto-save toggles) to text and
/// follows §4 (optimistic; reconcile via the stream).
///
/// **Optimism without flash.** After a commit that changed the value the
/// new text is held in `_pending` and shown until the parent's stream
/// delivers it back (cleared in `didUpdateWidget`). So there's no
/// one-frame flicker of the pre-edit value. Writes are local-first
/// (Drift → PowerSync), so the local stream always reconciles; a
/// server-side rejection surfaces via the sync banner, not here. If
/// [onCommit] throws, the parent shows a SnackBar (§4 — no rollback).
///
/// **Read-only** viewers pass `editable: false` → plain styled text, no
/// affordance, no tap target (matches the current display for guardians
/// / non-editors).
///
/// Single-line ([maxLines] == 1) commits on the keyboard "done" action
/// or on blur. Multiline commits on blur only (Enter inserts a newline).
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

  /// 1 = single line (commits on done/blur). >1 = multiline (commits on
  /// blur; Enter inserts a newline).
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

  /// The just-committed text, shown until the parent's stream delivers a
  /// new `value` — then dropped in `didUpdateWidget`. Prevents a 1-frame
  /// flash of the pre-edit value between the optimistic write and the
  /// Drift watch re-emitting.
  String? _pending;

  @override
  void didUpdateWidget(InlineEditableText old) {
    super.didUpdateWidget(old);
    // The stream delivered a new value — trust it and drop the optimistic
    // hold (covers both "our write landed" and "someone else edited").
    if (widget.value != old.value) _pending = null;
  }

  @override
  void dispose() {
    _focus?.removeListener(_onFocusChange);
    _focus?.dispose();
    _ctl?.dispose();
    super.dispose();
  }

  String get _displayValue => _pending ?? widget.value;

  void _enterEdit() {
    if (!widget.editable || _editing) return;
    _ctl = TextEditingController(text: _displayValue);
    _focus = FocusNode()..addListener(_onFocusChange);
    setState(() => _editing = true);
    // `autofocus: true` raises the Android IME on the field's first
    // mount, but RE-entering edit mode on a field inside a scrollable
    // can have Android treat it as focus-already-held and skip the
    // keyboard (CLAUDE.md interaction invariant #4: requestFocus alone
    // doesn't show the IME). Force it up once the field has mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      _focus?.requestFocus();
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    });
  }

  void _onFocusChange() {
    // Blur while editing = commit. (`done` also routes here after it
    // drops focus; the `!_editing` guard in _commitAndExit dedupes.)
    if (_editing && !(_focus?.hasFocus ?? false)) _commitAndExit();
  }

  void _commitAndExit() {
    if (!_editing) return;
    final text = (_ctl?.text ?? '').trim();
    final changed = text != _displayValue.trim();

    // Detach the live controllers IMMEDIATELY so a fast re-tap that
    // creates fresh ones can't be clobbered by the deferred dispose
    // below. Dispose the captured (old) instances next frame — disposing
    // a FocusNode inside its own listener is a footgun.
    final oldCtl = _ctl;
    final oldFocus = _focus;
    _ctl = null;
    _focus = null;

    setState(() {
      _editing = false;
      if (changed) _pending = text;
    });

    if (changed) {
      // Fire-and-forget; the parent mutator persists (local-first) and
      // owns error reporting. The stream reconciles `_pending` away.
      // ignore: discarded_futures
      widget.onCommit(text);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldFocus?.removeListener(_onFocusChange);
      oldFocus?.dispose();
      oldCtl?.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = widget.style ?? theme.textTheme.bodyMedium;

    if (_editing) {
      final single = widget.maxLines <= 1;
      return TextField(
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
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          hintText: widget.hintText ?? widget.placeholder,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
