import 'package:differentworld/shared/breakpoints.dart';
import 'package:flutter/material.dart';

/// Single-column body for form-shaped screens.
///
/// On a 1920-wide desktop window, an unconstrained `TextField` runs
/// ~1800dp wide — fields like "First name" become 1800-pixel ribbons
/// that are hostile to read and impossible to scan as a form. This
/// primitive clamps the column to a comfortable reading width
/// (default 600dp, matching `Breakpoints.contentMaxWidth`) and
/// centers horizontally.
///
/// Use this for any screen whose body is "a series of fields the
/// user fills in" — subject edit, vehicle edit, observation form,
/// group edit, member detail (form tabs), settings detail rows,
/// invite create, send export, etc.
///
/// For list-shaped pages (cards, rows, tabular data) reach for
/// `ResponsivePage` (lib/shared/widgets/responsive_page.dart) — it
/// clamps wider (1200dp) so lists can take more screen real estate.
class FormBody extends StatelessWidget {
  const FormBody({
    required this.children,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96),
    this.physics,
    super.key,
  });

  /// Form rows / fields / sections rendered top-to-bottom.
  final List<Widget> children;

  /// Max column width. Defaults to 600dp — comfortable line length
  /// for input labels + values without truncating field text.
  final double maxWidth;

  /// Padding around the inner column. 96dp bottom by convention so
  /// the last field clears the omnibox bar.
  final EdgeInsetsGeometry padding;

  /// Override scroll physics. Defaults to platform-correct.
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: padding,
          physics: physics,
          children: children,
        ),
      ),
    );
  }
}
