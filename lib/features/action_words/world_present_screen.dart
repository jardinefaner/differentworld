import 'dart:async';

import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:differentworld/shared/platform/fullscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/present-world/:id` — **project the world to the room.** A fullscreen,
/// high-contrast slideshow of the world (title → question → each Watch → Do
/// cue → the verbs → the activities), sized to be read from across a room on
/// the screen/projector the device is mirrored to. The curriculum's
/// "laptop → projector" moment, in the app. Swipe or tap the edges to
/// advance. Goes fully immersive (hides app chrome + the OS bars).
class WorldPresentScreen extends ConsumerStatefulWidget {
  const WorldPresentScreen({required this.worldId, super.key});

  final String worldId;

  @override
  ConsumerState<WorldPresentScreen> createState() => _WorldPresentScreenState();
}

class _WorldPresentScreenState extends ConsumerState<WorldPresentScreen> {
  final _page = PageController();
  late final CastImmersive _immersive;
  int _index = 0;
  int _count = 1;

  @override
  void initState() {
    super.initState();
    // Cache the notifier (don't touch ref in dispose) — the cast pattern.
    _immersive = ref.read(castImmersiveProvider.notifier);
    // Defer the provider write out of the build phase (the chrome trap),
    // and guard on `mounted` so a fast pop can't leave the chrome hidden:
    // if we're already disposed when the microtask drains, dispose's
    // exit() + edgeToEdge already ran, so we must NOT re-enter. Keep the
    // immersive OS call INSIDE the same microtask so the two stay in lockstep.
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        _immersive.enter();
        unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
        );
      }),
    );
  }

  @override
  void dispose() {
    _immersive.exit();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = ref
        .watch(curriculumWorldsProvider)
        .whenOrNull(
          data: (worlds) {
            for (final w in worlds) {
              if (w.id == widget.worldId) return w;
            }
            return null;
          },
        );
    if (world == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final slides = _slidesFor(world);
    _count = slides.length;
    final accent = world.color;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(accent.withValues(alpha: 0.45), Colors.black),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _page,
                itemCount: slides.length,
                onPageChanged: (i) {
                  if (mounted) setState(() => _index = i);
                },
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 56,
                  ),
                  child: slides[i],
                ),
              ),
              // Tap zones: left third = back, right third = forward. Opaque,
              // or a childless GestureDetector hit-tests nothing and the tap
              // falls through to the PageView (tap-to-advance silently dead).
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _go(-1),
                      ),
                    ),
                    const Spacer(),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _go(1),
                      ),
                    ),
                  ],
                ),
              ),
              // Close
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              // Fullscreen — top-left, web only (native is already fullscreen
              // via immersiveSticky). The "view it on the TV" toggle.
              if (webFullscreenSupported)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    tooltip: 'Fullscreen',
                    icon: const Icon(Icons.fullscreen, color: Colors.white70),
                    onPressed: () => unawaited(toggleWebFullscreen()),
                  ),
                ),
              // Progress dots
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < slides.length; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index ? Colors.white : Colors.white24,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(int delta) {
    if (!mounted) return;
    final next = (_index + delta).clamp(0, _count - 1);
    if (next == _index) return;
    unawaited(
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      ),
    );
  }

  List<Widget> _slidesFor(CurriculumWorld w) {
    return [
      _TitleSlide(world: w),
      _BigText(label: 'Week ${w.week}', big: '“${w.question}”'),
      for (final v in w.videos)
        _BigText(
          label: 'Watch · ${v.minutes} min',
          big: v.title,
          sub: '→ ${v.after}',
        ),
      _VerbsSlide(world: w),
      _ActivitiesSlide(world: w),
    ];
  }
}

class _TitleSlide extends StatelessWidget {
  const _TitleSlide({required this.world});
  final CurriculumWorld world;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(world.emoji, style: const TextStyle(fontSize: 140)),
        const SizedBox(height: 24),
        Text(
          'WEEK ${world.week}',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 22,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          world.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          world.tagline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 24,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _BigText extends StatelessWidget {
  const _BigText({required this.label, required this.big, this.sub});
  final String label;
  final String big;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 20,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          big,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 20),
          Text(
            sub!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 26),
          ),
        ],
      ],
    );
  }
}

class _VerbsSlide extends StatelessWidget {
  const _VerbsSlide({required this.world});
  final CurriculumWorld world;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'THIS WEEK’S VERBS',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 20,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 32),
        for (final id in world.featuredVerbs)
          if (verbById(id) case final v?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${v.emoji}  ${v.label.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      ],
    );
  }
}

class _ActivitiesSlide extends StatelessWidget {
  const _ActivitiesSlide({required this.world});
  final CurriculumWorld world;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACTIVITIES',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 20,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 20),
        for (final a in world.activities.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              '•  ${a.split(':').first}',
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
          ),
      ],
    );
  }
}
