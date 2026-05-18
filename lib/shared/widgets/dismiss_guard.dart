import 'package:flutter/material.dart';

/// Wraps a screen / sheet body in a [PopScope] that intercepts the
/// system / scrim / drag-down dismiss when [isDirty] returns true,
/// and shows a "Discard changes?" confirmation dialog before
/// actually popping.
///
/// Callers pass `isDirty` as a function (not a bool) so the freshest
/// state is read on every pop attempt — the widget rebuilds when the
/// host calls setState but we want the dismiss check to evaluate at
/// the moment the user tries to leave.
class DismissGuard extends StatelessWidget {
  const DismissGuard({
    required this.isDirty,
    required this.child,
    this.discardMessage = 'You have unsaved changes. Discard them?',
    super.key,
  });

  final bool Function() isDirty;
  final Widget child;
  final String discardMessage;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!isDirty()) {
          Navigator.of(context).pop();
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Discard changes?'),
            content: Text(discardMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  foregroundColor: Theme.of(dialogCtx).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
