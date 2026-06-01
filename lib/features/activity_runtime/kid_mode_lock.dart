import 'dart:async';

import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The kid-mode lockdown, extracted so the conducted activity screens
/// share ONE vetted copy instead of re-deriving it (the bugs fixed on the
/// Math/Photography screens — ref-in-dispose, watch-then-mutate — stay
/// fixed everywhere). For camera-less full-screen kid activities.
///
/// Usage:
/// ```dart
/// class _State extends ConsumerState<MyScreen>
///     with WidgetsBindingObserver, KidModeLock<MyScreen> {
///   @override void initState() { super.initState(); enterKidLock('/activity/x'); }
///   @override void dispose() { exitKidLock(); super.dispose(); }
///   @override Widget build(BuildContext context) =>
///       buildKidLock(child: _body());
/// }
/// ```
///
/// Drives the lock from local state ([kidUnlocked]) — it deliberately does
/// NOT `ref.watch(kidModeProvider)` (mutating it in dispose would notify a
/// defunct element). Notifiers are cached in [enterKidLock] (ref is unsafe
/// in dispose). Blocks back until a staff 5-tap (+ PIN) unlock.
mixin KidModeLock<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, WidgetsBindingObserver {
  KidMode? _kidMode;
  KidModeLockedRoute? _lockedRoute;
  String _lockRoute = '/';
  bool _kidUnlocked = false;
  int _staffTaps = 0;
  Timer? _staffTapReset;

  /// True once staff has unlocked (back works, the lock is released).
  bool get kidUnlocked => _kidUnlocked;

  /// Call from initState. [route] is pinned so the router refuses to
  /// navigate away (covers the web back button too).
  void enterKidLock(String route) {
    _lockRoute = route;
    _kidMode = ref.read(kidModeProvider.notifier);
    _lockedRoute = ref.read(kidModeLockedRouteProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        _kidMode?.enter();
        _lockedRoute?.pin(_lockRoute);
      }),
    );
  }

  /// Call from dispose, BEFORE super.dispose().
  void exitKidLock() {
    WidgetsBinding.instance.removeObserver(this);
    _staffTapReset?.cancel();
    _kidMode?.exit();
    _lockedRoute?.pin(null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-engage on resume unless staff already unlocked.
    if (state == AppLifecycleState.resumed && !_kidUnlocked && mounted) {
      _kidMode?.enter();
      _lockedRoute?.pin(_lockRoute);
    }
  }

  Future<void> _onStaffCornerTap() async {
    _staffTaps += 1;
    _staffTapReset?.cancel();
    if (_staffTaps >= 5) {
      _staffTaps = 0;
      final result = await showKidModeExitDialog(context, ref);
      if (!mounted) return;
      switch (result) {
        case KidModeExitResult.unlocked:
        case KidModeExitResult.noPinConfigured:
          setState(() => _kidUnlocked = true);
          _lockedRoute?.pin(null);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('Unlocked. Press back to exit.')),
          );
        case KidModeExitResult.cancelled:
          break;
      }
      return;
    }
    _staffTapReset = Timer(const Duration(seconds: 2), () {
      if (mounted) _staffTaps = 0;
    });
  }

  /// Wrap the screen's content: blocks back while locked, fills the screen
  /// black (no chrome — AppShell strips it in kid mode), and overlays the
  /// hidden staff-corner exit on top.
  Widget buildKidLock({required Widget child}) {
    return PopScope(
      canPop: _kidUnlocked,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Hand the device back to a teacher to exit.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: EdgeScaffold(
        body: ColoredBox(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(child: child),
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => unawaited(_onStaffCornerTap()),
                  child: const SizedBox(width: 56, height: 56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
