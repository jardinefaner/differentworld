import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The modal-free destructive pattern (CLAUDE.md "No modal is a destination or
/// a task"): delete NOW, then offer Undo in a snackbar for a few seconds — no
/// "are you sure?" wall. Use this for any REVERSIBLE delete: rows carry a
/// stable client-side UUID, so [onUndo] just re-inserts the same row and
/// PowerSync re-syncs it (it reappears on every device).
///
/// Keep [confirmDestructive] ONLY for irreversible / cascading deletes where a
/// single re-insert can't restore the whole tree (e.g. deleting a cohort that
/// owns children) — there, a one-tap undo would lie about what it can bring
/// back.
///
/// The snackbar rides the root messenger, so undo still works after the user
/// navigates away from the screen that triggered the delete (pass closures that
/// capture the DAO/data, not [context]).
Future<void> deleteWithUndo(
  BuildContext context, {
  required String label,
  required Future<void> Function() onDelete,
  required Future<void> Function() onUndo,
  String? message,
  Duration duration = const Duration(seconds: 6),
}) async {
  final messenger = ScaffoldMessenger.of(context);
  unawaited(HapticFeedback.mediumImpact());
  await onDelete();
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message ?? 'Deleted $label'),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(onUndo()),
        ),
      ),
    );
}

/// Any write that a mis-tap should be able to take back.
///
/// [deleteWithUndo] is shaped for deletes; this is the same guarantee for a
/// CHANGE. It exists because the fix-in-place controls on the readiness card
/// write on a single tap — "No" against a child's photo consent is one
/// thumb-width from "Yes", and consent is exactly the answer you would hate
/// to set wrong silently.
///
/// The snackbar rides the root messenger, so undo survives navigating away;
/// pass closures that capture the DAO and the PREVIOUS value, never
/// the build context.
/// Takes a [messenger] rather than a [BuildContext] on purpose: callers
/// routinely need an `await` (a DAO future) before the write, and reading
/// the messenger off a context after that gap is the exact
/// use_build_context_synchronously trap. Capturing it up front makes the
/// safe thing the only thing.
Future<void> writeWithUndo({
  required ScaffoldMessengerState messenger,
  required String message,
  required Future<void> Function() onWrite,
  required Future<void> Function() onUndo,
  Duration duration = const Duration(seconds: 6),
}) async {
  unawaited(HapticFeedback.selectionClick());
  await onWrite();
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(onUndo()),
        ),
      ),
    );
}

/// Shows a confirm-destructive dialog and returns `true` if the user
/// confirmed. Reserve for IRREVERSIBLE / cascading deletes — for a reversible
/// delete, reach for [deleteWithUndo] instead (no modal).
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogCtx).colorScheme.errorContainer,
            foregroundColor: Theme.of(dialogCtx).colorScheme.onErrorContainer,
          ),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// A trailing destructive button (red text, ghost outline) commonly
/// used at the bottom of edit forms. Wraps [TextButton.icon] so it
/// shows a delete icon + label.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.delete_outline,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: scheme.error),
      label: Text(
        label,
        style: TextStyle(color: scheme.error),
      ),
    );
  }
}
