import 'dart:async';

import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drop a quick "I noticed…" into the inbox.
///
/// The lifecycle is deliberately autosave-only — there is no Save
/// button. Per UX_DECISIONS §1, a save button on a single-field
/// capture is friction we don't need: the user types, dismisses, and
/// the row is there. If they dismiss before typing anything, the row
/// is hard-deleted (no audit value in keeping empty captures).
///
/// On first non-empty keystroke we INSERT the row and remember the id.
/// Every subsequent change (debounced ~400ms) UPDATEs the body. This
/// keeps each open-sheet to at most one row in the inbox.
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
  Timer? _saveTimer;

  /// Once the row exists in the DB, we remember its id so subsequent
  /// edits target it instead of inserting again.
  String? _captureId;

  /// Visual feedback after a save completes — a 700ms "Saved" chip.
  bool _savedFlash = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    // Auto-focus the next frame — the bottom sheet animation needs to
    // settle first or the keyboard fights the slide-up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flashTimer?.cancel();
    _ctrl
      ..removeListener(_onChanged)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _flushSave);
  }

  Future<void> _flushSave() async {
    final text = _ctrl.text;
    final actions = ref.read(captureActionsProvider);
    try {
      if (_captureId == null) {
        if (text.trim().isEmpty) return; // nothing to persist yet
        final id = await actions.start(body: text);
        if (!mounted) return;
        setState(() => _captureId = id);
      } else {
        await actions.updateBody(id: _captureId!, body: text);
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

  Future<void> _closeNow() async {
    // Force a flush so a fast typist who dismisses 200ms after the
    // last keystroke doesn't lose that last keystroke.
    _saveTimer?.cancel();
    await _flushSave();
    if (_captureId != null && _ctrl.text.trim().isEmpty) {
      // Row was created but emptied — clean it up.
      await ref.read(captureActionsProvider).discardEmpty(_captureId!);
    }
    if (!mounted) return;
    unawaited(Navigator.of(context).maybePop());
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
                    onPressed: _closeNow,
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _closeNow,
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
