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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 64,
                color: theme.colorScheme.error.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                detail ??
                    "We couldn't reach the server. Your local data is "
                        'safe — try again in a moment.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
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
