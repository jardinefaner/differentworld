import 'dart:async';
import 'dart:math' as math;

import 'package:differentworld/features/action_words/verb_skills.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/entries/entries_read_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/world/skill_measure.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/skills/:subjectId/:skillId` — one skill's PROGRESSION for a child
/// (docs/VISION.md "the number IS the story"). The current number, the rising
/// curve, the delta from day one, and "they practiced it N times — now it's
/// theirs." Reads the same `skill_measure` entries the character sheet does;
/// "Practice again" reopens the recorder.
class SkillDetailScreen extends ConsumerWidget {
  const SkillDetailScreen({
    required this.subjectId,
    required this.skillId,
    super.key,
  });

  final String subjectId;
  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vs = verbSkillById(skillId);
    if (vs == null) {
      return const EdgeScaffold(
        body: EmptyState(
          icon: Icons.help_outline,
          title: 'Unknown skill',
          message: 'That skill is no longer in the catalog.',
        ),
      );
    }
    // Both providers stream the SAME local SQLite, so the subject arrives with
    // (or before) the entries; the '?' fallback only shows for the sub-second
    // cold-launch window, then resolves — an intentional soft default, not a
    // gate.
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    final firstName = subject?.firstName ?? 'this child';
    final key = (subjectId: subjectId, kind: EntryKind.skillMeasure);
    final entriesAsync = ref.watch(entriesForSubjectProvider(key));

    return EdgeScaffold(
      body: SafeArea(
        bottom: false,
        child: entriesAsync.when(
          loading: () => const LoadingSlot(),
          error: (_, _) => ErrorState(
            title: "Couldn't load the arc",
            onRetry: () => ref.invalidate(entriesForSubjectProvider(key)),
          ),
          data: (entries) => _Arc(
            subjectId: subjectId,
            firstName: firstName,
            groupId: subject?.groupId,
            skill: vs,
            arc: skillArcFor(entries, skillId),
          ),
        ),
      ),
    );
  }
}

class _Arc extends StatelessWidget {
  const _Arc({
    required this.subjectId,
    required this.firstName,
    required this.groupId,
    required this.skill,
    required this.arc,
  });

  final String subjectId;
  final String firstName;
  final String? groupId;
  final VerbSkill skill;
  final SkillArc arc;

  static String _bare(num v) => v % 1 == 0 ? v.toInt().toString() : '$v';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final verb = verbById(skill.verbId);
    final ms = measurableSkillById(skill.id);
    String fmt(num v) => ms?.format(v) ?? _bare(v);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            ContentHeader(
              title:
                  '${verb?.emoji ?? ''} ${verb?.label ?? ''} · ${skill.name}',
              subtitle: arc.isEmpty
                  ? '$firstName · not measured yet'
                  : '$firstName · ${arc.reps} ${arc.reps == 1 ? 'rep' : 'reps'}',
            ),
            if (arc.isEmpty)
              _EmptyArc(key: const ValueKey('skill-empty-arc'), how: skill.how)
            else ...[
              Row(
                key: const ValueKey('skill-data-arc'),
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      fmt(arc.latest),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'latest',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                skill.how,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // The chart is decorative — the number + the delta card carry the
              // data — so a screen reader skips it.
              Semantics(
                label: 'Progression chart',
                excludeSemantics: true,
                child: SizedBox(
                  height: 92,
                  child: CustomPaint(
                    painter: _SkillSparkline(
                      series: [for (final m in arc.series) m.value.toDouble()],
                      higherIsBetter: skill.higherIsBetter,
                      accent: accent,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _DeltaCard(
                skill: skill,
                arc: arc,
                firstName: firstName,
                fmt: fmt,
              ),
              const SizedBox(height: 18),
            ],
            FilledButton.icon(
              onPressed: () => unawaited(
                showSkillMeasureSheet(
                  context,
                  subjectId: subjectId,
                  firstName: firstName,
                  groupId: groupId,
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(arc.isEmpty ? 'Log the first rep' : 'Practice again'),
            ),
            const SizedBox(height: 10),
            Text(
              'week 1: ${skill.week1}   →   week 10: ${skill.week10}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyArc extends StatelessWidget {
  const _EmptyArc({required this.how, super.key});
  final String how;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(
            Icons.timeline_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            how,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'The first rep starts the story.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The delta + the affirmation — the emotional payload ("they did that").
class _DeltaCard extends StatelessWidget {
  const _DeltaCard({
    required this.skill,
    required this.arc,
    required this.firstName,
    required this.fmt,
  });

  final VerbSkill skill;
  final SkillArc arc;
  final String firstName;
  final String Function(num) fmt;

  String get _impUnit => switch (skill.measure) {
    SkillMeasureKind.seconds => ' seconds',
    SkillMeasureKind.count => '',
    SkillMeasureKind.frequency => ' a day',
    SkillMeasureKind.rating => ' points',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final imp = arc.improvement(higherIsBetter: skill.higherIsBetter);

    final String head;
    final String body;
    if (arc.reps < 2) {
      head = fmt(arc.latest);
      body = 'First rep logged. The number only goes from here.';
    } else if (imp > 0) {
      head =
          '${fmt(arc.first)} → ${fmt(arc.latest)}  ·  '
          '+${_Arc._bare(imp)}$_impUnit';
      body =
          'Nobody taught $firstName this. They practiced it ${arc.reps} '
          'times. Now it belongs to them.';
    } else {
      head = '${fmt(arc.first)} → ${fmt(arc.latest)}';
      body =
          'The curve wiggles before it climbs. Keep practicing — the number '
          'remembers.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            head,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// A value sparkline. For a speed skill (lower-is-better) the plot is flipped so
/// improvement always reads as the line going UP.
class _SkillSparkline extends CustomPainter {
  _SkillSparkline({
    required this.series,
    required this.higherIsBetter,
    required this.accent,
  });

  final List<double> series;
  final bool higherIsBetter;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final lo = series.reduce(math.min);
    final hi = series.reduce(math.max);
    final range = (hi - lo).abs() < 1e-9 ? 1.0 : (hi - lo);
    final n = series.length;

    Offset pt(int i) {
      final x = n == 1 ? size.width / 2 : size.width * i / (n - 1);
      // Flip for speed skills so a smaller number sits higher.
      final v = higherIsBetter ? series[i] : (hi + lo - series[i]);
      final norm = (v - lo) / range; // 0..1
      final y = size.height - norm * size.height;
      return Offset(
        x.clamp(4.0, size.width - 4.0),
        y.clamp(5.0, size.height - 5.0),
      );
    }

    final path = Path();
    for (var i = 0; i < n; i++) {
      final p = pt(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = accent.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(pt(0), 3.5, Paint()..color = accent.withValues(alpha: 0.5))
      ..drawCircle(pt(n - 1), 4.5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_SkillSparkline old) =>
      !listEquals(old.series, series) ||
      old.accent != accent ||
      old.higherIsBetter != higherIsBetter;
}
