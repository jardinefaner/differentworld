---
name: capabilities
description: Quick reference to the capability system — what's where, how to read and write, the role bundles. Triggered when working with the capabilities feature.
---

# Capability system reference

JSONB blob on each entity (`spaces`, `members`, `groups`, `subjects`)
storing opt-in flags. Typed access via constants. Master catalog in
`docs/CAPABILITIES.md`.

## The four entity layers

| Class | Entity | Purpose |
|---|---|---|
| `SpaceCaps` | program-level | `feature_*` toggles, defaults, window times |
| `MemberCaps` | per-staff | `can_*` ability flags, cert lists |
| `GroupCaps` | per-classroom | `tracks_*`, `has_*`, `age_band`, schedules |
| `SubjectCaps` | per-student | medical (allergies, meds), education (IEP), pickup, care notes |

## Reading

```dart
import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';

// .caps is an extension getter on each entity (Space, Member, Group, Subject).
final caps = member.caps;

final flag = caps.getBool(MemberCaps.canObserve);                  // bool
final s    = caps.getString(SubjectCaps.iepNotes);                 // String?
final n    = caps.getInt(SpaceCaps.defaultClassSize);              // int?
final list = caps.getStringList(SubjectCaps.authorizedPickupGuardianIds);
```

## Writing

```dart
// Build the updated draft:
final draft = caps.setting(MemberCaps.canObserve, true);
// Persist via typed Drift mutator:
await db.updateMemberCapabilities(member.id, draft.toJson());
```

`Capabilities` is immutable; `setting()` and `mergedWith()` return new
instances. `setting(key, null)` removes the key.

## Role defaults

`RoleBundles.defaultsFor(role)` seeds a capability map when creating a
new Member or accepting an invite. Roles: `director`, `lead_teacher`,
`teacher`, `assistant`.

## Age-band defaults

`AgeBandDefaults.forBand(band)` seeds GroupCaps based on the age band:

- `infant` — tracks diapers, naps, bottle feeds, detailed meals
- `toddler` — diapers, naps, detailed meals
- `preschool` / `prek` — naps + outdoor time + field trips
- `mixed` — naps + outdoor time

## Pair with

- `no-magic-strings` — always use the typed constants
- `new-capability` — adding a new key
