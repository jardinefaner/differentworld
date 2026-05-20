---
name: photo-via-storage
description: Binary media (photos) never goes through PowerSync. The synced row stores a PATH; bytes live in the PRIVATE Supabase Storage bucket. Render via signedPersonPhotoUrlProvider — the URL is minted at view time. Triggered when adding a photo upload or display feature.
---

# Photos via Supabase Storage, private bucket + signed URLs

PowerSync's data budget is for text and numbers. A photo or video
shipping through PowerSync rows means we pay PowerSync to ship megabytes
per upload. Every binary asset takes a parallel HTTPS path.

## The rule

> The synced row carries a STORAGE PATH; the bytes live in the private
> `person-photos` Supabase Storage bucket; views mint short-lived
> signed URLs at render time.

## Upload flow

```dart
// PhotoService.uploadAndPersist already implements this — use it.
final picked = await ImagePicker().pickImage(...);
// Returns the bucket-relative path (e.g. `<space>/member/<id>/<uuid>.jpg`)
// — NOT a full URL.
final path = await ref.read(photoServiceProvider).uploadAndPersist(
      entity: PhotoEntity.subject,
      entityId: subjectId,
      picked: picked!,
    );
// The path is already written to the row via the Drift mutation
// inside uploadAndPersist; PowerSync uploads only that short string.
```

The 1-MB JPEG never touches PowerSync. The ~50-byte path does.

## Display flow

### Avatars (circular)

```dart
import 'package:differentworld/shared/widgets/person_avatar.dart';

PersonAvatar(
  name: subject.fullName,
  photoUrl: subject.photoUrl,  // accepts a path or a legacy URL
  radius: 22,
)
```

`PersonAvatar` is a `ConsumerWidget` — it watches
`signedPersonPhotoUrlProvider(value)` and renders via
`CachedNetworkImage` once the signed URL is minted. Falls back to
initials on load failure or while the URL is in flight.

### Gallery / freeform photos

```dart
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';

PersonPhotoNetwork(
  urlOrPath: entry.photoUrl,
  fit: BoxFit.cover,
  placeholderBuilder: (_) => /* skeleton */,
  errorBuilder: (_) => /* fallback */,
)
```

Same provider underneath. Used by observation photos, viewer, etc.

### Don't use raw CachedNetworkImage for person-photos

The bucket is PRIVATE — passing a stored path directly to
`CachedNetworkImage(imageUrl: ...)` will 401. Always go through
PersonAvatar or PersonPhotoNetwork.

## Legacy rows

Pre-flip rows still hold full https URLs like
`https://<project>.supabase.co/storage/v1/object/public/person-photos/...`.
`extractPersonPhotoPath` (in `lib/features/photos/person_photo_url.dart`)
strips the prefix and re-signs the path. Both widgets handle this
transparently.

## Signed URL TTL

1 hour. Riverpod caches the URL in memory while at least one widget
is watching it; we `ref.keepAlive()` for `TTL - 60s` so the URL
stays cached for almost the full server-side lifetime.

## Offline upload (deferred)

When the camera fires offline, write `photo_url = 'pending:<local-path>'`
to the row. A small upload-when-online queue swaps the URL once Storage
accepts it. **This isn't built yet**; current behavior is "upload now
or fail" — listed in CLAUDE.md's deferred section.

## Forbidden

- Storing image bytes in a Drift `TextColumn` as base64
- Adding a column `photo_bytes BYTEA` to a synced table
- Anything called `Column.blob` in `power_sync_schema.dart`
- Calling `getPublicUrl(...)` for person-photos (bucket is private —
  you'll get a URL that 401s on read)
- Using raw `CachedNetworkImage` for person-photos paths

## Videos and audio

**Out of scope for v1.** Don't add columns or buckets for them. When
the time comes, we'll design separately (streaming uploads, transcript
sync stream, etc.).
