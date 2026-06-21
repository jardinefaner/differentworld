import 'dart:async';

import 'package:differentworld/features/entities/linkified_text.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/reflections/reflection_providers.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Below this many seconds a session is "just a quick timer" — no reflection
/// is demanded (so the Stop button never trains dread). At/above, the face is
/// required (docs/VISION.md: "require the reflection only past a threshold").
const _reflectThresholdSeconds = 120;

/// The four how-did-it-go faces (the tap-a-face Scale primitive). Value is
/// `index + 1` (1–4); the colour follows the scheme so it reads in both modes.
const _faces = <(IconData, String)>[
  (Icons.sentiment_very_dissatisfied_outlined, 'Tough'),
  (Icons.sentiment_dissatisfied_outlined, 'Okay'),
  (Icons.sentiment_satisfied_outlined, 'Good'),
  (Icons.sentiment_very_satisfied_outlined, 'Great'),
];

/// `/reflect` — the stopwatch-then-reflect ritual (docs/VISION.md, 2026-06-14).
/// The clock counts UP (never a pomodoro box); on stop a how-did-it-go is
/// required; saved reflections stack into the growth strip below — the
/// accountability + growth made *visible*. Staff-facing by default (a
/// staffer's own practice → the runbook); a kid-scoped entry point can pass a
/// subject so it lands in that child's Book instead.
class ReflectionSessionScreen extends ConsumerStatefulWidget {
  const ReflectionSessionScreen({super.key});

  @override
  ConsumerState<ReflectionSessionScreen> createState() =>
      _ReflectionSessionScreenState();
}

class _ReflectionSessionScreenState
    extends ConsumerState<ReflectionSessionScreen> {
  Timer? _ticker;
  int _seconds = 0;
  bool _reflecting = false;
  int _face = 0; // 0 = unpicked
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _start() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _reflecting) return;
      setState(() => _seconds++);
    });
  }

  void _stop() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _reflecting = true);
  }

  /// Past the threshold a how-did-it-go is required; below it the face is
  /// optional (a quick timer shouldn't demand a reflection).
  bool get _faceRequired => _seconds >= _reflectThresholdSeconds;

  Future<void> _save() async {
    if (_saving || (_face == 0 && _faceRequired)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(entryActionsProvider).recordReflection(
            seconds: _seconds,
            face: _face,
            note: _note.text,
          );
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not save the reflection.')),
      );
      return;
    }
    if (!mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    _note.clear();
    // Fresh session — the just-saved one drops into the strip below.
    setState(() {
      _saving = false;
      _reflecting = false;
      _seconds = 0;
      _face = 0;
    });
    _start();
  }

  static String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final reflections = ref.watch(recentReflectionsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return EdgeScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const ContentHeader(
            title: 'Reflect',
            subtitle:
                'Time the real work — then say how it went. It stacks into '
                'something you can see.',
          ),
          _SessionCard(
            elapsed: _fmt(_seconds),
            reflecting: _reflecting,
            face: _face,
            faceRequired: _faceRequired,
            saving: _saving,
            note: _note,
            onStop: _stop,
            onPickFace: (f) => setState(() => _face = f),
            onSave: _save,
          ),
          const SizedBox(height: 24),
          Text('Your growth — visible', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          // Every branch here is a ListView CHILD, so it must be intrinsically
          // sized — no Center / Expanded / full-bleed EmptyState (they need a
          // bounded parent height and crash a list with `hasSize`).
          reflections.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Could not load your reflections.'),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timeline_outlined,
                        size: 34,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Finish a session above and your first one lands here '
                        '— then it only grows.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [for (final r in rows) _ReflectionTile(r: r)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.elapsed,
    required this.reflecting,
    required this.face,
    required this.faceRequired,
    required this.saving,
    required this.note,
    required this.onStop,
    required this.onPickFace,
    required this.onSave,
  });

  final String elapsed;
  final bool reflecting;
  final int face;
  final bool faceRequired;
  final bool saving;
  final TextEditingController note;
  final VoidCallback onStop;
  final ValueChanged<int> onPickFace;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          children: [
            Text(
              reflecting ? 'You stuck with it for' : 'Counting up',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              elapsed,
              style: theme.textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 18),
            if (!reflecting)
              FilledButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop & reflect'),
              )
            else ...[
              Text('How did it go?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _faces.length; i++)
                    _FaceButton(
                      icon: _faces[i].$1,
                      label: _faces[i].$2,
                      selected: face == i + 1,
                      onTap: () => onPickFace(i + 1),
                    ),
                ],
              ),
              if (!faceRequired)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Optional for a quick one',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: note,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'A line on what it became (optional)',
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                // Past the threshold a face is required; below it a quick
                // session can save without one.
                onPressed:
                    (saving || (face == 0 && faceRequired)) ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save reflection'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FaceButton extends StatelessWidget {
  const _FaceButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: tint),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tint,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReflectionTile extends StatelessWidget {
  const _ReflectionTile({required this.r});

  final ReflectionView r;

  static String _fmt(int s) {
    final m = (s % 3600) ~/ 60;
    final h = s ~/ 3600;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final faceIcon =
        (r.face >= 1 && r.face <= 4) ? _faces[r.face - 1].$1 : Icons.remove;
    final when = DateTime.tryParse(r.entry.recordedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(faceIcon, size: 20, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinkifiedText(
                  r.note ?? 'No note',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: r.note == null ? scheme.onSurfaceVariant : null,
                    fontStyle: r.note == null ? FontStyle.italic : null,
                  ),
                ),
                if (when != null)
                  Text(
                    relativeTimeAgo(when),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmt(r.seconds),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
