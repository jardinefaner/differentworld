import 'dart:async';

import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One face of a presented deck — the content-agnostic shape ANY feature fills
/// to put a moment on the room's screen (docs/VISION.md 2026-06-20: *"everything
/// could be turned into slides… the cast/present"*). A child's day, a moment,
/// the words of the day, a week's project — each becomes a `List<PresentSlide>`.
@immutable
class PresentSlide {
  const PresentSlide({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.emoji,
    this.icon,
    this.accent,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;

  /// A glyph to lead with — `emoji` wins over `icon` when both are set.
  final String? emoji;
  final IconData? icon;

  /// Optional content colour; the projection deepens it over near-black so the
  /// slide carries the moment's hue while staying TV-dark.
  final Color? accent;
}

/// Arguments for the generic `/present-deck` route — a titled deck of slides.
typedef PresentDeckArgs = ({String title, List<PresentSlide> slides});

/// Throw a deck of slides to the room — the one call any feature makes to
/// present/cast its content. Opens the immersive [SlidePresentScreen]; the
/// staffer mirrors their screen to the TV (HDMI / AirPlay / Cast), the same
/// "show it on this screen" path the cast sheet offers.
Future<void> presentSlides(
  BuildContext context, {
  required String title,
  required List<PresentSlide> slides,
}) {
  if (slides.isEmpty) return Future<void>.value();
  return context.push<void>(
    '/present-deck',
    extra: (title: title, slides: slides),
  );
}

/// Full-screen, swipeable, castable presentation of an arbitrary deck — the
/// reusable present engine (the content-agnostic generalization of
/// `block_present_screen`). Immersive via [castImmersiveProvider]; a
/// deliberately-dark raw canvas (it lives on a TV regardless of OS theme) on
/// the theme-adherence allowlist.
class SlidePresentScreen extends ConsumerStatefulWidget {
  const SlidePresentScreen({required this.title, required this.slides, super.key});

  final String title;
  final List<PresentSlide> slides;

  @override
  ConsumerState<SlidePresentScreen> createState() => _SlidePresentScreenState();
}

class _SlidePresentScreenState extends ConsumerState<SlidePresentScreen> {
  late final CastImmersive _immersive;
  final PageController _page = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _immersive = ref.read(castImmersiveProvider.notifier);
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
    final slides = widget.slides;
    if (slides.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final current = slides[_index.clamp(0, slides.length - 1)];
    final bg = current.accent == null
        ? Colors.black
        : Color.alphaBlend(
            current.accent!.withValues(alpha: 0.30),
            const Color(0xFF0B0B0D),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        color: bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _page,
                        onPageChanged: (i) {
                          if (!mounted) return;
                          setState(() => _index = i);
                        },
                        itemCount: slides.length,
                        itemBuilder: (_, i) => _PresentFace(slide: slides[i]),
                      ),
                    ),
                    if (slides.length > 1)
                      _PageDots(
                        count: slides.length,
                        index: _index.clamp(0, slides.length - 1),
                        onTap: (i) => unawaited(
                          _page.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Exit',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresentFace extends StatelessWidget {
  const _PresentFace({required this.slide});

  final PresentSlide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glyph = slide.emoji != null
        ? Text(slide.emoji!, style: const TextStyle(fontSize: 58))
        : slide.icon != null
        ? Icon(slide.icon, size: 60, color: Colors.white70)
        : null;

    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (slide.eyebrow != null) ...[
            Text(
              slide.eyebrow!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white70,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (glyph != null) ...[glyph, const SizedBox(height: 22)],
          Text(
            slide.title,
            style: theme.textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.02,
            ),
          ),
          if (slide.subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              slide.subtitle!,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white60,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Generic page indicator for the deck — tappable dots, current one widened.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.onTap,
  });

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Semantics(
              button: true,
              label: i == index
                  ? 'Slide ${i + 1} of $count'
                  : 'Jump to slide ${i + 1} of $count',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == index ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
