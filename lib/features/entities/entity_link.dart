import 'package:differentworld/features/entities/entity_peek.dart';
import 'package:differentworld/features/entities/entity_providers.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tint + weight a linked entity's text wears, so a structured [EntityLink]
/// and an autotagged span in `LinkifiedText` look identical. The accent is
/// content-driven; [readableEntityTint] keeps it AA in both light and dark.
TextStyle entityInlineTextStyle(
  BuildContext context,
  EntityKind kind, {
  TextStyle? base,
}) {
  final tint = readableEntityTint(kind.accent, Theme.of(context).brightness);
  return (base ?? const TextStyle()).copyWith(
    color: tint,
    fontWeight: FontWeight.w500,
  );
}

/// A STRUCTURED entity reference — a place that already knows the id (a roster
/// row's name, a block's activity, a trip's vehicle). Renders the label as a
/// tappable tinted chip that opens [showEntityPeek]. When live entities are
/// switched off it degrades to plain [Text], so call sites never branch.
class EntityLink extends ConsumerWidget {
  const EntityLink({
    required this.entity,
    this.style,
    this.padded = true,
    this.tinted = true,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final EntityRef entity;

  /// Base text style; the tint + weight are layered on.
  final TextStyle? style;

  /// `true` → a soft tinted pill (a standalone chip). `false` → bare tinted
  /// text (inline next to other words).
  final bool padded;

  /// `false` → the label keeps its own colour and only the TAP survives.
  ///
  /// The kind-tint is what makes an entity reference legible inside prose —
  /// "Sofia and Mateo built a fort" wants the two names to look like the
  /// things they are. In a LIST where every row is the same kind it says
  /// nothing new, and twenty tinted names read as twenty flagged rows. The
  /// brand's rule is that glow is scarce; a roster spends it on nothing.
  final bool tinted;

  /// Forwarded to the inner [Text] so the chip is safe in a constrained slot
  /// (e.g. a grid-card header that caps the name at one line).
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!liveEntitiesOn(ref)) {
      return Text(
        entity.label,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final theme = Theme.of(context);
    final accent = entity.kind.accent;
    final label = Text(
      entity.label,
      style: tinted
          ? entityInlineTextStyle(context, entity.kind, base: style)
          : style,
      maxLines: maxLines,
      overflow: overflow,
    );
    final inner = padded
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: entityChipFill(accent, theme.brightness),
              borderRadius: BorderRadius.circular(5),
            ),
            child: label,
          )
        : label;
    return Semantics(
      button: true,
      label: '${entity.label}, ${entity.kind.noun}',
      child: InkWell(
        onTap: () => showEntityPeek(context, entity),
        borderRadius: BorderRadius.circular(5),
        child: inner,
      ),
    );
  }
}

/// Make an existing CHIP (or any small widget) open its entity peek on tap,
/// WITHOUT restyling it as a text link — for the verb / world / role chips in
/// detail views that should be explorable. Keeps the chip's own visual; just
/// adds the tap. Degrades to the bare [child] when live entities are off.
class EntityChipTap extends ConsumerWidget {
  const EntityChipTap({
    required this.entity,
    required this.child,
    super.key,
  });

  final EntityRef entity;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!liveEntitiesOn(ref)) return child;
    return Semantics(
      button: true,
      label: '${entity.label}, ${entity.kind.noun}',
      child: InkWell(
        onTap: () => showEntityPeek(context, entity),
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}
