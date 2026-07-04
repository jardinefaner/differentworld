import 'dart:async';

import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of the kid-mode exit gesture. Caller branches:
///   - [unlocked] → staff entered the right PIN; pop the lock
///   - [cancelled] → staff dismissed the dialog without succeeding
///   - [noPinConfigured] → space has no PIN set; the 5-tap gesture
///     alone unlocks (caller treats it like `unlocked`)
enum KidModeExitResult { unlocked, cancelled, noPinConfigured }

/// Show the staff exit dialog. Returns one of:
///
///   - `KidModeExitResult.unlocked` — staff entered the correct PIN
///   - `KidModeExitResult.cancelled` — staff dismissed without
///     completing
///   - `KidModeExitResult.noPinConfigured` — `Space.capabilities.staff_pin`
///     is unset; caller falls back to "5-tap alone unlocks"
///
/// The PIN is read off the active Space's capabilities. There's no
/// rate limiting yet; we trust the device-level lockdown to be
/// "kid can't get to a numeric keypad before staff intervenes",
/// not "staff is fending off a determined adversary."
Future<KidModeExitResult> showKidModeExitDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final viewer = ref.read(viewerProvider);
  final pin = viewer.spaceCaps.getString(SpaceCaps.staffPin)?.trim();
  if (pin == null || pin.isEmpty) {
    // No PIN configured — the 5-tap-corner is sufficient. Caller
    // treats this as the unlock signal.
    return KidModeExitResult.noPinConfigured;
  }
  final result = await showDialog<KidModeExitResult>(
    context: context,
    builder: (_) => _PinEntryDialog(expected: pin),
  );
  return result ?? KidModeExitResult.cancelled;
}

/// PIN entry dialog. 4–6 digit numeric keypad; correct PIN
/// triggers the haptic + closes with [KidModeExitResult.unlocked].
/// Wrong PIN shows a shake animation + error text; staff can retry
/// without closing the dialog.
class _PinEntryDialog extends StatefulWidget {
  const _PinEntryDialog({required this.expected});

  final String expected;

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _shake;
  String? _error;
  int _wrongCount = 0;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // Autofocus next frame so the keyboard appears immediately on
    // open — staff usually wants to type-and-go.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim() == widget.expected) {
      unawaited(HapticFeedback.mediumImpact());
      Navigator.of(context).pop(KidModeExitResult.unlocked);
      return;
    }
    _wrongCount += 1;
    unawaited(HapticFeedback.heavyImpact());
    unawaited(_shake.forward(from: 0));
    setState(() {
      _error = _wrongCount >= 3
          ? 'That is not right. Ask a director for the PIN.'
          : 'Wrong PIN — try again.';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      icon: Icon(Icons.lock_outline, color: scheme.primary, size: 36),
      title: const Text('Staff PIN'),
      content: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          // Subtle horizontal shake on wrong PIN. Eased so the
          // movement reads as "no" rather than "loading."
          final offsetX = _shake.isAnimating
              ? 8 * (1 - _shake.value) * (_shake.value * 8 % 2 < 1 ? 1 : -1)
              : 0.0;
          return Transform.translate(
            offset: Offset(offsetX, 0),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the PIN to exit kid mode.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              autocorrect: false,
              enableSuggestions: false,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                letterSpacing: 8,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            KidModeExitResult.cancelled,
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
