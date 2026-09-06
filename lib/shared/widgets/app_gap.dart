import 'package:flutter/widgets.dart';

/// The spacing scale — the one set of gaps the app is allowed to use.
///
/// Before this there were **29 distinct spacing values across 1,906 call
/// sites**: 2, 3, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28 and up. Nothing
/// was wrong with any single one; the problem is that 10 and 12 and 14 all
/// exist, so no two screens share a rhythm and the deck reads as assembled
/// rather than designed. That is the real cause behind "some screens are
/// cramped and not breathable" — not any one gap, but the absence of a scale.
///
/// Seven steps, on a 4-grid with a 2 for hairline nudges. Sized by what the
/// gap is BETWEEN, so the choice is a judgement about structure rather than a
/// number pulled from the air:
///
/// | step | px | between |
/// |---|---|---|
/// | `xs`  | 2  | a label and the thing it labels |
/// | `sm`  | 4  | parts of one component |
/// | `md`  | 8  | sibling rows in a list |
/// | `lg`  | 12 | a component and the next |
/// | `xl`  | 16 | groups of components |
/// | `xxl` | 24 | major blocks on a screen |
/// | `xxxl`| 32 | a screen's distinct sections |
///
/// Use `AppGap.lg()` in a Column/Row instead of `SizedBox(height: 12)`; it
/// reads as the intent and it is checked. `scripts/check_spacing_scale.sh`
/// fails on a NEW off-scale literal, so the sprawl cannot regrow while the
/// existing 1,900 sites are migrated surface by surface.
class AppGap extends StatelessWidget {
  /// A label and the thing it labels.
  const AppGap.xs({super.key}) : _px = 2;

  /// Parts of a single component.
  const AppGap.sm({super.key}) : _px = 4;

  /// Sibling rows in a list.
  const AppGap.md({super.key}) : _px = 8;

  /// One component and the next.
  const AppGap.lg({super.key}) : _px = 12;

  /// Groups of components.
  const AppGap.xl({super.key}) : _px = 16;

  /// Major blocks on a screen — a prompt, a count, an action group.
  const AppGap.xxl({super.key}) : _px = 24;

  /// A screen's distinct sections.
  const AppGap.xxxl({super.key}) : _px = 32;

  final double _px;

  /// The steps, for callers that need the number (padding, grid spacing)
  /// rather than a widget.
  static const double xsPx = 2;
  static const double smPx = 4;
  static const double mdPx = 8;
  static const double lgPx = 12;
  static const double xlPx = 16;
  static const double xxlPx = 24;
  static const double xxxlPx = 32;

  /// Every legal step, for the guard and for tests.
  static const List<double> steps = [
    xsPx,
    smPx,
    mdPx,
    lgPx,
    xlPx,
    xxlPx,
    xxxlPx,
  ];

  /// Square, so one gap works in a Column OR a Row without the caller picking
  /// an axis. A Column ignores the width and a Row ignores the height, which
  /// is why `SizedBox(height:)` and `SizedBox(width:)` were free to drift into
  /// two different sets of numbers in the first place.
  @override
  Widget build(BuildContext context) => SizedBox(width: _px, height: _px);
}
