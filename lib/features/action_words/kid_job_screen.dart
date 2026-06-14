import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verb_roles.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/action-words/job/:subjectId` — **Role-4: the kid verb-job reshapes
/// kid-mode** (docs/VISION.md "your role reshapes your screen", applied to a
/// child). Where `ActionWordsKidScreen` is the morning PICK, this is the
/// during-the-day surface handed to ONE child to *do* the jobs their picks gave
/// them: each picked verb becomes a big job card — "You are The Mover!" + the
/// kid mission — and the child taps "I did it!" as they finish. The screen is
/// literally different for every child because their three verbs are different;
/// that difference IS the personalization (the kid analogue of "different tools
/// for different roles").
///
/// Same kid-mode hardening as the pick screen: locks on mount (AppShell strips
/// chrome; the router pins the URL so system-back can't escape to a staff
/// surface), re-engages on resume, and only a staff 5-tap-corner + optional PIN
/// unlocks it. Writes go through the existing [ActionWordsActions.toggleDone]
/// (optimistic local Drift — works offline).
class KidJobScreen extends ConsumerStatefulWidget {
  const KidJobScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  ConsumerState<KidJobScreen> createState() => _KidJobScreenState();
}

class _KidJobScreenState extends ConsumerState<KidJobScreen>
    with WidgetsBindingObserver {
  bool _staffUnlocked = false;

  // In-flight toggles, by verb id. A kid double-tapping "I did it!" faster than
  // a write round-trip would otherwise queue two toggles that net to a no-op
  // (tap twice → still undone), which reads as an unresponsive button. The
  // guard makes a rapid double-tap idempotent: the job stays done.
  final Set<String> _toggling = {};

  // Hidden staff-exit: five quick taps in the top-left corner, each within
  // _staffTapWindow of the last, so a kid mashing the corner can't accumulate.
  int _staffTapCount = 0;
  Timer? _staffTapReset;
  bool _exitDialogOpen = false;
  static const _staffTapTarget = 5;
  static const _staffTapWindow = Duration(milliseconds: 800);

  String get _lockedRoute => '/action-words/job/${widget.subjectId}';

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
          debugPrint('[kid-job] enter failed: $e\n$st');
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

  Future<void> _toggle(Subject subject, String verbId) async {
    if (_toggling.contains(verbId)) return;
    _toggling.add(verbId);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref.read(actionWordsActionsProvider).toggleDone(
            subjectId: subject.id,
            groupId: subject.groupId,
            date: todayKey(),
            verbId: verbId,
          );
    } on Object catch (e, st) {
      if (kDebugMode) debugPrint('[kid-job] toggle failed: $e\n$st');
    } finally {
      _toggling.remove(verbId);
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
            Positioned.fill(child: _body()),
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

  Widget _body() {
    final subject = ref.watch(subjectByIdProvider(widget.subjectId)).value;
    final dayAsync = ref.watch(
      actionWordsForDayProvider(
        (subjectId: widget.subjectId, date: todayKey()),
      ),
    );
    final topInset = MediaQuery.paddingOf(context).top;

    return dayAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Message(
        emoji: '💛',
        text: 'Show a grown-up!',
        topInset: topInset,
      ),
      data: (day) {
        if (!day.hasPicks) {
          // No self-navigation out of a locked kid surface: pushing the pick
          // screen here would let ITS dispose clear the shared
          // kidModeLockedRouteProvider pin and drop this screen's lock (the
          // single-slot collision both reviewers flagged). Staff exit via the
          // corner gesture and launch the pick screen from the roster instead.
          return _Message(
            emoji: '🌱',
            text: 'Pick your 3 words first!\nShow a grown-up.',
            topInset: topInset,
          );
        }
        return _JobList(
          subject: subject,
          day: day,
          topInset: topInset,
          onToggle: (verbId) {
            if (subject != null) unawaited(_toggle(subject, verbId));
          },
        );
      },
    );
  }
}

/// The day's jobs — one big card per picked verb, plus a header and an
/// all-done celebration. The list is what makes each kid's screen unique.
class _JobList extends ConsumerWidget {
  const _JobList({
    required this.subject,
    required this.day,
    required this.topInset,
    required this.onToggle,
  });

  final Subject? subject;
  final ActionWordsDay day;
  final double topInset;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roles = ref.watch(verbRolesProvider).value ?? const {};
    final verbs = verbsByIds(day.verbPicks);
    final firstName = subject?.firstName.trim() ?? '';
    final allDone = day.isComplete;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, topInset + 24, 20, 32),
      children: [
        Text(
          firstName.isEmpty ? 'Your jobs today!' : "$firstName's jobs today!",
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _Dots(done: day.doneCount, total: day.verbPicks.length),
        const SizedBox(height: 20),
        if (allDone) ...[
          const _AllDoneBanner(),
          const SizedBox(height: 16),
        ],
        // Stable keys: the conditional all-done banner inserts at index 0 and
        // shifts the cards; keys keep Flutter matching each card to its verb
        // (project convention for any growable multi-child list).
        for (final v in verbs)
          Padding(
            key: ValueKey('job-${v.id}'),
            padding: const EdgeInsets.only(bottom: 16),
            child: _JobCard(
              verb: v,
              role: roles[v.id],
              done: day.done.contains(v.id),
              onToggle: () => onToggle(v.id),
            ),
          ),
      ],
    );
  }
}

/// One verb's job, big and kid-legible. The verb's job title + level-1 mission
/// is the "reshape" — a child who picked Carry sees The Carrier's job, a child
/// who picked Play sees The Player's. Tapping toggles done.
class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.verb,
    required this.role,
    required this.done,
    required this.onToggle,
  });

  final Verb verb;
  final VerbRole? role;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Done cards warm to the primary container; undone sit on a calm surface.
    final fill = done ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final onFill = done ? scheme.onPrimaryContainer : scheme.onSurface;
    final title = (role != null && role!.jobTitle.isNotEmpty)
        ? 'You are ${role!.jobTitle}!'
        : '${verb.label}!';
    // Kid-facing "what to do": the simplest mission level; fall back to the
    // verb's lens so the card is never empty even off-curriculum.
    final mission = (role != null && role!.mission.level1.isNotEmpty)
        ? role!.mission.level1
        : verb.lens;

    return Semantics(
      button: true,
      label: '$title. ${done ? 'Done' : 'Tap when you finish'}',
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(verb.emoji, style: const TextStyle(fontSize: 52)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: onFill,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  mission,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: onFill.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                _DoneButton(done: done, onToggle: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big "I did it!" toggle — a kid-sized tap target (≥ 56 dp tall).
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.done, required this.onToggle});

  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: done
          ? FilledButton.icon(
              onPressed: onToggle,
              icon: const Icon(Icons.check_circle, size: 26),
              label: const Text(
                'Done! 🎉',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            )
          : FilledButton.tonalIcon(
              onPressed: onToggle,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.surface,
                foregroundColor: scheme.primary,
              ),
              icon: const Icon(Icons.radio_button_unchecked, size: 26),
              label: const Text(
                'I did it!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
    );
  }
}

/// Three (or N) big dots that fill as jobs are finished — a kid-legible meter.
class _Dots extends StatelessWidget {
  const _Dots({required this.done, required this.total});
  final int done;
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
                color: i < done ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: i < done ? scheme.primary : scheme.outline,
                  width: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          Text(
            'You did all your jobs!',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.emoji,
    required this.text,
    required this.topInset,
  });
  final String emoji;
  final String text;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
