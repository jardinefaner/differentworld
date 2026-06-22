import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:differentworld/features/photos/person_photo_url.dart';
import 'package:differentworld/features/photos/photo_upload_queue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the on-disk path for a still-pending (`pending:<id>`) photo so
/// a held-local shot renders from its bytes instead of a placeholder. Null
/// when the queue has no such entry or the file is gone (e.g. it already
/// uploaded + was deleted — the row's value will have flipped to the real
/// path by then anyway). Native-only: web has no filesystem queue, so this
/// is always null there and the placeholder shows.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final pendingPhotoFileProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, id) async {
        if (kIsWeb) return null;
        return ref.watch(photoUploadQueueProvider).localPathFor(id);
      },
    );

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
    if (v == null || v.isEmpty) {
      return _placeholder(context);
    }
    // A `pending:<id>` value means the bytes haven't uploaded yet. For a
    // held-local kid photo-turn shot, the bytes live in the upload queue's
    // local file — render THAT so the review grid + progress folder show
    // the real photo, not a grey box. No network involved. Falls through to
    // the placeholder when there's no local file (web, or already-uploaded
    // mid-flip).
    if (v.startsWith('pending:')) {
      final id = v.substring('pending:'.length);
      final asyncLocal = ref.watch(pendingPhotoFileProvider(id));
      return asyncLocal.when(
        data: (localPath) {
          if (localPath == null) return _placeholder(context);
          return Image.file(
            File(localPath),
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (ctx, _, _) => _placeholder(ctx),
          );
        },
        loading: () => _placeholder(context),
        error: (_, _) => _placeholder(context),
      );
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
