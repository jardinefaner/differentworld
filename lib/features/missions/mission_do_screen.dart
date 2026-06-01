import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/missions/mission_templates.dart';
import 'package:differentworld/features/missions/missions_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/missions/do` — the do-it + save-progress loop (docs/MISSIONS.md slice 2).
/// A mission's manual + its checklist; tick the steps as the room does them
/// for real, then "Mark it done" — which records a completion (an `entries`
/// row, kind 'mission') that feeds the track record + the growth book. No
/// typing, no grading; the back arrow exits (A6).
class MissionDoScreen extends ConsumerStatefulWidget {
  const MissionDoScreen({required this.mission, super.key});

  final Mission mission;

  @override
  ConsumerState<MissionDoScreen> createState() => _MissionDoScreenState();
}

class _MissionDoScreenState extends ConsumerState<MissionDoScreen> {
  late final List<String> _steps = decodeMissionActions(widget.mission.actions);
  late final List<bool> _checked = List<bool>.filled(_steps.length, false);
  bool _saving = false;
  bool _done = false;

  int get _doneCount => _checked.where((c) => c).length;

  Future<void> _markDone() async {
    if (_saving) return;
    setState(() => _saving = true);
    unawaited(HapticFeedback.mediumImpact());
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await runReported(
      library: 'missions',
      messenger: messenger,
      onError: 'Could not record the mission.',
      action: () => ref
          .read(missionActionsProvider)
          .complete(
            widget.mission,
            stepsDone: _doneCount,
            stepsTotal: _steps.length,
          ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _done = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      backFallbackRoute: '/settings/missions',
      body: ColoredBox(
        color: const Color(0xFF12231F),
        child: SafeArea(child: _done ? _confirm(context) : _doing(context)),
      ),
    );
  }

  Widget _doing(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.mission;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Text(
                  m.icon ?? '🎯',
                  style: const TextStyle(fontSize: 56),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Today's mission: ${m.name}",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (m.builds != null && m.builds!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Chip(
                    label: Text('builds ${m.builds}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              if (m.rules != null && m.rules!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THE MANUAL',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.rules!,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_steps.isNotEmpty) ...[
                const Text(
                  'CHECK EACH STEP AS YOU GO',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _steps.length; i++)
                  _StepRow(
                    key: ValueKey('step-$i'),
                    text: _steps[i],
                    checked: _checked[i],
                    onTap: () => setState(() => _checked[i] = !_checked[i]),
                  ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _markDone,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Mark it done!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirm(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Nice work!',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.mission.name} — done and saved.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.text,
    required this.checked,
    required this.onTap,
    super.key,
  });

  final String text;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                Icon(
                  checked ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: checked ? Colors.tealAccent : Colors.white38,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: checked ? Colors.white60 : Colors.white,
                      fontSize: 17,
                      decoration: checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
