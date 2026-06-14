import 'dart:async';

import 'package:differentworld/shared/breakpoints.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Locks **phones** to portrait while leaving tablets / desktop / web free
/// to rotate.
///
/// The user only ever holds a phone upright, and every screen is designed
/// phone-first for a narrow portrait viewport — so a landscape phone layout
/// is a class of bugs nobody will ever see the upside of. Locking it away
/// means no screen has to defend a layout it's never shown in.
///
/// Tablets and desktop stay rotatable on purpose: the responsive layer is
/// built FOR landscape there — the `DesktopNavRail` (≥ [Breakpoints.tablet]),
/// `MasterDetailScaffold`, and the two-column breakpoints only make sense
/// in a wide window.
///
/// Detection is by **shortest side**, the standard phone/tablet split: a
/// device whose narrow edge is below [Breakpoints.phone] (600 dp) is a
/// phone. Living in `didChangeDependencies` (not `main()`) makes it robust
/// to two things a boot-time read can't handle: metrics that aren't ready
/// on the first frame, and a foldable / split-screen window that crosses
/// the 600 dp line at runtime — both re-fire this and re-evaluate.
class OrientationLock extends StatefulWidget {
  const OrientationLock({required this.child, super.key});

  final Widget child;

  @override
  State<OrientationLock> createState() => _OrientationLockState();
}

class _OrientationLockState extends State<OrientationLock> {
  /// Last policy we pushed to the platform. Tracked so we only touch the
  /// orientation channel when the decision actually flips (e.g. a foldable
  /// unfolds past 600 dp), not on every unrelated MediaQuery change.
  bool? _lockedToPortrait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyPolicy();
  }

  void _applyPolicy() {
    // Web rotates with the browser window; native desktop windows are
    // free-form. Only Android / iOS have a device orientation worth
    // locking.
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    final isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (!isMobile) return;

    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    // `> 0` guards the zero-size first frame some platforms report before
    // layout — skip until real metrics arrive (a later dependency change
    // re-runs us).
    final shouldLock = shortestSide > 0 && shortestSide < Breakpoints.phone;
    if (shouldLock == _lockedToPortrait) return;
    _lockedToPortrait = shouldLock;
    unawaited(
      SystemChrome.setPreferredOrientations(
        shouldLock
            // Phone: portrait only. `portraitUp` alone (not `portraitDown`)
            // matches the platform convention — nobody holds a phone
            // upside-down on purpose.
            ? const [DeviceOrientation.portraitUp]
            // Tablet that briefly looked phone-sized (split-screen): let
            // every orientation back through.
            : DeviceOrientation.values,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
