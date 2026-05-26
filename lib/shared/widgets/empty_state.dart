import 'package:differentworld/shared/breakpoints.dart';
import 'package:flutter/material.dart';

/// Default empty state for any list / data screen.
///
/// Per CLAUDE.md, every data screen must design its empty state — never
/// just an empty white surface. Use this widget for the standard layout:
/// icon, title, optional message, optional action button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wave 112: scale the empty state up at desktop widths. A 64dp
    // icon + 360dp text block centered in a 1920px window looks
    // like a 404 page. At desktop, 96dp icon + 480dp text reads
    // as "this surface is empty," not "the page is broken."
    final formFactor = FormFactor.of(context);
    final isWide = formFactor.isExpanded;
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
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
              SizedBox(height: isWide ? 24 : 20),
              Text(
                title,
                style: isWide
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                SizedBox(height: isWide ? 12 : 8),
                Text(
                  message!,
                  style: (isWide
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall)
                      ?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                SizedBox(height: isWide ? 32 : 24),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
