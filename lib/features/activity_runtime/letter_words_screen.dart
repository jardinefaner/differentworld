import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/kid_mode_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/starts-with` — the "every answer starts with this letter"
/// game (docs/ACTIVITY_RUNTIME.md). Same generate-to-a-constraint loop as
/// math inverse, with letters: a category (from the content bank) + a
/// letter → the kid brainstorms as many words as they can that fit, each
/// validated live → a recap of their haul.
///
/// Validation is LOCAL + free: starts-with-letter is a character check;
/// novelty is "not already in your list". Category-fit is honor/peer for
/// now (a cached valid-answer set per category+letter is the CONTENT_BANK
/// follow-up that also lets us auto-credit). No AI on the hot path.
class LetterWordsScreen extends ConsumerStatefulWidget {
  const LetterWordsScreen({super.key});

  @override
  ConsumerState<LetterWordsScreen> createState() => _LetterWordsScreenState();
}

class _LetterWordsScreenState extends ConsumerState<LetterWordsScreen>
    with WidgetsBindingObserver, KidModeLock<LetterWordsScreen> {
  static const _route = '/activity/starts-with';

  // Kid-friendly letters (skips the near-impossible X/Z/Q).
  static const _letters = ['C', 'K', 'B', 'S', 'T', 'P', 'M', 'D', 'F', 'R'];

  final LocalContentBank _bank = LocalContentBank.seeded();
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();

  late ContentItem _category;
  late String _letter;
  int _letterIndex = 0;
  final List<String> _words = [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _category = _bank.next(ContentKind.category) ?? _fallbackCategory();
    _letter = _letters[0];
    enterKidLock(_route);
  }

  @override
  void dispose() {
    exitKidLock();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  ContentItem _fallbackCategory() => const ContentItem(
    kind: ContentKind.category,
    fingerprint: 'a-word',
    payload: {'label': 'a word'},
  );

  String get _categoryLabel => _category.payload['label']! as String;

  ({bool valid, bool novel}) _check(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return (valid: false, novel: false);
    final valid = t.startsWith(_letter.toLowerCase());
    final novel = !_words.map((w) => w.toLowerCase()).contains(t);
    return (valid: valid, novel: novel);
  }

  void _onChanged(String _) => setState(() {});

  void _add() {
    final word = _ctl.text.trim();
    final v = _check(word);
    if (!v.valid || !v.novel) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _words.add(word);
      _ctl.clear();
    });
    _refocus();
  }

  void _newRound() {
    final next = _bank.next(ContentKind.category);
    setState(() {
      if (next != null) {
        _category = next;
      } else {
        _bank.reset();
        _category = _bank.next(ContentKind.category) ?? _fallbackCategory();
      }
      _letterIndex = (_letterIndex + 1) % _letters.length;
      _letter = _letters[_letterIndex];
      _words.clear();
      _ctl.clear();
      _done = false;
    });
    _refocus();
  }

  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _done) return;
      _focus.requestFocus();
      // requestFocus alone can skip the Android IME (interaction #4).
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildKidLock(child: _done ? _recap(context) : _play(context));
  }

  Widget _play(BuildContext context) {
    final theme = Theme.of(context);
    final v = _check(_ctl.text);
    final canAdd = v.valid && v.novel;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _LetterChip(letter: _letter),
                const SizedBox(height: 16),
                Text(
                  'Name $_categoryLabel that starts with $_letter',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _ctl,
                  focusNode: _focus,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'a word starting with $_letter…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  onChanged: _onChanged,
                  onSubmitted: (_) => _add(),
                ),
                const SizedBox(height: 10),
                _Verdict(text: _ctl.text, letter: _letter, check: v),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: canAdd ? _add : null,
                  child: const Text('Add it'),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _words.isEmpty
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final w in _words)
                                Chip(
                                  label: Text(w),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                TextButton(
                  onPressed: _words.isEmpty
                      ? null
                      : () {
                          _focus.unfocus();
                          setState(() => _done = true);
                        },
                  child: Text(
                    "I'm done (${_words.length})",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _recap(BuildContext context) {
    final theme = Theme.of(context);
    final n = _words.length;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  n == 0
                      ? 'No words this round'
                      : '$n ${n == 1 ? 'word' : 'words'} that start with $_letter!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _categoryLabel,
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in _words)
                      Chip(
                        label: Text(w),
                        backgroundColor: Colors.amberAccent.withValues(
                          alpha: 0.9,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                FilledButton.tonal(
                  onPressed: _newRound,
                  child: const Text('New round'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hand the device back to your teacher.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.amberAccent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 40,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.text,
    required this.letter,
    required this.check,
  });

  final String text;
  final String letter;
  final ({bool valid, bool novel}) check;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    final (String msg, Color color, IconData icon) = trimmed.isEmpty
        ? (
            'Type a word that starts with $letter',
            Colors.white54,
            Icons.edit_outlined,
          )
        : !check.valid
        ? (
            'Oops — it needs to start with $letter',
            Colors.redAccent,
            Icons.close,
          )
        : !check.novel
        ? ('You already have that one!', Colors.amberAccent, Icons.refresh)
        : ('Nice! tap Add it', Colors.greenAccent, Icons.check_circle);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}
