import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/activity/this-or-that` — a TEACHER-hosted brain break (game-show-host
/// model, not handed to a kid). One session, two VIEWS by form factor:
///
///   - **Presentation** (wide screen / projector): the pair, big, for the
///     room to see + react to (hands up, move to a side).
///   - **Control** (phone): the host's remote — Back / Reveal / Next +
///     progress. The phone drives the slides.
///
/// Single-device for now: a laptop shows presentation + a control bar; a
/// phone shows the control with a preview. The LIVE two-device link (phone
/// controls a separate projector via a realtime session) is the next
/// layer — this proves the separation of concerns first.
class ThisOrThatScreen extends ConsumerStatefulWidget {
  const ThisOrThatScreen({super.key});

  @override
  ConsumerState<ThisOrThatScreen> createState() => _ThisOrThatScreenState();
}

class _ThisOrThatScreenState extends ConsumerState<ThisOrThatScreen> {
  static const _wideBreakpoint = 720.0;

  late final LocalContentBank _bank;
  late final List<ContentItem> _pairs;

  @override
  void initState() {
    super.initState();
    // Draw from the banked snapshot (curated ∪ synced AI/crowd), falling
    // back to curated-only until the DB tier has synced. Build our OWN
    // bank so this session's seen-tracking is independent of any other.
    final snapshot = ref.read(bankedContentProvider).value ?? curatedSeeds;
    _bank = LocalContentBank(snapshot);
    _pairs = _bank.take(ContentKind.thisOrThat, 8);
  }

  int _index = 0;
  bool _revealed = false; // the "why?" discussion prompt is showing
  bool _done = false;

  // Per-pair palette so each slide has its own two-tone split.
  static const _palette = <(Color, Color)>[
    (Color(0xFFEF5350), Color(0xFF42A5F5)),
    (Color(0xFFFFA726), Color(0xFF26A69A)),
    (Color(0xFFAB47BC), Color(0xFF66BB6A)),
    (Color(0xFF5C6BC0), Color(0xFFFFCA28)),
    (Color(0xFFEC407A), Color(0xFF29B6F6)),
  ];

  String get _a => _pairs[_index].payload['a']! as String;
  String get _b => _pairs[_index].payload['b']! as String;
  bool get _atEnd => _index >= _pairs.length - 1;

  void _next() {
    unawaited(HapticFeedback.selectionClick());
    if (_atEnd) {
      setState(() => _done = true);
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  void _back() {
    if (_done) {
      setState(() => _done = false);
      return;
    }
    if (_index == 0) return;
    setState(() {
      _index--;
      _revealed = false;
    });
  }

  void _toggleReveal() => setState(() => _revealed = !_revealed);

  void _restart() => setState(() {
    _index = 0;
    _revealed = false;
    _done = false;
  });

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      actions: [
        SecondaryActionButton(
          tooltip: 'Present on a big screen',
          icon: Icons.cast,
          onPressed: () => unawaited(context.push('/live/this-or-that')),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideBreakpoint;
          return wide ? _wideLayout(context) : _phoneLayout(context);
        },
      ),
    );
  }

  // Big screen: presentation fills, a slim control bar at the bottom so a
  // single laptop both presents and is controlled.
  Widget _wideLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _presentation(context)),
        _ControlBar(
          index: _index,
          total: _pairs.length,
          revealed: _revealed,
          done: _done,
          onBack: _back,
          onReveal: _toggleReveal,
          onNext: _next,
          onRestart: _restart,
        ),
      ],
    );
  }

  // Phone: the control IS the focus — a small preview on top, big controls
  // below. ("The phone becomes the coordination + next-slide control.")
  Widget _phoneLayout(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          SizedBox(height: 220, child: _presentation(context)),
          Expanded(
            child: _ControlPanel(
              index: _index,
              total: _pairs.length,
              revealed: _revealed,
              done: _done,
              onBack: _back,
              onReveal: _toggleReveal,
              onNext: _next,
              onRestart: _restart,
            ),
          ),
        ],
      ),
    );
  }

  Widget _presentation(BuildContext context) {
    if (_done) return const _WrapSlide();
    final (colorA, colorB) = _palette[_index % _palette.length];
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              child: _Half(text: _a, color: colorA),
            ),
            Expanded(
              child: _Half(text: _b, color: colorB),
            ),
          ],
        ),
        const Center(child: _OrBadge()),
        if (_revealed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              child: const Text(
                'Why? Turn to a partner and tell them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.28)!],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FittedBox(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrBadge extends StatelessWidget {
  const _OrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'OR',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _WrapSlide extends StatelessWidget {
  const _WrapSlide();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1B1B2F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎉', style: TextStyle(fontSize: 56)),
            SizedBox(height: 12),
            Text(
              "That's a wrap!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The host control — slim, for the bottom of the presentation (wide).
class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.index,
    required this.total,
    required this.revealed,
    required this.done,
    required this.onBack,
    required this.onReveal,
    required this.onNext,
    required this.onRestart,
  });

  final int index;
  final int total;
  final bool revealed;
  final bool done;
  final VoidCallback onBack;
  final VoidCallback onReveal;
  final VoidCallback onNext;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                done ? 'Done' : '${index + 1} / $total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: (index == 0 && !done) ? null : onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
              const SizedBox(width: 8),
              if (done)
                FilledButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.replay),
                  label: const Text('Again'),
                )
              else ...[
                FilledButton.tonalIcon(
                  onPressed: onReveal,
                  icon: Icon(
                    revealed ? Icons.visibility_off : Icons.lightbulb_outline,
                  ),
                  label: Text(revealed ? 'Hide' : 'Discuss'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The host control — big, phone-focused (the phone is the remote).
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.index,
    required this.total,
    required this.revealed,
    required this.done,
    required this.onBack,
    required this.onReveal,
    required this.onNext,
    required this.onRestart,
  });

  final int index;
  final int total;
  final bool revealed;
  final bool done;
  final VoidCallback onBack;
  final VoidCallback onReveal;
  final VoidCallback onNext;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            done ? 'Done' : 'Slide ${index + 1} of $total',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (done)
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.replay),
                label: const Text('Start over'),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward, size: 28),
                label: const Text(
                  'Next',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (index == 0) ? null : onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReveal,
                    icon: Icon(
                      revealed ? Icons.visibility_off : Icons.lightbulb_outline,
                    ),
                    label: Text(revealed ? 'Hide' : 'Discuss'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
