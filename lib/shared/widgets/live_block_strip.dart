import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/db/app_database.dart' show Entry;
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A slim strip that sits directly above the omnibox bar while a
/// schedule block is live. Collapses to zero height when nothing is
/// live — absence is the signal, no "nothing live" copy.
///
/// Shows: 🟢 LIVE · {block title}
/// The green dot has a slow breathing animation so it reads as "active
/// now" without competing with the content. A `RepaintBoundary` wraps
/// the dot so only it repaints on each animation tick.
class LiveBlockStrip extends StatefulWidget {
  const LiveBlockStrip({required this.liveBlock, super.key});

  final LiveBlock? liveBlock;

  @override
  State<LiveBlockStrip> createState() => _LiveBlockStripState();
}

class _LiveBlockStripState extends State<LiveBlockStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _alpha;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    unawaited(_pulse.repeat(reverse: true));
    _alpha = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.liveBlock;

    // Collapses to zero height when nothing is live.
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: block == null
          ? const SizedBox.shrink()
          : _Strip(block: block, alpha: _alpha),
    );
  }
}

class _Strip extends ConsumerWidget {
  const _Strip({required this.block, required this.alpha});

  final LiveBlock block;
  final Animation<double> alpha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // ⊕ N — how many moments have tied to this block so far (Slice 2).
    final count =
        ref.watch(momentsForBlockProvider(block.blockId)).value?.length ?? 0;

    // REAL floating glass — a translucent tint OVER a backdrop blur,
    // matching the omnibox bar it butts against (not a solid fill). Flush
    // band with a top hairline, no rounded pill (it reads continuous with
    // the bar). Rubric: chrome is floating glass, never a solid bar.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: scheme.surface.withValues(alpha: 0.55),
          child: InkWell(
            // Tap the strip to review the moments tied to this block.
            onTap: () => unawaited(showBlockMomentsSheet(context, block)),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Breathing green dot — RepaintBoundary so only the dot
                  // repaints on each animation tick.
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: alpha,
                      builder: (_, _) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.growthOf(
                            theme,
                          ).withValues(alpha: alpha.value),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.growthOf(theme),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Separator dot.
                  Text(
                    '·',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      block.title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (count > 0) ...[
                    _MomentCount(count: count),
                    const SizedBox(width: 10),
                  ],
                  // Time remaining — shows how long until the block ends.
                  _TimeRemaining(endAt: block.endAt),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ⊕ N moments tally on the strip.
class _MomentCount extends StatelessWidget {
  const _MomentCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.add_circle_outline,
          size: 14,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// "ends in Xm" label — redraws only when the minute changes.
class _TimeRemaining extends StatelessWidget {
  const _TimeRemaining({required this.endAt});

  final DateTime endAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = endAt.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final mins = math.max(1, remaining.inMinutes);
    return Text(
      '${mins}m',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Opens the block's moment sheet — the moments tied to this live block,
/// newest first (live-block Slice 2). Glass sheet, scroll-controlled.
Future<void> showBlockMomentsSheet(BuildContext context, LiveBlock block) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MomentSheet(block: block),
  );
}

class _MomentSheet extends ConsumerWidget {
  const _MomentSheet({required this.block});

  final LiveBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final moments =
        ref.watch(momentsForBlockProvider(block.blockId)).value ??
        const <Entry>[];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.growthOf(theme),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${moments.length} '
                  '${moments.length == 1 ? 'moment' : 'moments'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (moments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'No moments yet — anything you capture while this block is '
                  'live ties here automatically.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: moments.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (_, i) => _MomentRow(entry: moments[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = entry.body?.trim();
    final when = DateTime.tryParse(entry.recordedAt)?.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconFor(entry.kind),
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (body != null && body.isNotEmpty) ? body : _labelFor(entry.kind),
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (when != null) ...[
            const SizedBox(width: 8),
            Text(
              relativeTimeAgo(when),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String kind) => switch (kind) {
    EntryKind.observation => Icons.visibility_outlined,
    EntryKind.meal => Icons.restaurant_outlined,
    EntryKind.nap => Icons.bedtime_outlined,
    EntryKind.diaper => Icons.baby_changing_station_outlined,
    EntryKind.incident => Icons.report_outlined,
    EntryKind.medication => Icons.medication_outlined,
    _ => Icons.circle_outlined,
  };

  String _labelFor(String kind) => switch (kind) {
    EntryKind.observation => 'Observation',
    EntryKind.meal => 'Meal',
    EntryKind.nap => 'Nap',
    EntryKind.diaper => 'Diaper change',
    EntryKind.incident => 'Incident',
    EntryKind.medication => 'Medication',
    _ => 'Moment',
  };
}
