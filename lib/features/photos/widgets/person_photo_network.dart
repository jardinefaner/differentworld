import 'package:cached_network_image/cached_network_image.dart';
import 'package:differentworld/features/photos/person_photo_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drop-in replacement for `CachedNetworkImage` when the URL points
/// at the private `person-photos` Supabase bucket. Handles the signed-
/// URL dance internally: feed it whatever value the row stored
/// (path going forward, legacy public URL on older rows, or a
/// `pending:` placeholder) and it'll render the photo if it can or
/// fall through to the placeholder if it can't.
///
/// Keep the same prop shape as `CachedNetworkImage` so swapping
/// call sites is mechanical: rename the constructor + `imageUrl:`
/// → `urlOrPath:` and the rest reads the same.
///
/// For circular avatars, prefer `PersonAvatar` (in
/// `lib/shared/widgets/person_avatar.dart`) — it adds initials-
/// fallback and per-name tinting which are not appropriate for
/// freeform gallery photos.
class PersonPhotoNetwork extends ConsumerWidget {
  const PersonPhotoNetwork({
    required this.urlOrPath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderBuilder,
    this.errorBuilder,
    this.fadeInDuration = const Duration(milliseconds: 200),
    super.key,
  });

  /// The stored value. Can be a bucket-relative path (new shape), a
  /// legacy https URL (older rows pre-bucket-flip), a `pending:`
  /// placeholder, or null. Anything we can't resolve renders the
  /// placeholder.
  final String? urlOrPath;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Override for the in-flight placeholder. If null, uses a tinted
  /// rectangle the size of the image.
  final WidgetBuilder? placeholderBuilder;

  /// Override for the load-failed widget. If null, uses an
  /// "image_not_supported" glyph in a tinted rectangle.
  final WidgetBuilder? errorBuilder;

  final Duration fadeInDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = urlOrPath;
    if (v == null || v.isEmpty || v.startsWith('pending:')) {
      return _placeholder(context);
    }
    final asyncUrl = ref.watch(signedPersonPhotoUrlProvider(v));
    return asyncUrl.when(
      data: (url) {
        if (url == null || url.isEmpty) return _error(context);
        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: width,
          height: height,
          placeholder: (ctx, _) => _placeholder(ctx),
          errorWidget: (ctx, _, _) => _error(ctx),
          fadeInDuration: fadeInDuration,
        );
      },
      loading: () => _placeholder(context),
      error: (_, _) => _error(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final builder = placeholderBuilder;
    if (builder != null) return builder(context);
    return _DefaultPlaceholder(width: width, height: height);
  }

  Widget _error(BuildContext context) {
    final builder = errorBuilder;
    if (builder != null) return builder(context);
    return _DefaultError(width: width, height: height);
  }
}

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.surfaceContainerHighest,
    );
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: scheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}
