---
name: select-not-watch
description: Use ref.watch(provider.select((s) => s.foo)) to subscribe to slices, not whole objects. Triggered when reading a provider in build().
---

# `select` for slices, not the whole object

`ref.watch(currentMemberProvider)` rebuilds the widget every time
ANY field on the member changes — including the per-sync `updated_at`
churn. For a widget that only cares about the display name, that's
nearly every emission wasted.

## Right

```dart
final memberName = ref.watch(
  currentMemberProvider.select((m) => m.value?.displayName),
);
```

Rebuilds only when the display name actually changes.

## Wrong

```dart
final member = ref.watch(currentMemberProvider).value;
final memberName = member?.displayName;
```

Rebuilds on every member emission, even when the name is unchanged.

## When to skip select

- Building widgets that genuinely use most fields of the object
- Tiny screens with very few rebuilds anyway
- Settings index, member detail, where the rebuild is cheap

The win is biggest on screens with high-frequency rebuilds — Today's
classroom cards, attendance rows, anywhere inside a hot list.

## Pair with

- `read-in-callbacks` — callbacks should `ref.read`, not `ref.watch`
