import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Add one more of something without leaving the page.
///
/// The affordance IS the input: a dashed "+" that becomes a field in place,
/// takes a value, commits it, and stays open for the next one. Adding
/// fourteen children should be fourteen keystrokes-and-enter, not fourteen
/// round trips through a form — and a setup page whose every "+" navigates
/// away is how one job became seven screens.
///
/// This is the shape CLAUDE.md's modal law asks for. A sheet here would be a
/// modal for a single field (the app's #1 bug class), and a route would lose
/// your place in a list you are working down. Neither is right for "one more
/// of the same thing".
///
/// Interaction rules it honours, each learned the hard way:
/// - `requestFocus` alone does not raise the Android IME — the explicit
///   `TextInput.show` is load-bearing, not belt-and-braces.
/// - The collapsed button and the open field carry stable keys, because a
///   widget that swaps children inside a Row/Wrap will otherwise poison its
///   siblings' Elements and close the keyboard mid-type.
/// - Submitting keeps focus and clears the field, so the next entry is
///   immediate. Empty submit closes — the natural "I'm done" gesture.
class InlineAdd extends StatefulWidget {
  const InlineAdd({
    required this.hint,
    required this.onSubmit,
    this.width = 200,
    super.key,
  });

  /// Placeholder naming what one entry is — "First name", "Block title".
  final String hint;

  /// Commit one value. Errors surface to the caller's snackbar; this widget
  /// stays open so a failed entry is not silently lost.
  final Future<void> Function(String value) onSubmit;

  final double width;

  @override
  State<InlineAdd> createState() => _InlineAddState();
}

class _InlineAddState extends State<InlineAdd> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openField() {
    setState(() => _open = true);
    // Post-frame, not a delay: the field does not exist until this build
    // completes, and no hardcoded duration is allowed to stand in for that.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      unawaited(
        SystemChannels.textInput.invokeMethod<void>('TextInput.show'),
      );
    });
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _open = false);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSubmit(value);
      if (!mounted) return;
      _controller.clear();
      // Stay open and focused — the common case is another one.
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_open) {
      return OutlinedButton.icon(
        key: const ValueKey('inline-add-button'),
        onPressed: _openField,
        icon: const Icon(Icons.add, size: 18),
        label: Text(widget.hint),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      );
    }
    return SizedBox(
      key: const ValueKey('inline-add-field'),
      width: widget.width,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: !_busy,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Done adding',
            onPressed: () => setState(() => _open = false),
          ),
        ),
        onSubmitted: (_) => unawaited(_submit()),
      ),
    );
  }
}
