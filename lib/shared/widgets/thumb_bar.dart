import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/shared/widgets/shell_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A fixed control pinned under the thumb (CLAUDE.md, the half-second rule).
///
/// Two rules live here so no screen has to remember either:
///
/// 1. **The thumb owns the bottom.** What you read sits at the top; what you
///    press repeatedly sits down here. Not symmetry — the top of a phone is
///    out of reach one-handed, and a control you must look at is a control
///    you cannot use while talking. (`EdgeScaffold.actions` is the top pill,
///    which is right for a page's save/edit and wrong for an instrument's
///    repeated action.)
///
/// 2. **It clears the LIVE strip.** That strip floats over the body's bottom
///    edge whenever a block is live, and scrolling content passing under it
///    is fine — a FIXED control being covered by it is not. That seam buried
///    the message composer until it was found on device, and then buried the
///    arrangement button the same way a week later. Encoding it once is the
///    only reason it will not happen a third time.
class ThumbBar extends ConsumerWidget {
  const ThumbBar({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 12),
    super.key,
  });

  final Widget child;

  /// Base padding. The live-strip clearance is ADDED to its bottom, never
  /// replaces it.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveBlockProvider) != null;
    return Padding(
      padding: padding.copyWith(
        bottom: padding.bottom + (live ? ShellMetrics.liveStripHeight : 0),
      ),
      child: child,
    );
  }
}
