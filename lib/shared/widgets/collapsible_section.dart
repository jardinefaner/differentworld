import 'package:flutter/material.dart';

/// A section with a tappable header that collapses its body — the calm /
/// progressive-disclosure primitive.
///
/// The "too much at once" fix: a dense screen leads with what matters and
/// tucks the rarely-opened sections one tap away. Pairs with
/// `SectionCard` (hide-when-empty) for the full calm toolkit — use that
/// when a section has NOTHING to say; use this when it has content that
/// just doesn't need to be open by default (a child's sent reports,
/// pickup list, etc.).
///
/// - [title] + optional [icon]: the header, in the app's section-header
///   style (`titleSmall`).
/// - [collapsedSummary]: an optional one-line peek shown ONLY when
///   collapsed, so collapsing keeps the glanceable signal alive
///   ("3 guardians", "Allergy: peanut").
/// - [visible] `= false` renders nothing (parity with `SectionCard`).
/// - [initiallyExpanded] seeds the open/closed state; the user's toggle
///   is local (not persisted) — cheap and predictable.
///
/// The body stays built while collapsed (AnimatedCrossFade keeps both
/// children) so its Drift watches are warm and there's no load-flash on
/// expand. Cheap for the local streams these wrap.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    required this.title,
    required this.child,
    this.icon,
    this.collapsedSummary,
    this.initiallyExpanded = true,
    this.visible = true,
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? collapsedSummary;
  final bool initiallyExpanded;
  final bool visible;
  final EdgeInsetsGeometry headerPadding;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          button: true,
          label: widget.title,
          expanded: _expanded,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: widget.headerPadding.add(
                const EdgeInsets.symmetric(vertical: 6),
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                  ],
                  Text(widget.title, style: theme.textTheme.titleSmall),
                  const Spacer(),
                  if (!_expanded && widget.collapsedSummary != null)
                    Flexible(
                      child: Text(
                        widget.collapsedSummary!,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: widget.child,
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}
