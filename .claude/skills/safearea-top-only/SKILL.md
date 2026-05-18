---
name: safearea-top-only
description: Scaffolds wrap their body in SafeArea(bottom: false) so content draws under the gesture nav. Triggered when wrapping a body with SafeArea or setting up an edge-to-edge layout.
---

# SafeArea(bottom: false) — top only

In edge-to-edge mode, content should flow visually under the Android
gesture-nav pill / iOS home indicator. The top of the screen still needs
to clear the status bar, but the bottom should not be padded.

`EdgeScaffold` handles this — `lib/shared/widgets/edge_scaffold.dart`
wraps the body in `SafeArea(bottom: false)`. Use that and don't add a
second SafeArea inside.

## Right

```dart
return EdgeScaffold(
  body: ListView(
    padding: const EdgeInsets.only(bottom: 96),  // FAB clearance
    children: [...],
  ),
);
```

## Don't

- Don't wrap the body again with `SafeArea(child: ...)` — double-padded
- Don't use `SafeArea(top: false, bottom: true, ...)` — backwards
- Don't pull in `MediaQuery.paddingOf(context).bottom` to add manual
  spacing — `EdgeScaffold` already lets content extend; ListView padding
  handles the FAB

## Exception

Modal bottom sheets do their own keyboard inset handling via
`MediaQuery.viewInsetsOf(context).bottom`. That's correct; don't refactor.
