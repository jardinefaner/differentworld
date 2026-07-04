import 'package:flutter/widgets.dart';

/// Layout breakpoints, in logical pixels (dp on mobile, CSS pixels on web).
///
/// Use `FormFactor.fromWidth(constraints.maxWidth)` inside a `LayoutBuilder`
/// for size-aware widgets — avoid reading `MediaQuery.of(context).size` in
/// `build` methods that rebuild often (it triggers a rebuild on every
/// keyboard show/hide, rotation, window resize).
abstract final class Breakpoints {
  /// Below this is a phone in portrait. Single column, bottom nav.
  static const double phone = 600;

  /// Below this is a small tablet or phone landscape. Single column with
  /// a side rail.
  static const double smallTablet = 840;

  /// Below this is an iPad-sized window. Two-column master-detail.
  static const double tablet = 1200;

  /// Anything wider is a desktop window. Three-column with persistent
  /// side panel.

  /// Standard max content width for forms and prose. Keeps lines from
  /// stretching uncomfortably wide on desktop.
  static const double contentMaxWidth = 600;

  /// Wider max for two-column layouts (list + detail side by side).
  static const double splitMaxWidth = 1200;
}

enum FormFactor {
  phone,
  smallTablet,
  tablet,
  desktop
  ;

  static FormFactor fromWidth(double width) {
    if (width < Breakpoints.phone) return FormFactor.phone;
    if (width < Breakpoints.smallTablet) return FormFactor.smallTablet;
    if (width < Breakpoints.tablet) return FormFactor.tablet;
    return FormFactor.desktop;
  }

  static FormFactor of(BuildContext context) {
    return FormFactor.fromWidth(MediaQuery.sizeOf(context).width);
  }

  bool get isCompact => this == FormFactor.phone;
  bool get isMedium =>
      this == FormFactor.smallTablet || this == FormFactor.tablet;
  bool get isExpanded => this == FormFactor.desktop;
}
