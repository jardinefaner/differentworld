import 'dart:async';

import 'package:differentworld/features/settings/display_style_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class FeatureCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    // Calm mode flattens NEUTRAL chrome — transparent + a hairline instead of
    // the heavy fill — so a list of rows reads as one surface, not a stack of
    // boxes. Signal tones keep their tint (that's what makes them a signal).
    // Calm AND Clean both flatten neutral chrome. Checked explicitly (not
    // `!= boxed`) so the null/loading state falls to boxed — matching the
    // pre-existing behaviour every golden baseline was captured under.
    final style = ref.watch(displayStyleProvider).value;
    final flat =
        (style == DisplayStyle.calm || style == DisplayStyle.clean) &&
        tone == FeatureCardTone.neutral;
    final bg = flat
        ? Colors.transparent
        : switch (tone) {
            FeatureCardTone.neutral => scheme.surfaceContainerHighest,
            FeatureCardTone.selected => scheme.primaryContainer,
            FeatureCardTone.danger => scheme.errorContainer.withValues(
              alpha: 0.45,
            ),
            FeatureCardTone.success => scheme.tertiaryContainer.withValues(
              alpha: 0.5,
            ),
          };
    // Foreground paired to each tone. Default text color over
    // `surfaceContainerHighest` is `onSurface`, but over tinted
    // containers it has to flip to the matching foreground or the
    // contrast drops below WCAG AA. Wave 94 fix: title + subtitle
    // now inherit this color instead of the always-`onSurface`
    // they had before.
    final fg = switch (tone) {
      FeatureCardTone.neutral => scheme.onSurface,
      FeatureCardTone.selected => scheme.onPrimaryContainer,
      FeatureCardTone.danger => scheme.onErrorContainer,
      FeatureCardTone.success => scheme.onTertiaryContainer,
    };

    final body = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (flat)
            // One edge: the leading HANGS in a fixed gutter so the content
            // snaps to the same left line on every row (an empty gutter when
            // there's no leading keeps that edge consistent).
            SizedBox(
              width: 44,
              child: leading == null
                  ? null
                  : Align(alignment: Alignment.topLeft, child: leading),
            )
          else if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: content ?? _defaultContent(theme, fg),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    // The tap surface — haptics wired into the primitive so every site
    // inherits them (CLAUDE.md "every primary tap fires HapticFeedback").
    // Rectangular ripple when flat (a row), rounded when boxed (a card).
    // Mark the tappable card as a button so TalkBack / VoiceOver announce
    // the role — InkWell exposes a tap action but not the button role, and
    // a `content:` override bypasses the default title Text, so without this
    // a rich card reads as an unlabeled tappable region. The descendant
    // Text nodes still supply the spoken label.
    final inner = onTap == null && onLongPress == null
        ? body
        : Semantics(
            button: true,
            child: InkWell(
              borderRadius: flat ? null : radius,
              onTap: onTap == null
                  ? null
                  : () {
                      unawaited(HapticFeedback.selectionClick());
                      onTap!();
                    },
              onLongPress: onLongPress == null
                  ? null
                  : () {
                      unawaited(HapticFeedback.mediumImpact());
                      onLongPress!();
                    },
              child: body,
            ),
          );

    // Calm neutral → a flush ROW: no fill, no box, a bottom hairline to
    // separate rows. Boxed / signal tones → a filled, rounded card.
    if (flat) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          child: inner,
        ),
      );
    }
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }

  Widget _defaultContent(ThemeData theme, Color fg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _renderTitle(theme, fg),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          _renderSubtitle(theme, fg),
        ],
      ],
    );
  }

  Widget _renderTitle(ThemeData theme, Color fg) {
    if (title is Widget) return title as Widget;
    return Text(
      title as String,
      style: theme.textTheme.titleMedium?.copyWith(color: fg),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Widget _renderSubtitle(ThemeData theme, Color fg) {
    final s = subtitle;
    if (s is Widget) return s;
    // Fade the foreground a touch for the subtitle so it reads as
    // secondary while still passing AA against the tinted surface.
    return Text(
      s! as String,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: fg.withValues(alpha: 0.78),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
