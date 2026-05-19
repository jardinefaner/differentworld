import 'dart:async';

import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drop a quick "I noticed…" into the inbox.
///
/// Saves on EVERY keystroke through a serialized `Future` chain, so a
/// swipe-to-dismiss never loses the last character the user typed. The
/// first non-empty keystroke INSERTs the row; later keystrokes UPDATE
/// it. We hold an [CaptureActions] instance captured at initState so
/// any in-flight write completes safely even after the widget
/// unmounts (the chain references the actions instance, not the
/// sheet's `ref`).
Future<void> showCaptureSheet(BuildContext context) async {
  unawaited(HapticFeedback.selectionClick());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CaptureSheet(),
  );
}

class _CaptureSheet extends ConsumerStatefulWidget {
  const _CaptureSheet();

  @override
  ConsumerState<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<_CaptureSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// The actions instance is read once at mount and stays alive for
  /// the chain's lifetime, even after the widget is gone.
  late final CaptureActions _actions;

  /// Serialized chain of write Futures. Each keystroke appends its
  /// own `then(...)` so writes happen in the order they were typed.
  /// If a save is in flight when the sheet dismisses, the chain
  /// continues running in the background — no data loss.
  Future<void> _saveChain = Future<void>.value();

  /// The id of this sheet's capture row, after the first non-empty
  /// save. Subsequent saves UPDATE this row.
  String? _captureId;

  /// Set to `true` while a save round-trip is in flight, so the
  /// "Saved" chip can flash green.
  bool _savedFlash = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _actions = ref.read(captureActionsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _ctrl.removeListener(_onChanged);
    // Schedule one last cleanup: if the user opened the sheet, never
    // typed anything meaningful, and dismissed it — hard-delete the
    // shell row so the inbox stays tidy. Capture the id here because
    // `this._captureId` may be read by the chain after super.dispose().
    final id = _captureId;
    final lastText = _ctrl.text;
    if (id != null && lastText.trim().isEmpty) {
      _saveChain = _saveChain.then((_) => _actions.discardEmpty(id));
    }
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    // Capture the current text NOW; never read _ctrl inside the
    // chain (it could be disposed by then).
    final text = _ctrl.text;
    _saveChain = _saveChain.then((_) => _doSave(text));
  }

  Future<void> _doSave(String text) async {
    try {
      if (_captureId == null) {
        if (text.trim().isEmpty) return; // nothing to persist yet
        _captureId = await _actions.start(body: text);
      } else {
        await _actions.updateBody(id: _captureId!, body: text);
      }
      if (!mounted) return;
      _flashSaved();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'captures'),
      );
    }
  }

  void _flashSaved() {
    setState(() => _savedFlash = true);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _savedFlash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    return Padding(
      // Hug the keyboard — the modal sheet doesn't do this for us.
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Capture',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _savedFlash ? 1 : 0,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      label: const Text('Saved'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What did you notice?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Type and dismiss. We'll save it to the inbox; "
                'triage it later from /captures or the weekly review.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        unawaited(Navigator.of(context).maybePop()),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () =>
                        unawaited(Navigator.of(context).maybePop()),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
