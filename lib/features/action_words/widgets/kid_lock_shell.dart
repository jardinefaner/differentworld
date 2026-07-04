import 'dart:async';

import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The kid-mode lock + hidden-staff-exit shell shared by the action-words
/// kid surfaces (`ActionWordsKidScreen`, `KidJobScreen`) — one vetted copy of
/// the machinery both screens previously duplicated line-for-line:
///
/// - locks into kid mode on mount (deferred through a microtask: initState
///   runs during the parent route's build phase and AppShell watches
///   kidModeProvider, so a sync write trips Riverpod's "modified during
///   build" assertion) and pins the route so system-back / browser-back
///   can't drift to a staff surface;
/// - re-engages the lock on OS resume (the Activity can be resurrected
///   without rebuilding the tree, so initState wouldn't fire again);
/// - exits + unpins on dispose;
/// - the hidden staff-exit: five quick taps in the top-left corner, each
///   within [_staffTapWindow] of the last, so a kid mashing the corner can't
///   accumulate — with a re-entrancy guard so a second 5-tap burst while the
///   PIN dialog is open can't stack a second dialog;
/// - [buildKidLockShell] wraps the screen body in the PopScope +
///   EdgeScaffold + corner-tap Stack.
///
/// NOTE: `activity_runtime/kid_mode_lock.dart` has a sibling mixin with
/// deliberately different semantics (black raw-canvas fill, 2 s tap window,
/// no dialog re-entrancy guard) — this one preserves the action-words
/// behavior exactly; don't merge them without reconciling those differences.
mixin KidLockShell<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, WidgetsBindingObserver {
  bool _staffUnlocked = false;

  // Hidden staff-exit tap accounting.
  int _staffTapCount = 0;
  Timer? _staffTapReset;
  bool _exitDialogOpen = false;
  static const _staffTapTarget = 5;
  static const _staffTapWindow = Duration(milliseconds: 800);

  /// The route the router pins while locked (e.g.
  /// `/action-words/pick/$subjectId`).
  String get kidLockRoute;

  /// Short tag for kDebugMode logs, e.g. `action-words-kid`.
  String get kidLockDebugTag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer through a microtask (not a sync write): initState runs during the
    // parent route's build phase and AppShell watches kidModeProvider, so a
    // sync write trips Riverpod's "modified during build" assertion.
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        try {
          ref.read(kidModeProvider.notifier).enter();
          ref.read(kidModeLockedRouteProvider.notifier).pin(kidLockRoute);
        } on Object catch (e, st) {
          if (kDebugMode) {
            debugPrint('[$kidLockDebugTag] enter failed: $e\n$st');
          }
        }
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-engage the lock if the OS resurrected the Activity without rebuilding
    // the tree (initState wouldn't fire again on resume).
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(kidModeProvider.notifier).enter();
      if (_staffUnlocked) setState(() => _staffUnlocked = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(kidModeProvider.notifier).exit();
    ref.read(kidModeLockedRouteProvider.notifier).pin(null);
    _staffTapReset?.cancel();
    _staffTapReset = null;
    super.dispose();
  }

  Future<void> _onStaffCornerTap() async {
    _staffTapCount += 1;
    _staffTapReset?.cancel();
    if (_staffTapCount >= _staffTapTarget) {
      _staffTapCount = 0;
      _staffTapReset = null;
      // Re-entrancy guard: a second 5-tap burst while the PIN dialog is open
      // (a kid hammering the corner during staff entry) must not stack a
      // second dialog.
      if (_exitDialogOpen) return;
      _exitDialogOpen = true;
      try {
        final result = await showKidModeExitDialog(context, ref);
        if (!mounted) return;
        switch (result) {
          case KidModeExitResult.unlocked:
          case KidModeExitResult.noPinConfigured:
            setState(() => _staffUnlocked = true);
            ref.read(kidModeLockedRouteProvider.notifier).pin(null);
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(content: Text('Unlocked. Press back to exit.')),
            );
          case KidModeExitResult.cancelled:
            break;
        }
      } finally {
        _exitDialogOpen = false;
      }
      return;
    }
    _staffTapReset = Timer(_staffTapWindow, () {
      _staffTapCount = 0;
      _staffTapReset = null;
    });
  }

  /// Wraps [body] in the locked shell: back is blocked while kid mode is on
  /// and staff hasn't unlocked, and the hidden staff-corner (top-left, no
  /// content overlap) overlays the content. Call from `build`.
  Widget buildKidLockShell({required Widget body}) {
    final inKidMode = ref.watch(kidModeProvider);
    final blockPop = inKidMode && !_staffUnlocked;

    return PopScope(
      canPop: !blockPop,
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
        body: Stack(
          children: [
            Positioned.fill(child: body),
            // Hidden staff-corner (top-left, no content overlap).
            // `translucent` is deliberate: the detector must catch the
            // 5-tap even over empty space WITHOUT stealing hits from any
            // body content underneath (deferToChild would make the empty
            // SizedBox untappable; opaque would swallow the body's taps).
            Positioned(
              top: 0,
              left: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onStaffCornerTap,
                child: const SizedBox(width: 56, height: 56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
