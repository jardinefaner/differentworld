import 'dart:async';

import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
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
    this.imagePath,
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

  /// Optional photo — a Storage path or legacy URL. When set, it's the hero of
  /// the slide (the moment itself on the room screen), shown above any caption.
  /// Rendered via a signed URL, so it never rides PowerSync.
  final String? imagePath;
}

/// Arguments for the generic `/present-deck` route — a titled deck of slides,
/// plus the slide to open on (`initialIndex`, default 0).
typedef PresentDeckArgs = ({
  String title,
  List<PresentSlide> slides,
  int initialIndex,
});

/// Throw a deck of slides to the room — the one call any feature makes to
/// present/cast its content. Opens the immersive [SlidePresentScreen]; the
/// staffer mirrors their screen to the TV (HDMI / AirPlay / Cast), the same
/// "show it on this screen" path the cast sheet offers.
///
/// [initialIndex] opens the deck on a specific slide (clamped) — e.g. casting
/// from a session's current beat opens the room deck on that beat's slide.
/// Defaults to 0 (the start), so every existing call site is unaffected.
Future<void> presentSlides(
  BuildContext context, {
  required String title,
  required List<PresentSlide> slides,
  int initialIndex = 0,
}) {
  if (slides.isEmpty) return Future<void>.value();
  return context.push<void>(
    '/present-deck',
    extra: (title: title, slides: slides, initialIndex: initialIndex),
  );
}

/// Full-screen, swipeable, castable presentation of an arbitrary deck — the
/// reusable present engine (the content-agnostic generalization of
/// `block_present_screen`). Immersive via [castImmersiveProvider]; a
/// deliberately-dark raw canvas (it lives on a TV regardless of OS theme) on
/// the theme-adherence allowlist.
class SlidePresentScreen extends ConsumerStatefulWidget {
  const SlidePresentScreen({
    required this.title,
    required this.slides,
    this.initialIndex = 0,
    super.key,
  });

  final String title;
  final List<PresentSlide> slides;

  /// The slide to open on (clamped to the deck). Lets a caster open the deck at
  /// the current beat's slide instead of always at slide 0.
  final int initialIndex;

  @override
  ConsumerState<SlidePresentScreen> createState() => _SlidePresentScreenState();
}

class _SlidePresentScreenState extends ConsumerState<SlidePresentScreen> {
  late final CastImmersive _immersive;
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    // Seed the starting slide from initialIndex, clamped into the deck so a
    // stale/out-of-range index can never throw or land off the end.
    final lastIndex = widget.slides.isEmpty ? 0 : widget.slides.length - 1;
    _index = widget.initialIndex.clamp(0, lastIndex);
    _page = PageController(initialPage: _index);
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

    // A photo moment: the image is the hero; any caption sits beneath it.
    if (slide.imagePath != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: double.infinity,
                  child: PersonPhotoNetwork(
                    urlOrPath: slide.imagePath,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(color: Colors.white70),
                    ),
                    errorBuilder: (_) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (slide.eyebrow != null ||
                slide.title.isNotEmpty ||
                slide.subtitle != null) ...[
              const SizedBox(height: 16),
              if (slide.eyebrow != null) ...[
                Text(
                  slide.eyebrow!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (slide.title.isNotEmpty)
                Text(
                  slide.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
              if (slide.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  slide.subtitle!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white60,
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    }

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
