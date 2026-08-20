import 'dart:async';

import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:differentworld/features/story/story_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/story/:subjectId/play` — **play the story** (docs/VISION.md 2026-06-19,
/// the showcase: "the drawing becomes a film"). The child's Story moments,
/// oldest → newest, presented one at a time over a calm stage — auto-advancing
/// so a staffer can hold the phone up and the room watches it unfold. Tap to
/// move on, the play/pause control to hold a beat. A presentation of what the
/// Story timeline already gathers; it adds no data.
class StoryShowcaseScreen extends ConsumerStatefulWidget {
  const StoryShowcaseScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  ConsumerState<StoryShowcaseScreen> createState() =>
      _StoryShowcaseScreenState();
}

class _StoryShowcaseScreenState extends ConsumerState<StoryShowcaseScreen> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  int _count = 0;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted || !_playing || _count == 0) return;
    // The timer starts in initState but the PageView only attaches once entries
    // load — never page an unattached controller.
    if (!_controller.hasClients) return;
    if (_index >= _count - 1) {
      // Reached the end — hold on the last beat.
      setState(() => _playing = false);
      return;
    }
    unawaited(
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      ),
    );
  }

  void _advance() {
    if (!_controller.hasClients || _index >= _count - 1) return;
    unawaited(
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  /// Moments worth showing — drop the routine logistics + the sensitive
  /// incident beats; a showcase celebrates. Oldest-first so the story builds.
  List<Moment> _showable(List<Moment> all) {
    const skip = {
      EntryKind.meal,
      EntryKind.nap,
      EntryKind.diaper,
      EntryKind.medication,
      EntryKind.incident,
      EntryKind.departure,
    };
    return [
      for (final m in all.reversed)
        if (!skip.contains(m.entry.kind)) m,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(subjectByIdProvider(widget.subjectId)).value;
    final firstName = subject?.firstName ?? 'This child';
    final momentsAsync = ref.watch(
      momentsForSubjectProvider(widget.subjectId),
    );

    return EdgeScaffold(
      body: momentsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const EmptyState(
          icon: Icons.movie_outlined,
          title: 'Could not play the story',
          message: 'Try again in a moment.',
        ),
        data: (allMoments) {
          final moments = _showable(allMoments);
          _count = moments.length;
          if (moments.isEmpty) {
            return EmptyState(
              icon: Icons.movie_outlined,
              title: 'No story to play yet',
              message:
                  'As $firstName’s moments gather, you’ll be able to play '
                  'their story here.',
            );
          }
          return Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: moments.length,
                onPageChanged: (i) {
                  // An in-flight nextPage animation can complete after a pop.
                  if (mounted) setState(() => _index = i);
                },
                itemBuilder: (context, i) => GestureDetector(
                  onTap: _advance,
                  behavior: HitTestBehavior.opaque,
                  child: _MomentStage(
                    moment: moments[i],
                    childName: firstName,
                  ),
                ),
              ),
              // Progress dots + the play/pause, low so they don't fight the art.
              Positioned(
                left: 0,
                right: 0,
                bottom: 92,
                child: _Controls(
                  count: moments.length,
                  index: _index,
                  playing: _playing,
                  onToggle: () => setState(() => _playing = !_playing),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One beat, full-bleed — the photo when there is one, else the emoji + title
/// on a calm tinted ground, with the caption over a soft gradient.
class _MomentStage extends ConsumerWidget {
  const _MomentStage({required this.moment, required this.childName});

  final Moment moment;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final photo = moment.showsPhotos
        ? ref
              .watch(
                attachmentsForEntityProvider((
                  kind: 'entry',
                  id: moment.entry.id,
                )),
              )
              .value
              ?.urls
              .firstOrNull
        : null;

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            PersonPhotoNetwork(
              urlOrPath: photo,
              errorBuilder: (_) => _emojiGround(scheme),
            )
          else
            _emojiGround(scheme),
          // Caption band.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 132),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${moment.emoji}  ${moment.title}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      // Over-photo scrim label (the family_today pattern).
                      color: Colors.white, // raw-canvas
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (moment.body != null && moment.body!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      moment.body!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emojiGround(ColorScheme scheme) => ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Center(
      child: Text(moment.emoji, style: const TextStyle(fontSize: 120)),
    ),
  );
}

/// Progress dots + play/pause.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.count,
    required this.index,
    required this.playing,
    required this.onToggle,
  });

  final int count;
  final int index;
  final bool playing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: playing ? 'Pause' : 'Play',
          onPressed: onToggle,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        ),
        const SizedBox(width: 14),
        // A compact progress readout — dots get unwieldy past ~12 beats.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${index + 1} / $count',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}
