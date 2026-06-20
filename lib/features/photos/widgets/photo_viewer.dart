import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:differentworld/features/photos/person_photo_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fullscreen photo viewer. Swipe horizontally between photos in a
/// list; pinch / double-tap to zoom each one.
///
/// Used by every place that shows photo thumbnails (observation feed,
/// per-child timeline, observation form). Open via [PhotoViewer.open].
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    required this.urls,
    required this.initialIndex,
    super.key,
  });

  final List<String> urls;
  final int initialIndex;

  /// Push a fullscreen viewer on top of the current route. Returns
  /// when the user closes it (any pop). Uses an opaque page route so
  /// the background fades fully to black, not a translucent dialog.
  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
  }) {
    if (urls.isEmpty) return Future.value();
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        fullscreenDialog: true,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => PhotoViewer(
          urls: urls,
          initialIndex: initialIndex.clamp(0, urls.length - 1),
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _page;
  late int _index;

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

  /// Cast the moment to the room — the photos as full-screen slides. No
  /// caption (just the photo), so no free-text narrative travels with it.
  void _castToRoom() {
    unawaited(
      presentSlides(
        context,
        title: 'Moment',
        slides: [
          for (final url in widget.urls) PresentSlide(title: '', imagePath: url),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: widget.urls.length > 1
              ? Text(
                  '${_index + 1} / ${widget.urls.length}',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
          actions: [
            IconButton(
              tooltip: 'Cast to room',
              icon: const Icon(Icons.cast),
              onPressed: _castToRoom,
            ),
          ],
        ),
        body: PageView.builder(
          controller: _page,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => _ZoomablePhoto(url: widget.urls[i]),
        ),
      ),
    );
  }
}

/// A single photo wrapped in [InteractiveViewer] so pinch and double-
/// tap zoom work. Double-tap toggles between fit-to-screen and 2.5×.
///
/// The constructor takes the stored value (Storage path going forward;
/// legacy public URL on older rows) — this widget resolves it to a
/// signed URL via [signedPersonPhotoUrlProvider]. The signed URL is
/// cached for an hour, so the same photo doesn't get re-signed on
/// swipe-back-and-forth.
class _ZoomablePhoto extends ConsumerStatefulWidget {
  const _ZoomablePhoto({required this.url});

  final String url;

  @override
  ConsumerState<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends ConsumerState<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _controller.value = _zoomAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final isZoomedIn = _controller.value.getMaxScaleOnAxis() > 1.1;
    final end = isZoomedIn ? Matrix4.identity() : _zoomedInMatrix(details);
    _zoomAnimation = Matrix4Tween(
      begin: _controller.value,
      end: end,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.reset();
    unawaited(_anim.forward());
  }

  /// Build a 2.5x zoom focused on where the user tapped. Pure math
  /// translation so the tap point stays put visually.
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
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {}, // need both for the gesture detector to arm
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
