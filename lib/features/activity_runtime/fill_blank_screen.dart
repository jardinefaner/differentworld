import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/fill-blank` — **Fill in the blank** (ad libs, docs/VISION.md
/// 2026-06-19). Host-present, no kid phone: a silly template hides its words;
/// the room shouts one for each blank ("give me an action word!"), the host
/// types it, and at the end the whole goofy sentence is REVEALED big — and the
/// room reads it out loud. Teacher-paced; ephemeral (a laugh, not a record).
class FillBlankScreen extends ConsumerStatefulWidget {
  const FillBlankScreen({super.key});

  @override
  ConsumerState<FillBlankScreen> createState() => _FillBlankScreenState();
}

class _FillBlankScreenState extends ConsumerState<FillBlankScreen> {
  // Shuffled once per session so "Another one" always advances; a re-open
  // re-shuffles. Built lazily from the bank.
  List<ContentItem>? _deck;
  int _deckIndex = 0;
  final List<String> _filled = <String>[];
  int _blankIndex = 0;
  bool _revealed = false;
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  List<ContentItem> _deckFrom(List<ContentItem> items) {
    final existing = _deck;
    if (existing != null) return existing;
    final picks = items.where((i) => i.kind == ContentKind.fillBlank).toList()
      ..shuffle();
    _deck = picks;
    return picks;
  }

  List<String> _blanksOf(ContentItem item) {
    final raw = item.payload['blanks'];
    return raw is List ? raw.map((e) => '$e').toList() : const <String>[];
  }

  void _submit(List<String> blanks) {
    final word = _input.text.trim();
    if (word.isEmpty) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _filled.add(word);
      _input.clear();
      if (_filled.length >= blanks.length) {
        _revealed = true;
      } else {
        _blankIndex++;
      }
    });
  }

  void _another() {
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _deckIndex++;
      _filled.clear();
      _blankIndex = 0;
      _revealed = false;
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = ref.watch(bankedContentProvider).value ?? curatedSeeds;
    final deck = _deckFrom(items);

    return EdgeScaffold(
      body: deck.isEmpty
          ? const EmptyState(
              icon: Icons.edit_note_outlined,
              title: 'Nothing to fill in yet',
              message:
                  'Fill-in-the-blank stories will appear here to play '
                  'with the room.',
            )
          : _body(theme, deck[_deckIndex % deck.length]),
    );
  }

  Widget _body(ThemeData theme, ContentItem item) {
    final template = (item.payload['template'] as String?) ?? '';
    final blanks = _blanksOf(item);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        children: [
          const ContentHeader(
            title: 'Fill in the blank',
            subtitle: 'Silly words make a silly story',
          ),
          if (_revealed) _reveal(theme, template) else _fill(theme, blanks),
        ],
      ),
    );
  }

  Widget _fill(ThemeData theme, List<String> blanks) {
    final scheme = theme.colorScheme;
    final isLast = _blankIndex == blanks.length - 1;
    final prompt = _blankIndex < blanks.length ? blanks[_blankIndex] : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Blank ${_blankIndex + 1} of ${blanks.length}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Give me… $prompt',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _input,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(blanks),
          decoration: const InputDecoration(
            hintText: 'Type the room’s word',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _submit(blanks),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
          ),
          icon: Icon(isLast ? Icons.celebration_outlined : Icons.arrow_forward),
          label: Text(isLast ? 'Reveal it!' : 'Next word'),
        ),
        const SizedBox(height: 18),
        // Progress dots — filled blanks vs remaining.
        Row(
          children: [
            for (var i = 0; i < blanks.length; i++) ...[
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= _blankIndex
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              if (i < blanks.length - 1) const SizedBox(width: 5),
            ],
          ],
        ),
      ],
    );
  }

  Widget _reveal(ThemeData theme, String template) {
    final scheme = theme.colorScheme;
    final base = theme.textTheme.displaySmall?.copyWith(
      color: scheme.onPrimaryContainer,
      fontWeight: FontWeight.w500,
      height: 1.25,
    );
    final fill = base?.copyWith(
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(26),
          child: Text.rich(
            TextSpan(children: _revealSpans(template, base, fill)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Read it out loud!',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _another,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Another one'),
        ),
      ],
    );
  }

  /// Splits the template on `{n}` placeholders and renders the room's words in
  /// the accent style so they pop when read.
  List<InlineSpan> _revealSpans(
    String template,
    TextStyle? base,
    TextStyle? fill,
  ) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\{(\d+)\}');
    var last = 0;
    for (final m in re.allMatches(template)) {
      if (m.start > last) {
        spans.add(
          TextSpan(text: template.substring(last, m.start), style: base),
        );
      }
      final idx = int.parse(m.group(1)!);
      final word = idx < _filled.length ? _filled[idx] : '___';
      spans.add(TextSpan(text: word, style: fill));
      last = m.end;
    }
    if (last < template.length) {
      spans.add(TextSpan(text: template.substring(last), style: base));
    }
    return spans;
  }
}
