import 'package:cached_network_image/cached_network_image.dart';
import 'package:differentworld/features/photos/person_photo_url.dart';
import 'package:differentworld/features/settings/generated_portraits_setting.dart';
import 'package:differentworld/shared/widgets/generated_portrait.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders a circular avatar for a person (member, subject, guardian).
///
/// - If [photoUrl] is non-null and non-empty AND can be resolved to a
///   signed Storage URL, shows the photo via [CachedNetworkImage] with
///   a graceful fallback to the initials path while loading or on
///   error.
/// - Otherwise shows initials derived from [name] on a colour-tinted
///   circle. The tint is deterministic per name so the same person
///   always gets the same colour across the app.
///
/// The widget is a [ConsumerWidget] because the `person-photos`
/// bucket is private — every render mints a short-lived signed URL
/// via [signedPersonPhotoUrlProvider]. Riverpod caches the URL while
/// at least one widget watches it, so a list of N avatars triggers N
/// signed-URL fetches once per session and reuses them everywhere.
///
/// Sized via [radius] (default 18 — matches a `ListTile` leading
/// CircleAvatar).
class PersonAvatar extends ConsumerWidget {
  const PersonAvatar({
    required this.name,
    this.photoUrl,
    this.radius = 18,
    this.onTap,
    super.key,
  });

  /// The person's display name. We pull initials from the first two
  /// whitespace-separated tokens, falling back to the first character
  /// if there's only one token.
  final String name;

  /// Either:
  ///   - A bucket-relative Storage **path** (the new shape): e.g.
  ///     `<space_id>/member/<id>/<uuid>.jpg`. We mint a signed URL.
  ///   - A legacy https **URL** from before the bucket-private flip:
  ///     the path is extracted from it via
  ///     [extractPersonPhotoPath] and a fresh signed URL is minted
  ///     (the old URL itself no longer resolves once the bucket is
  ///     private).
  ///   - A `pending:<local-path>` placeholder for an offline-queued
  ///     upload — falls back to initials until the upload lands
  ///     (Phase 2 reads the local bytes).
  final String? photoUrl;

  final double radius;

  /// Optional tap handler — when non-null, wraps the avatar in an
  /// InkWell and adds a tiny edit-pencil overlay so the affordance
  /// is discoverable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tint = avatarColorFor(name, scheme);
    final fg = ThemeData.estimateBrightnessForColor(tint) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    // Seeded on the NAME, never an id. The same person must present the
    // same face on every screen — a portrait that changes between the roster
    // and the picker is the one bug people notice instantly. Two children
    // with identical full names share a face, which is exactly what they
    // already do with initials.
    final drawn = ref.watch(generatedPortraitsProvider).value ?? false;
    final fallback = drawn
        ? GeneratedPortrait(seed: name, size: radius * 2)
        : Container(
            width: radius * 2,
            height: radius * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Text(
              _initials(name),
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          );

    // Path-or-null gate. We don't even subscribe to the signed-URL
    // provider when there's nothing to resolve — saves Supabase calls
    // for the (very common) initials-only case.
    final hasPhoto =
        photoUrl != null &&
        photoUrl!.isNotEmpty &&
        !photoUrl!.startsWith('pending:');
    final signedAsync = hasPhoto
        ? ref.watch(signedPersonPhotoUrlProvider(photoUrl))
        : const AsyncValue<String?>.data(null);
    final signedUrl = signedAsync.value;

    final avatar = signedUrl != null && signedUrl.isNotEmpty
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: signedUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
              fadeInDuration: const Duration(milliseconds: 200),
            ),
          )
        : fallback;

    if (onTap == null) return avatar;

    // Tappable avatar with a small camera-edit overlay so the user
    // discovers that the picture is changeable.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: avatar,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: scheme.surface,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.photo_camera_outlined,
              size: radius * 0.55,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Returns the 1-2 character initials for a display name.
/// Standalone so attendance / checklist rows can render the same
/// glyph for the leading area without instantiating an avatar.
String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  String first(String s) => s.isEmpty ? '' : s.substring(0, 1).toUpperCase();
  if (parts.length == 1) return first(parts.first);
  return '${first(parts.first)}${first(parts.last)}';
}

/// Stable per-name colour. Same name → same tint everywhere in the
/// app, derived from a small palette tuned for the active
/// [ColorScheme]. The 9-colour palette gives enough variety that a
/// small team / class list looks distinct without becoming
/// disorienting.
Color avatarColorFor(String name, ColorScheme scheme) {
  final n = name.trim().isEmpty ? '?' : name.trim();
  final hash = n.codeUnits.fold<int>(0, (acc, c) => (acc + c) % 9);
  final palette = <Color>[
    scheme.primaryContainer,
    scheme.secondaryContainer,
    scheme.tertiaryContainer,
    Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.25),
      scheme.surface,
    ),
    Color.alphaBlend(
      scheme.tertiary.withValues(alpha: 0.25),
      scheme.surface,
    ),
    Color.alphaBlend(
      scheme.secondary.withValues(alpha: 0.30),
      scheme.surface,
    ),
    Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.18),
      scheme.surfaceContainerHighest,
    ),
    Color.alphaBlend(
      scheme.tertiary.withValues(alpha: 0.18),
      scheme.surfaceContainerHighest,
    ),
    Color.alphaBlend(
      scheme.secondary.withValues(alpha: 0.18),
      scheme.surfaceContainerHighest,
    ),
  ];
  return palette[hash];
}
