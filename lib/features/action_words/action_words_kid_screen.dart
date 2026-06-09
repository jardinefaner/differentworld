import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/widgets/verb_grid.dart';
import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/action-words/pick/:subjectId` — the **kid-facing** morning pick. Where
/// `ActionWordsScreen` is the teacher doing every kid in ~10 s each, this is
/// the device handed to ONE child to choose their own three words for the day.
///
/// It locks into kid mode on mount (AppShell strips the omnibox bar, drawer,
/// and top chrome; the router pins the URL so system-back / browser-back can't
/// drift to a staff surface) and only a staff 5-tap-corner + optional PIN
/// unlocks it — the same hardening survey-take uses. Picks save through the
/// existing `ActionWordsActions.setPicks` (one `action_words` entry per
/// subject/day); the revealed world stays hidden until the closing ceremony,
/// exactly like the teacher path.
class ActionWordsKidScreen extends ConsumerStatefulWidget {
  const ActionWordsKidScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  ConsumerState<ActionWordsKidScreen> createState() =>
      _ActionWordsKidScreenState();
}

class _ActionWordsKidScreenState extends ConsumerState<ActionWordsKidScreen>
    with WidgetsBindingObserver {
  final Set<String> _selected = {};
  bool _saving = false;
  bool _saved = false;
  bool _staffUnlocked = false;

  // Hidden staff-exit: five quick taps in the top-left corner, each within
  // _staffTapWindow of the last, so a kid mashing the corner can't accumulate.
  int _staffTapCount = 0;
  Timer? _staffTapReset;
  bool _exitDialogOpen = false;
  static const _staffTapTarget = 5;
  static const _staffTapWindow = Duration(milliseconds: 800);

  String get _lockedRoute => '/action-words/pick/${widget.subjectId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer through a microtask (not a sync write): initState runs during the
    // parent route's build phase and AppShell watches kidModeProvider, so a
    // sync write trips Riverpod's "modified during build" assertion.
    unawaited(Future.microtask(() {
      if (!mounted) return;
      try {
        ref.read(kidModeProvider.notifier).enter();
        ref.read(kidModeLockedRouteProvider.notifier).pin(_lockedRoute);
      } on Object catch (e, st) {
        if (kDebugMode) {
          debugPrint('[action-words-kid] enter failed: $e\n$st');
        }
      }
    }));
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

  void _toggle(String id) {
    if (_saved || _saving) return;
    setState(() {
      if (_selected.remove(id)) {
        unawaited(HapticFeedback.selectionClick());
      } else if (_selected.length < kPicksPerDay) {
        _selected.add(id);
        unawaited(HapticFeedback.selectionClick());
      }
    });
  }

  Future<void> _save(Subject subject) async {
    if (_saving || _saved || _selected.length != kPicksPerDay) return;
    setState(() => _saving = true);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref.read(actionWordsActionsProvider).setPicks(
            subjectId: subject.id,
            groupId: subject.groupId,
            date: todayKey(),
            verbIds: _selected.toList(),
          );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
    } on Object catch (e, st) {
      // The write is optimistic local Drift, so this is rare — but if it
      // throws we must clear _saving or the kid's button is dead for the rest
      // of the locked session, with no way to retry.
      if (kDebugMode) {
        debugPrint('[action-words-kid] save failed: $e\n$st');
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not save — tap to try again.')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(subjectByIdProvider(widget.subjectId)).value;
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
            Positioned.fill(child: _body(subject)),
            // Hidden staff-corner (top-left, no content overlap).
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

  Widget _body(Subject? subject) {
    final topInset = MediaQuery.paddingOf(context).top;
    if (_saved) {
      return _Celebration(verbIds: _selected.toList(), topInset: topInset);
    }
    final theme = Theme.of(context);
    final firstName = subject?.firstName.trim() ?? '';
    final ready = _selected.length == kPicksPerDay;
    return Column(
      children: [
        SizedBox(height: topInset + 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                firstName.isEmpty
                    ? 'Pick your 3 words!'
                    : '$firstName, pick your 3 words!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _ProgressDots(filled: _selected.length, total: kPicksPerDay),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: VerbGrid(selected: _selected, onToggle: _toggle),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ready && !_saving && subject != null
                    ? () => unawaited(_save(subject))
                    : null,
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.check_circle, size: 28),
                label: Text(
                  ready ? 'These are my words!' : 'Pick 3 to finish',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Three big dots that fill as words are picked — a kid-legible progress meter.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.filled, required this.total});
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: i < filled ? scheme.primary : scheme.outline,
                  width: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The post-save celebration — the kid's three chosen words, big. They show a
/// grown-up; staff takes the device back and exits via the corner gesture.
class _Celebration extends StatelessWidget {
  const _Celebration({required this.verbIds, required this.topInset});
  final List<String> verbIds;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verbs = verbsByIds(verbIds);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('✨', style: TextStyle(fontSize: theme.textTheme.displayLarge?.fontSize ?? 56)),
          const SizedBox(height: 8),
          Text(
            'Your words today!',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 28),
          for (final v in verbs)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(v.emoji, style: const TextStyle(fontSize: 44)),
                  const SizedBox(width: 16),
                  Text(
                    v.label,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Show a grown-up! 💛',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
