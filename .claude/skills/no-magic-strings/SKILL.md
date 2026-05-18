---
name: no-magic-strings
description: Reference capability keys, role names, status values via typed constants — never raw string literals. Triggered when typing 'feature_observations' or similar in code.
---

# Typed constants for every cross-cutting key

The analyzer can't catch `'feature_obervations'` (typo) — but it can
catch `SpaceCaps.featureObervations` (compile error). Use the constants.

## Capability keys

`lib/core/capabilities/capability_keys.dart`:

- `SpaceCaps.feature*` — program-level toggles
- `MemberCaps.can*` — per-staff abilities
- `GroupCaps.tracks*` / `GroupCaps.has*` — classroom flags
- `SubjectCaps.*` — per-student medical / care notes
- `AgeBands.infant` / `toddler` / `preschool` / `prek` / `mixed`

```dart
// Right
final canObserve = caps.getBool(MemberCaps.canObserve);

// Wrong
final canObserve = caps.getBool('can_observe');
```

## Role names

These four exact strings:
- `'director'`
- `'lead_teacher'`
- `'teacher'`
- `'assistant'`

Compared in a few hot paths — when they grow we'll promote them to an
enum. Use `RoleBundles.defaultsFor(role)` to seed capabilities.

## Attendance status

`AttendanceStatus` enum already exists (`lib/features/attendance/attendance_status.dart`).
Convert to/from DB via `.dbValue` and `AttendanceStatus.fromDb(...)`.

## Why

Capability keys also appear in docs/CAPABILITIES.md and the JSONB blobs
on every entity row. Typos silently shadow real keys and produce dead
toggles. The constant set is the single source of truth.
