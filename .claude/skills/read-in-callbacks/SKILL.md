---
name: read-in-callbacks
description: Use ref.read inside onTap / onPressed / onChanged; never ref.watch. Triggered when wiring widget callbacks.
---

# `ref.read` in callbacks, `ref.watch` in build

`ref.watch` subscribes the *enclosing build method* to changes — which
means calling it inside a callback subscribes the callback's enclosing
widget. That's almost never what you want and produces noisy rebuilds.

## Right

```dart
FilledButton(
  onPressed: () async {
    final actions = ref.read(groupActionsProvider);
    await actions.create(name: name);
  },
  child: const Text('Create'),
)
```

## Wrong

```dart
FilledButton(
  onPressed: () async {
    // Subscribes the widget to groupActionsProvider for no reason.
    final actions = ref.watch(groupActionsProvider);
    await actions.create(name: name);
  },
  child: const Text('Create'),
)
```

## Riverpod's own analyzer

Riverpod has an inline lint that flags `ref.watch` inside callbacks. If
you see `avoid_manual_providers_as_generated_provider_dependency` or
similar, this is what it's telling you.

## Pair with

- `select-not-watch` — for the values you DO want to watch in build
