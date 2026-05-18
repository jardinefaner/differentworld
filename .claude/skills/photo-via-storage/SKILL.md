---
name: photo-via-storage
description: Binary media (photos, future video / audio) never goes through PowerSync. The synced row stores a URL string; bytes live in Supabase Storage. Triggered when adding a photo / image / file upload feature.
---

# Photos via Supabase Storage, never via PowerSync

PowerSync's data budget is for text and numbers. A photo or video
shipping through PowerSync rows means we pay PowerSync to ship megabytes
per upload. Every binary asset takes a parallel HTTPS path.

## The rule

> The synced row carries a URL or path string; the bytes live in
> Supabase Storage.

## Upload flow

```dart
// PhotoService.uploadAndPersist already implements this — use it.
final picked = await ImagePicker().pickImage(...);
final compressed = await Isolate.run(() => _compressSync(bytes));
await supabase.storage.from('person-photos').uploadBinary(path, compressed);
final url = supabase.storage.from('person-photos').getPublicUrl(path);
await db.updateFooPhotoUrl(fooId, url);  // typed Drift — PowerSync uploads this string
```

The 1-MB JPEG never touches PowerSync. The ~80-byte URL does.

## Display flow

```dart
import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: foo.photoUrl!,
  fit: BoxFit.cover,
  placeholder: (_, _) => /* skeleton */,
  errorWidget: (_, _, _) => /* fallback */,
)
```

Bytes cache to disk forever after first load.

## Offline upload (deferred)

When the camera fires offline, write `photo_url = 'pending:<local-path>'`
to the row. A small upload-when-online queue swaps the URL once Storage
accepts it. **This isn't built yet**; current behavior is "upload now
or fail" — listed in CLAUDE.md's deferred section.

## Forbidden

- Storing image bytes in a Drift `TextColumn` as base64
- Adding a column `photo_bytes BYTEA` to a synced table
- Anything called `Column.blob` in `power_sync_schema.dart`
- Public-URL-leaks for student photos: see CLAUDE.md "Privacy &
  security" — student photos belong in private buckets with signed URLs
  (currently public-with-obscurity for v0.1; flip before external)

## Videos and audio

**Out of scope for v1.** Don't add columns or buckets for them. When
the time comes, we'll design separately (streaming uploads, transcript
sync stream, etc.).
