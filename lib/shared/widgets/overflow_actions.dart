import 'dart:async';

import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One screen action, *described* rather than pre-built — so a container
/// can choose to render it inline (as a chrome pill button) OR collapse it
/// into the "⋯" overflow menu when the top-right pill would otherwise
/// crowd a narrow phone.
///
/// The fields mirror [PrimaryActionButton] / [SecondaryActionButton]
/// exactly ([icon] + [label] (their `tooltip`) + [onPressed]), so moving a
/// screen onto [OverflowActions] is a mechanical swap.
class EdgeAction {
  const EdgeAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
    this.iconColor,
  });

  final IconData icon;

  /// Tooltip when the action renders inline; the row label when it's
  /// collapsed into the "⋯" menu.
  final String label;

  /// `null` disables the action — it's dropped entirely (a disabled row
  /// in an overflow menu is noise), matching the "hide-don't-disable"
  /// convention used across the chrome pills.
  final VoidCallback? onPressed;

  /// The screen's primary verb — filled emphasis when inline, and *never*
  /// collapsed into the menu (a primary action must always be one tap).
  final bool isPrimary;

  /// A destructive verb (delete / remove) — tinted error in the menu.
  final bool isDestructive;

  /// Optional icon tint that survives both inline AND the menu — for the
  /// rare action that carries a meaning in its colour (e.g. a gold
  /// "Reveal" verb). Ignored for primaries (they own the filled emphasis)
  /// and overridden by [isDestructive].
  final Color? iconColor;
}

/// Renders a list of [EdgeAction]s for the top-right chrome pill,
/// collapsing the overflow into a single "⋯" menu so the pill never
/// crowds a narrow phone. Drop it into an `EdgeScaffold(actions: [...])`
/// slot as one entry:
///
/// ```dart
/// actions: [OverflowActions([
///   EdgeAction(icon: Icons.add, label: 'New', onPressed: ..., isPrimary: true),
///   EdgeAction(icon: Icons.edit, label: 'Edit', onPressed: ...),
///   EdgeAction(icon: Icons.delete, label: 'Delete', onPressed: ..., isDestructive: true),
/// ])],
/// ```
///
/// **Policy.** Primaries always render inline (a primary verb must never
/// hide). Secondaries fill the remaining inline slots up to [maxInline]
/// (1 on a phone, 3 on a wider viewport by default); anything past that
/// goes into the menu, in declared order. A menu is only shown when it
/// would hold **at least two** actions — collapsing a single action behind
/// a "⋯" tap is worse than just showing it.
class OverflowActions extends StatelessWidget {
  const OverflowActions(this.actions, {this.maxInline, super.key});

  final List<EdgeAction> actions;

  /// Override the inline budget (number of action pills shown beside the
  /// "⋯"). Defaults to 1 on a compact phone, 3 on anything wider. A screen
  /// with a critical secondary it wants always-visible can bump this.
  final int? maxInline;

  @override
  Widget build(BuildContext context) {
    // Disabled actions are dropped, not shown greyed — same
    // hide-don't-disable rule the pills follow.
    final items = actions.where((a) => a.onPressed != null).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final budget = maxInline ?? (FormFactor.of(context).isCompact ? 1 : 3);

    // Only collapse when it actually buys something: the menu must hold
    // ≥ 2. (With budget = 1, two total actions still both render inline —
    // a one-item "⋯" menu is pointless.)
    if (items.length <= budget + 1) {
      return _row([for (final a in items) _inline(a)]);
    }

    // Overflow. Primaries are pulled to the front of the inline set so a
    // primary verb is never collapsed; secondaries fill the rest of the
    // budget, and the remainder spills to the menu in declared order.
    final inline = <EdgeAction>[...items.where((a) => a.isPrimary)];
    final menu = <EdgeAction>[];
    for (final a in items.where((a) => !a.isPrimary)) {
      if (inline.length < budget) {
        inline.add(a);
      } else {
        menu.add(a);
      }
    }
    return _row([
      for (final a in inline) _inline(a),
      // `menu` can be empty if the overflow was driven entirely by
      // primaries (which never collapse) — don't render a "⋯" that opens
      // an empty popup.
      if (menu.isNotEmpty) _OverflowMenu(menu),
    ]);
  }

  Widget _inline(EdgeAction a) => a.isPrimary
      ? PrimaryActionButton(
          tooltip: a.label,
          icon: a.icon,
          onPressed: a.onPressed,
        )
      : SecondaryActionButton(
          tooltip: a.label,
          icon: a.icon,
          iconColor: a.isDestructive ? null : a.iconColor,
          onPressed: a.onPressed,
        );

  /// Mirrors `FloatingActions`' inter-pill spacing (2 dp) so an inline
  /// row built here lines up with one built from raw widgets.
  Widget _row(List<Widget> children) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(width: 2),
          ],
        ],
      );
}

/// The "⋯" pill — a [PopupMenuButton] sized + tinted to match
/// [SecondaryActionButton] (24 dp icon + 12 dp padding = 48 dp footprint),
/// so it sits flush in the chrome pill row.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu(this.items);

  final List<EdgeAction> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<int>(
      tooltip: 'More',
      icon: Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
      iconSize: 24,
      padding: const EdgeInsets.all(12),
      onSelected: (i) {
        unawaited(HapticFeedback.selectionClick());
        items[i].onPressed?.call();
      },
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(
                  items[i].icon,
                  size: 20,
                  color: items[i].isDestructive
                      ? scheme.error
                      : (items[i].iconColor ?? scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    items[i].label,
                    overflow: TextOverflow.ellipsis,
                    style: items[i].isDestructive
                        ? TextStyle(color: scheme.error)
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
