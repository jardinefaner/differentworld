import 'package:differentworld/shared/breakpoints.dart';
import 'package:flutter/material.dart';

/// Error variant of `EmptyState` with a built-in retry button.
///
/// Use whenever an `AsyncValue.error` should not wipe the screen with a
/// dead-end "Could not load X" message. The retry callback runs the
/// underlying provider again (callers typically `ref.invalidate(...)`
/// the provider that produced the error).
///
/// Visual: same vertical layout as `EmptyState` but with an error-tinted
/// icon and an explicit retry button. The optional [detail] surfaces a
/// short, user-friendly description (NEVER raw stack traces).
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    this.detail,
    this.onRetry,
    this.icon = Icons.cloud_off_outlined,
    super.key,
  });

  /// e.g. "Could not load today"
  final String title;

  /// One-sentence hint about what to do — keep gentle, no jargon.
  final String? detail;

  /// Invoked when the user taps Retry. If null, the retry chip is
  /// hidden (use sparingly — almost every error path should let the
  /// user try again).
  final VoidCallback? onRetry;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wave 112: same scale-up treatment as EmptyState — error
    // states on a 1920px window with a tiny 64dp icon look like
    // the app crashed, not "this slice couldn't load."
    final isWide = FormFactor.of(context).isExpanded;
    final iconSize = isWide ? 96.0 : 64.0;
    final maxWidth = isWide ? 480.0 : 360.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: theme.colorScheme.error.withValues(alpha: 0.85),
              ),
              SizedBox(height: isWide ? 24 : 20),
              Text(
                title,
                style: isWide
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isWide ? 10 : 6),
              Text(
                detail ??
                    "We couldn't reach the server. Your local data is "
                        'safe — try again in a moment.',
                style: (isWide
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.bodySmall)
                    ?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                SizedBox(height: isWide ? 28 : 20),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
