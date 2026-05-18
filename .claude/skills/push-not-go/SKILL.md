---
name: push-not-go
description: Drill-in navigation uses context.push, not context.go. Triggered when modifying navigation calls or adding new ones.
---

# context.push for drill-in, context.go for jumps

`go_router`'s `go()` *replaces* the route stack. That means:
- No slide-in / slide-out transition
- `canPop()` returns false, so back arrows have to fall back to another `go`
- Predictive back gesture and swipe-from-edge don't work right
- The home tree rebuilds every drill-in

Use `context.push` for **drill-in** navigation (parent → child screens
where the user expects a "back").

Use `context.go` only for **jump** semantics — e.g. omnibox suggestions
that explicitly take the user elsewhere, sign-out, fallback routes when
there's nothing to pop.

## Right

```dart
// Drill-in from a list:
onTap: () => context.push('/settings/team/${member.id}'),

// Tap a card:
onTap: () => context.push('/groups/${group.id}'),

// AppBar fallback when canPop is false:
if (context.canPop()) { context.pop(); } else { context.go('/'); }
```

## Wrong

```dart
// Replaces the stack — back won't slide out, no swipe-back gesture.
onTap: () => context.go('/settings/team/${member.id}'),
```

## Pair with

- `cupertino-transitions` — the slide animation that `push` triggers
- `floating-back-only` — the back button that benefits from the stack
