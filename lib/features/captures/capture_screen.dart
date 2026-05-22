import 'dart:async';

import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Drop a quick "I noticed…" into the capture inbox.
///
/// Promoted from `capture_sheet.dart` (bottom-sheet) to a full
/// route at `/captures/new` in Wave 21. Routes give the form full
/// chrome, proper back button, and the layout law — no more cramped
/// modal feel.
///
/// **Auto-save semantics preserved.** Every keystroke schedules a
/// serialized save through a `Future` chain. The first non-empty
/// character INSERTs the capture row; subsequent edits UPDATE it.
/// If the user navigates away with an empty body, the shell row is
/// discarded so the inbox stays tidy. In-flight writes complete in
/// the background even after the widget unmounts (the chain
/// references the captured actions instance, not `ref`).
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// Actions instance captured at mount so the save chain can
  /// complete safely after the widget is gone.
  late final CaptureActions _actions;

  /// Serialized chain of write Futures. Each keystroke appends a
  /// `.then(...)` so writes happen in typed order.
  Future<void> _saveChain = Future<void>.value();

  /// The id of this capture's row, after the first non-empty save.
  /// Subsequent saves UPDATE this row.
  String? _captureId;

  /// True while a save round-trip is in flight, so the "Saved" chip
  /// can flash green.
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
    // If the user opened the screen, never typed anything meaningful,
    // and navigated away — hard-delete the shell row so the inbox
    // stays tidy. Capture `id` here because `this._captureId` may be
    // read by the chain after super.dispose().
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
    // Capture the current text NOW; never read `_ctrl` inside the
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
    return EdgeScaffold(
      backFallbackRoute: '/captures',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: ContentHeader(
                  title: 'Capture',
                  subtitle: 'What did you notice?',
                  bottomGap: 0,
                ),
              ),
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
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            autofocus: true,
            minLines: 6,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: "Drop a thought. We'll auto-save as you type.",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Saves to the inbox automatically. Triage later from '
            '/captures or the weekly review. Empty captures are '
            'discarded when you leave.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  if (context.canPop()) context.pop();
                },
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
