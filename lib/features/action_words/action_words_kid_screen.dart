import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verb_voice.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/widgets/kid_lock_shell.dart';
import 'package:differentworld/features/action_words/widgets/kid_progress_dots.dart';
import 'package:differentworld/features/action_words/widgets/verb_grid.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
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
/// unlocks it — the same hardening survey-take uses; the machinery lives in
/// [KidLockShell]. Picks save through the existing
/// `ActionWordsActions.setPicks` (one `action_words` entry per subject/day);
/// the revealed world stays hidden until the closing ceremony, exactly like
/// the teacher path.
class ActionWordsKidScreen extends ConsumerStatefulWidget {
  const ActionWordsKidScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  ConsumerState<ActionWordsKidScreen> createState() =>
      _ActionWordsKidScreenState();
}

class _ActionWordsKidScreenState extends ConsumerState<ActionWordsKidScreen>
    with WidgetsBindingObserver, KidLockShell<ActionWordsKidScreen> {
  final Set<String> _selected = {};
  // On-device voiceover so a pre-reader can HEAR each word. Owned here:
  // stopped in dispose. See verb_voice.dart.
  final VerbVoice _voice = VerbVoice();
  bool _saving = false;
  bool _saved = false;

  @override
  String get kidLockRoute => '/action-words/pick/${widget.subjectId}';

  @override
  String get kidLockDebugTag => 'action-words-kid';

  @override
  void dispose() {
    unawaited(_voice.stop());
    super.dispose();
  }

  void _toggle(String id) {
    if (_saved || _saving) return;
    // Speak the word on every tap — for a pre-reader, hearing it IS how they
    // browse, whether the tap selects, deselects, or bounces off the cap.
    final verb = verbById(id);
    if (verb != null) unawaited(_voice.speakVerb(verb));
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
      await ref
          .read(actionWordsActionsProvider)
          .setPicks(
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
      // Read the three chosen words back so a pre-reader hears their pick.
      final picked = verbsByIds(
        _selected.toList(),
      ).map((v) => v.label).join(', ');
      unawaited(_voice.say('Your words today. $picked.'));
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

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(subjectByIdProvider(widget.subjectId)).value;
    return buildKidLockShell(body: _body(subject));
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
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.volume_up_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tap a word to hear it',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              KidProgressDots(filled: _selected.length, total: kPicksPerDay),
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
          Text(
            '✨',
            style: TextStyle(
              fontSize: theme.textTheme.displayLarge?.fontSize ?? 56,
            ),
          ),
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
