import 'dart:async';
import 'dart:math';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/discussions.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `/activity/discussions` — Group Discussions (docs/VISION.md dream #6). A
/// TEACHER-hosted talk: pick a TOPIC + an AGE BAND, then the room talks
/// through one curated prompt at a time. NO typing, NO right answer — the
/// teacher reveals a deeper follow-up or moves on. Prompts come from the
/// kid-safe [discussionLibrary].
class GroupDiscussionScreen extends StatefulWidget {
  const GroupDiscussionScreen({super.key});

  @override
  State<GroupDiscussionScreen> createState() => _GroupDiscussionScreenState();
}

enum _Phase { setup, present, done }

class _GroupDiscussionScreenState extends State<GroupDiscussionScreen> {
  // Per-prompt full-screen colors so each starter feels distinct
  // ("color the whole screen" — docs/VISION.md dream #10).
  static const _palette = <Color>[
    ActivityPalette.indigo, // indigo
    ActivityPalette.teal, // teal
    ActivityPalette.pink, // bloom
    ActivityPalette.purple, // orchid
    ActivityPalette.amber, // amber
    ActivityPalette.blue, // sky
  ];

  _Phase _phase = _Phase.setup;
  DiscussionBand _band = DiscussionBand.middle;
  String? _topicId; // null = any topic
  List<Discussion> _deck = const [];
  int _index = 0;
  bool _deeper = false;

  Discussion get _current => _deck[_index];
  bool get _atEnd => _index >= _deck.length - 1;

  int get _available => discussionsFor(_band, topicId: _topicId).length;

  void _setBand(DiscussionBand band) {
    setState(() {
      _band = band;
      // Drop a topic that has nothing for the new band.
      if (_topicId != null &&
          !topicsFor(band).any((t) => t.id == _topicId)) {
        _topicId = null;
      }
    });
  }

  void _start() {
    final pool = discussionsFor(_band, topicId: _topicId)..shuffle(Random());
    if (pool.isEmpty) return;
    setState(() {
      _deck = pool.take(8).toList();
      _index = 0;
      _deeper = false;
      _phase = _Phase.present;
    });
  }

  void _next() {
    unawaited(HapticFeedback.selectionClick());
    if (_atEnd) {
      setState(() => _phase = _Phase.done);
      return;
    }
    setState(() {
      _index++;
      _deeper = false;
    });
  }

  void _back() {
    if (_index == 0) {
      setState(() => _phase = _Phase.setup);
      return;
    }
    setState(() {
      _index--;
      _deeper = false;
    });
  }

  void _restart() => setState(() {
    _phase = _Phase.setup;
    _deck = const [];
    _index = 0;
    _deeper = false;
  });

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: switch (_phase) {
        _Phase.setup => _setup(context),
        _Phase.present => _present(context),
        _Phase.done => _doneView(context),
      },
    );
  }

  // ── Setup: pick a topic + an age band (no typing) ─────────────────────
  Widget _setup(BuildContext context) {
    final theme = Theme.of(context);
    final topics = topicsFor(_band);
    return SafeArea(
      bottom: false,
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(
              title: 'Group Discussion',
              subtitle: 'Pick a topic and an age — the room talks it out',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'AGE',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<DiscussionBand>(
              segments: [
                for (final b in DiscussionBand.values)
                  ButtonSegment(value: b, label: Text(b.short)),
              ],
              selected: {_band},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _setBand(s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'TOPIC',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('✨  Any topic'),
                  selected: _topicId == null,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _topicId = null),
                ),
                for (final t in topics)
                  ChoiceChip(
                    label: Text('${t.emoji}  ${t.label}'),
                    selected: _topicId == t.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _topicId = t.id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 96),
            child: FilledButton.icon(
              onPressed: _available == 0 ? null : _start,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
              ),
              icon: const Icon(Icons.forum_outlined),
              label: Text(
                'Start — $_available ${_available == 1 ? 'prompt' : 'prompts'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Present: one big prompt, full-color, host controls ────────────────
  Widget _present(BuildContext context) {
    final color = _palette[_index % _palette.length];
    final topic = topicById(_current.topicId);
    final hasDeeper = _current.deeper != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.34)!],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  if (topic != null)
                    Text(
                      '${topic.emoji}  ${topic.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${_index + 1} / ${_deck.length}  ·  ${_band.short}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _current.prompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 8),
                            ],
                          ),
                        ),
                        if (_deeper && hasDeeper) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _current.deeper!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _controls(context, hasDeeper: hasDeeper),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, {required bool hasDeeper}) {
    const onColor = Colors.white;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton.icon(
            onPressed: _next,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            icon: Icon(_atEnd ? Icons.flag_outlined : Icons.arrow_forward),
            label: Text(
              _atEnd ? 'Wrap up' : 'Next prompt',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _back,
                style: OutlinedButton.styleFrom(
                  foregroundColor: onColor,
                  side: BorderSide(color: onColor.withValues(alpha: 0.6)),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
            if (hasDeeper) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _deeper = !_deeper),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onColor,
                    side: BorderSide(color: onColor.withValues(alpha: 0.6)),
                  ),
                  icon: Icon(_deeper ? Icons.unfold_less : Icons.unfold_more),
                  label: Text(_deeper ? 'Hide' : 'Go deeper'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── Done ──────────────────────────────────────────────────────────────
  Widget _doneView(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💬', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(
                'Great talk!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_deck.length} ${_deck.length == 1 ? 'prompt' : 'prompts'}, '
                'together.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.refresh),
                label: const Text('New discussion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
