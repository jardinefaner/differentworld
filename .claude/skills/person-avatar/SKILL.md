---
name: person-avatar
description: Every place a person (member, subject, guardian) shows up renders via PersonAvatar, never a raw CircleAvatar with initials. Triggered when rendering a person's identity.
---

# Use PersonAvatar everywhere a person shows up

`lib/shared/widgets/person_avatar.dart` is the only place that knows how
to draw a person. It handles:

- The actual photo if `photoUrl` is set (via `cached_network_image`)
- Deterministic per-name color fallback when no photo
- Initials derived from the name
- The "tap to change photo" affordance when given an `onTap`

## Use

```dart
import 'package:differentworld/shared/widgets/person_avatar.dart';

PersonAvatar(
  name: member.displayName,
  photoUrl: member.avatarUrl,
  radius: 18,  // default for ListTile leading; 40 for detail header
)
```

## With photo-change affordance

```dart
PersonAvatar(
  name: member.displayName,
  photoUrl: member.avatarUrl,
  radius: 40,
  onTap: () => PhotoSourceSheet.show(
    context,
    entity: PhotoEntity.member,
    entityId: member.id,
    hasExisting: member.avatarUrl != null,
    displayName: member.displayName,
  ),
)
```

## Don't

- Don't render `CircleAvatar(child: Text(initial))` — `PersonAvatar`
  is the abstraction.
- Don't hand-roll initials extraction. The widget handles 1-2 token
  names, empty strings, single characters.
- Don't pass a tinted background — the per-name tint is derived
  inside `avatarColorFor()`.
