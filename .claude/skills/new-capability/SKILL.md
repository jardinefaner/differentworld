---
name: new-capability
description: Add a new capability key (Space / Member / Group / Subject) to the typed catalog and the docs. Triggered when adding a new feature toggle or per-entity flag.
---

# /new-capability — add a typed capability key

Capabilities are JSONB blobs on `spaces.capabilities`, `members.capabilities`,
`groups.capabilities`, `subjects.capabilities`. Typed access via constant
classes in `lib/core/capabilities/capability_keys.dart`. Master catalog
in `docs/CAPABILITIES.md`.

## Steps

1. **Pick the right entity layer.** Asking yourself:
   - Per-program toggle (e.g. "We log incidents") → `SpaceCaps`
   - Per-staff ability (e.g. "Can administer medication") → `MemberCaps`
   - Per-classroom tracking flag (e.g. "Has outdoor time") → `GroupCaps`
   - Per-student detail (e.g. "Photo consent") → `SubjectCaps`

2. **Add the constant.** `lib/core/capabilities/capability_keys.dart`:

   ```dart
   abstract class SpaceCaps {
     // ... existing
     static const featureNewThing = 'feature_new_thing';
   }
   ```

   Naming:
   - SpaceCaps: `feature_*` for toggles, otherwise descriptive
   - MemberCaps: `can_*` for boolean abilities
   - GroupCaps: `tracks_*`, `has_*`, or descriptive (e.g. `age_band`)
   - SubjectCaps: descriptive

3. **Update `docs/CAPABILITIES.md`** with the new key, type, layer,
   default value, and a sentence explaining its purpose.

4. **If it's a MemberCap with a role default**, update the appropriate
   role bundle in `RoleBundles.defaultsFor(role)` in `capability_keys.dart`.

5. **If it's a GroupCap that varies by age band**, update
   `AgeBandDefaults.forBand(band)`.

## Reading the cap

```dart
import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';

final caps = member.caps;  // extension getter
final canDoThing = caps.getBool(MemberCaps.canNewThing);
```

## Writing the cap

```dart
final draft = caps.setting(MemberCaps.canNewThing, true);
await db.updateMemberCapabilities(member.id, draft.toJson());
```

## Don't

- Don't use a raw string literal — that's what `no-magic-strings` is for
- Don't read a capability and store its value in a Drift column instead
  — JSONB is the contract; columns become rigid
- Don't add a cap to multiple entity layers — pick one
