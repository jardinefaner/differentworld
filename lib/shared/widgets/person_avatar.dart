import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a circular avatar for a person (member, subject, guardian).
///
/// - If [photoUrl] is non-null and non-empty, shows the photo via
///   [Image.network] with a graceful fallback to the initials path on
///   load failure.
/// - Otherwise shows initials derived from [name] on a colour-tinted
///   circle. The tint is deterministic per name so the same person
///   always gets the same colour across the app.
///
/// Sized via [radius] (default 18 — matches a `ListTile` leading
/// CircleAvatar).
class PersonAvatar extends StatelessWidget {
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

  /// Either an https URL (Supabase Storage signed/public link) or a
  /// `pending:<local-path>` placeholder for an offline-queued upload.
  /// We currently render an https URL; pending photos show initials
  /// until the upload lands (Phase 2 will read the local bytes).
  final String? photoUrl;

  final double radius;

  /// Optional tap handler — when non-null, wraps the avatar in an
  /// InkWell and adds a tiny edit-pencil overlay so the affordance
  /// is discoverable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null &&
        photoUrl!.isNotEmpty &&
        !photoUrl!.startsWith('pending:');

    final scheme = Theme.of(context).colorScheme;
    final tint = avatarColorFor(name, scheme);
    final fg = ThemeData.estimateBrightnessForColor(tint) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    final fallback = Container(
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

    final avatar = hasPhoto
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: photoUrl!,
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
