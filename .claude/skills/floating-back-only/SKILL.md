---
name: floating-back-only
description: Don't hand-roll back buttons. EdgeScaffold draws FloatingBack automatically when canPop is true; pass backFallbackRoute if a deep-link entry is possible. Triggered when adding navigation chrome.
---

# Back via FloatingBack — never hand-rolled

`lib/shared/widgets/floating_back.dart`. Tiny glass-pill in the top-left
that auto-hides when there's nothing to pop. `EdgeScaffold` instantiates
it for you.

## Default — drill-in via push, back via FloatingBack

```dart
return EdgeScaffold(
  // showBack: true by default. FloatingBack appears automatically.
  body: ...,
);
```

## Home page — no back

```dart
return EdgeScaffold(
  showBack: false,  // Today, the JoinOrCreate landing, etc.
  body: ...,
);
```

## Deep-linkable detail screens

If the user can land here via a deep link (skipping the parent), pass
where to go when there's no stack:

```dart
return EdgeScaffold(
  backFallbackRoute: '/settings/team',
  body: ...,
);
```

## Don't

- Don't add `AppBar(leading: IconButton(Icons.arrow_back, ...))` — see
  `no-app-bar`
- Don't wrap your screen in your own `Stack` to position a back button
  — `EdgeScaffold` already does it
- Don't check `context.canPop()` yourself in build to decide whether
  to show a back — `FloatingBack` does it internally
