import 'package:flutter/material.dart';

/// Visual tone for a [FeatureCard]. Drives the surface color so the
/// at-a-glance reading of a list of rows scans correctly even before
/// the user reads the text.
enum FeatureCardTone {
  /// Default neutral — `surfaceContainerHighest`.
  neutral,

  /// Currently-selected (multi-select / picker). Tinted with
  /// `primaryContainer` so the picked row pops in a list of greys.
  selected,

  /// Something needs attention — overdue task, expired cert, flagged
  /// kid. Tinted with `errorContainer` at low alpha so it reads as
  /// "look here" without screaming.
  danger,

  /// Affirmative state — completed, healthy, accounted for. Tinted
  /// `tertiaryContainer` for a softer "all good" cue. Use sparingly;
  /// the absence of a danger tone IS the success cue in most lists.
  success,
}

/// The canonical tappable-row card used across feature surfaces.
///
/// Wraps the Material + radius + InkWell + Padding + Row(leading,
/// content, trailing) pattern that's been re-implemented in 17
/// places across the app. New features should reach for this
/// instead of building a fresh `_FooCard` widget.
///
/// **Anatomy**:
/// ```text
/// ┌─────────────────────────────────────────────────────┐
/// │  [leading]    [title]            [trailing]         │
/// │               [subtitle]                            │
/// └─────────────────────────────────────────────────────┘
/// ```
///
/// The card sizes to its content — give it a `Column` of richer
/// rows via [content] when the simple title + subtitle pair isn't
/// enough.
///
/// **Examples**:
///
/// Simple drill-in row:
/// ```dart
/// FeatureCard(
///   leading: PersonAvatar(name: kid.name, photoUrl: kid.photoUrl),
///   title: kid.name,
///   subtitle: 'Tap to view today',
///   onTap: () => context.push('/family/${kid.id}'),
/// )
/// ```
///
/// With unread badge:
/// ```dart
/// FeatureCard(
///   leading: PersonAvatar(...),
///   title: name,
///   subtitle: lastMessage,
///   trailing: unread > 0 ? UnreadBadge(unread) : null,
///   onTap: ...,
/// )
/// ```
///
/// Selectable in a multi-select sheet:
/// ```dart
/// FeatureCard(
///   tone: selected ? FeatureCardTone.selected : FeatureCardTone.neutral,
///   leading: ...,
///   title: subject.firstName,
///   onTap: () => toggle(subject.id),
/// )
/// ```
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.content,
    this.onTap,
    this.onLongPress,
    this.tone = FeatureCardTone.neutral,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
    this.borderRadius = 14,
    super.key,
  });

  /// Leading widget — typically a `PersonAvatar` or a tinted [Icon].
  /// Omit for compact rows that don't need an identifier.
  final Widget? leading;

  /// Title shown on the first line. Pass a [Widget] for richer titles
  /// (e.g. a name + timestamp row); pass a [String] for the common
  /// single-line case.
  final Object title;

  /// Subtitle shown below the title. Same Widget-or-String rule as
  /// [title]. Render as italic when the data is a placeholder.
  final Object? subtitle;

  /// Trailing widget — chevron, count badge, status pill.
  final Widget? trailing;

  /// Override the title/subtitle column entirely. Use when the row
  /// needs more than the standard two-line layout (e.g. progress
  /// bars, attachment thumbnails).
  final Widget? content;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final FeatureCardTone tone;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    final bg = switch (tone) {
      FeatureCardTone.neutral => scheme.surfaceContainerHighest,
      FeatureCardTone.selected => scheme.primaryContainer,
      FeatureCardTone.danger => scheme.errorContainer.withValues(alpha: 0.45),
      FeatureCardTone.success =>
        scheme.tertiaryContainer.withValues(alpha: 0.5),
    };

    final body = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: content ?? _defaultContent(theme),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    return Material(
      color: bg,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null && onLongPress == null
          ? body
          : InkWell(
              borderRadius: radius,
              onTap: onTap,
              onLongPress: onLongPress,
              child: body,
            ),
    );
  }

  Widget _defaultContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _renderTitle(theme),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          _renderSubtitle(theme),
        ],
      ],
    );
  }

  Widget _renderTitle(ThemeData theme) {
    if (title is Widget) return title as Widget;
    return Text(
      title as String,
      style: theme.textTheme.titleMedium,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Widget _renderSubtitle(ThemeData theme) {
    final s = subtitle;
    if (s is Widget) return s;
    return Text(
      s! as String,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
