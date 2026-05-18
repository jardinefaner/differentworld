---
name: new-route
description: Add a new route to lib/app/router.dart with the correct nesting + push semantics.
---

# /new-route — register a go_router route

## Where it goes

`lib/app/router.dart`. Routes are nested under `GoRoute(path: '/')` for
the main signed-in tree, or as top-level entries (`/login`).

## Pattern for a screen under `/`

```dart
GoRoute(
  path: '/',
  builder: (_, _) => const _Home(),
  routes: [
    // ... existing routes
    GoRoute(
      path: 'foo/:id',
      builder: (_, state) => FooScreen(
        id: state.pathParameters['id']!,
      ),
      routes: [
        // Nested children if there's a third level.
      ],
    ),
  ],
),
```

## Pattern for a settings sub-route

```dart
GoRoute(
  path: '/settings',
  builder: (_, _) => const SettingsScreen(),
  routes: [
    GoRoute(
      path: 'foo',
      builder: (_, _) => const FooSettingsScreen(),
    ),
  ],
),
```

## When invoking the route

Use `context.push('/foo/${id}')` — never `go` for drill-in. See the
`push-not-go` skill.

If a deep link could land directly on this route (skipping the parent),
pass `backFallbackRoute: '/foo'` to the screen's `EdgeScaffold` so
the floating-back pill knows where to go when there's no stack.

## Don't

- Don't add `redirect:` on individual routes — the auth-aware redirect
  lives at the router root (line ~28). Adding more makes the redirect
  graph hard to reason about.
- Don't pass complex objects in route extras — pass IDs and let the
  destination screen watch its own provider.
- Don't forget the omnibox: if this is a top-level destination, add a
  suggestion in `lib/features/omnibox/omnibox_screen.dart` so users
  can jump to it via search.
