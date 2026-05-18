---
name: no-color-only
description: Never signal state with color alone. Always pair with icon, label, or position. Triggered when designing status indicators / chips / badges.
---

# No color-only signals

Colorblind users can't distinguish green-vs-red. Status chips, sync
indicators, validation states need a non-color cue too.

## Right — icon + label + tinted color

```dart
// Attendance status chip in _StatusChip:
Chip(
  avatar: Icon(status.icon, size: 16, color: color),
  label: Text(status.label, style: TextStyle(color: color)),
  backgroundColor: color.withValues(alpha: 0.10),
  side: BorderSide(color: color.withValues(alpha: 0.35)),
)
```

- Icon — `check_circle`, `cancel`, `schedule`, etc.
- Label — "Present", "Absent", "Late"
- Color — semantic but redundant

Any one of these alone communicates the state.

## Wrong

```dart
// Red dot. Means what?
Container(
  width: 8, height: 8,
  decoration: const BoxDecoration(
    color: Colors.red,
    shape: BoxShape.circle,
  ),
)
```

## Sync status

The `SyncStatusIndicator` uses a distinct icon per state (cloud /
cloud-off / sync-spinning / cloud-error). Color is decorative.

## Validation states

Form errors get inline text below the field, not just a red border:

```dart
TextFormField(
  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
)
```

## When to add an icon

Look at every place you reach for `Container(color: ...)` to indicate
state. If a colorblind user wouldn't know the meaning, add a glyph or
a label.

## The 9-color name-derived avatar palette

`avatarColorFor()` in `person_avatar.dart` mixes 9 derived tints. It's
NOT a state signal — it's identity. The user's NAME is also visible
in initials or the tile's title row, so the color is supplementary.
This is fine.
