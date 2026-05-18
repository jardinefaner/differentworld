---
name: mounted-after-await
description: After any await in a State/ConsumerState method, guard before touching context / setState. Triggered when writing async methods that use context.
---

# `if (!mounted) return;` after every await

Touching `BuildContext` or `setState()` after the widget was disposed
crashes in debug and silently fails in profile.

## Right

```dart
Future<void> _save() async {
  await actions.update(...);
  if (!mounted) return;
  Navigator.of(context).pop();
}
```

## Right (BuildContext captured before await)

When you really need the context after the await, capture the
materialized helpers before you `await`:

```dart
Future<void> _revoke() async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  await ref.read(inviteActionsProvider).revoke(id);
  // No need to check mounted — messenger / navigator survive
  // the widget's disposal because they're root-scaffold owned.
  messenger.showSnackBar(...);
  navigator.pop();
}
```

## Wrong

```dart
Future<void> _save() async {
  await actions.update(...);
  // Boom if the user navigated away during the await.
  Navigator.of(context).pop();
}
```

## With multiple awaits

Check after every one. Each `await` is a potential disposal point.

## Pair with

- `optimistic-writes` — keep the awaits short so the race window is small
- The flutter-lifecycle-guard agent catches missing checks
