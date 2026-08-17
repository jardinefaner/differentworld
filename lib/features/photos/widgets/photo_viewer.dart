import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:differentworld/features/photos/person_photo_url.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// The one full-screen photo viewer. Swipe between photos in a list; pinch /
/// double-tap to zoom each; drag down to dismiss; tap to hide the chrome; Share
/// or Cast the current one; an optional caption per photo.
///
/// Used by every place that shows photo thumbnails (observation feed, per-child
/// timeline, family recap, heroes, work gallery…). Open via [PhotoViewer.open]
/// — upgrading THIS widget upgrades every surface at once.
class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer({
    required this.urls,
    required this.initialIndex,
    this.captions,
    super.key,
  });

  final List<String> urls;
  final int initialIndex;

  /// Optional per-photo caption (who / when / the note), aligned to [urls].
  /// Missing / blank entries just render no caption.
  final List<String>? captions;

  /// Push a full-screen viewer on top of the current route. Non-opaque so the
  /// drag-to-dismiss fade reveals what's behind.
  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
    List<String>? captions,
  }) {
    if (urls.isEmpty) return Future.value();
    // rootNavigator: escape the app shell so the floating chrome pills +
    // omnibox bar don't paint over the full-bleed viewer (CLAUDE.md trap).
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: false,
        pageBuilder: (_, _, _) => PhotoViewer(
          urls: urls,
          initialIndex: initialIndex.clamp(0, urls.length - 1),
          captions: captions,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  late final PageController _page;
  late int _index;
  bool _chrome = true;
  bool _zoomed = false;
  double _dragDy = 0;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _page = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _toggleChrome() => setState(() => _chrome = !_chrome);

  void _onZoomChanged(bool zoomed) {
    if (zoomed == _zoomed) return;
    setState(() {
      _zoomed = zoomed;
      if (zoomed) _chrome = false; // clear the frame while inspecting
    });
  }

  void _onDragUpdate(double dy) {
    // Belt-and-suspenders: even if a drag arrives mid-zoom-animation (before the
    // GestureDetector's rebuild nulls its handlers), never dismiss while zoomed.
    if (_zoomed) return;
    setState(() => _dragDy += dy);
  }

  void _onDragEnd(double velocity) {
    if (_zoomed) return;
    if (_dragDy.abs() > 120 || velocity.abs() > 700) {
      unawaited(Navigator.of(context).maybePop());
    } else {
      setState(() => _dragDy = 0);
    }
  }

  /// "Print big" — fetch this photo's bytes (same signed-URL + cache path
  /// as share) and hand them to the poster tool.
  Future<void> _printBig() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final signed = await ref.read(
        signedPersonPhotoUrlProvider(widget.urls[_index]).future,
      );
      if (signed == null || signed.isEmpty || !mounted) return;
      final file = await DefaultCacheManager().getSingleFile(signed);
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      unawaited(context.push('/poster', extra: bytes));
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[photo-print-big] $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't load the photo")),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final signed = await ref.read(
        signedPersonPhotoUrlProvider(widget.urls[_index]).future,
      );
      if (signed == null || signed.isEmpty || !mounted) return;
      final file = await DefaultCacheManager().getSingleFile(signed);
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[photo-share] $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't share the photo")),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Cast the moment to the room — the photos as full-screen slides.
  void _castToRoom() {
    unawaited(
      presentSlides(
        context,
        title: 'Moment',
        slides: [
          for (final url in widget.urls)
            PresentSlide(title: '', imagePath: url),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The background fades out as the photo is dragged away.
    final bgOpacity = (1 - _dragDy.abs() / 400).clamp(0.0, 1.0);
    final captions = widget.captions;
    final caption = (captions != null && _index < captions.length)
        ? captions[_index].trim()
        : '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: bgOpacity),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // The pager — translated by the dismiss drag.
            Transform.translate(
              offset: Offset(0, _dragDy),
              child: PageView.builder(
                controller: _page,
                itemCount: widget.urls.length,
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                  _dragDy = 0;
                }),
                itemBuilder: (_, i) => _ZoomablePhoto(
                  url: widget.urls[i],
                  onTap: _toggleChrome,
                  onZoomChanged: _onZoomChanged,
                  onDragUpdate: _onDragUpdate,
                  onDragEnd: _onDragEnd,
                ),
              ),
            ),

            // Top chrome — close / counter / share / cast. Fades with the frame.
            AnimatedOpacity(
              opacity: _chrome ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: IgnorePointer(
                ignoring: !_chrome,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        color: Colors.white,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      if (widget.urls.length > 1)
                        Text(
                          '${_index + 1} / ${widget.urls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Share',
                        color: Colors.white,
                        icon: _sharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : const Icon(Icons.ios_share),
                        onPressed: _sharing ? null : () => unawaited(_share()),
                      ),
                      IconButton(
                        tooltip: 'Print big',
                        color: Colors.white,
                        icon: const Icon(Icons.print_outlined),
                        onPressed: _sharing
                            ? null
                            : () => unawaited(_printBig()),
                      ),
                      IconButton(
                        tooltip: 'Cast to room',
                        color: Colors.white,
                        icon: const Icon(Icons.cast),
                        onPressed: _castToRoom,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom caption — part of the chrome, fades with it.
            if (caption.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _chrome ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                        child: Text(
                          caption,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single photo wrapped in [InteractiveViewer] so pinch and double-tap zoom
/// work. Reports its zoom state up (so the viewer can gate drag-to-dismiss on
/// NOT-zoomed and hide the chrome while inspecting).
class _ZoomablePhoto extends ConsumerStatefulWidget {
  const _ZoomablePhoto({
    required this.url,
    required this.onTap,
    required this.onZoomChanged,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final String url;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  ConsumerState<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends ConsumerState<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim;
  Animation<Matrix4>? _zoomAnimation;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
    _anim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          if (_zoomAnimation != null) {
            _controller.value = _zoomAnimation!.value;
          }
        });
  }

  void _onTransform() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.1;
    if (zoomed != _isZoomed) {
      // Both setStates (this state + the parent via onZoomChanged) are safe:
      // the controller listener fires during the animation phase, never inside
      // a build().
      setState(() => _isZoomed = zoomed);
      widget.onZoomChanged(zoomed);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTransform)
      ..dispose();
    _anim.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final end = _isZoomed ? Matrix4.identity() : _zoomedInMatrix(details);
    _zoomAnimation = Matrix4Tween(
      begin: _controller.value,
      end: end,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.reset();
    unawaited(_anim.forward());
  }

  /// A 2.5x zoom focused on where the user tapped.
  Matrix4 _zoomedInMatrix(TapDownDetails details) {
    const scale = 2.5;
    final pos = details.localPosition;
    return Matrix4.identity()
      ..translateByDouble(-pos.dx * (scale - 1), -pos.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final asyncUrl = ref.watch(signedPersonPhotoUrlProvider(widget.url));
    return GestureDetector(
      // Opaque so taps + drags in the letterbox bands (BoxFit.contain leaves
      // transparent margins) still register.
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {}, // both needed for the gesture to arm
      // Drag-to-dismiss only when NOT zoomed — when zoomed, leaving these null
      // lets InteractiveViewer own the vertical pan instead.
      onVerticalDragUpdate: _isZoomed
          ? null
          : (d) => widget.onDragUpdate(d.delta.dy),
      onVerticalDragEnd: _isZoomed
          ? null
          : (d) => widget.onDragEnd(d.primaryVelocity ?? 0),
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 6,
        clipBehavior: Clip.none,
        child: Center(
          child: asyncUrl.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
            error: (_, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
            data: (signed) {
              if (signed == null || signed.isEmpty) {
                return const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                );
              }
              return CachedNetworkImage(
                imageUrl: signed,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
