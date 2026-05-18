import 'package:flutter/material.dart';

/// Shows a confirm-destructive dialog and returns `true` if the user
/// confirmed. Use for any irrecoverable action (delete classroom,
/// remove from team, revoke invite, etc.).
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
            backgroundColor:
                Theme.of(dialogCtx).colorScheme.errorContainer,
            foregroundColor:
                Theme.of(dialogCtx).colorScheme.onErrorContainer,
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
