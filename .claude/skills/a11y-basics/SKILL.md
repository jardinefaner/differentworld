---
name: a11y-basics
description: Built-in accessibility — semantic labels, touch targets, color contrast, focus order, dynamic type. Triggered when reviewing or building new screens.
---

# Accessibility basics

Built in from day one. Children's app, often used by tired adults, in
varied light conditions, sometimes with screen readers.

## Touch targets

Every tappable thing is ≥ 48×48 dp. `IconButton` defaults to that;
custom `GestureDetector` regions need explicit minimum sizes.

## Semantics

Every interactive element has a label.

```dart
IconButton(
  tooltip: 'Take attendance',       // ← acts as semantic label too
  icon: const Icon(Icons.fact_check_outlined),
  onPressed: ...,
)

// For custom tappable widgets:
Semantics(
  label: 'Mark Toby as present',
  button: true,
  child: GestureDetector(onTap: ..., child: ...),
)
```

`tooltip:` on `IconButton` is the standard way — it covers a11y + the
hover tooltip on desktop.

## Color contrast

≥ 4.5:1 on text. The Material 3 color schemes derived from
`Color(0xFF1F6FEB)` satisfy this. Don't hand-pick colors that bypass
the scheme.

## Dynamic type

Respect `MediaQuery.textScaleFactor`. Text must scale up to 200%
without truncation.

```dart
// Right
Text(longText, maxLines: 2, overflow: TextOverflow.ellipsis)

// Avoid
SizedBox(height: 20, child: Text(longText))   // pins height regardless of scale
```

## Focus order

Logical: top-to-bottom, left-to-right. Forms should have correct
`TextInputAction.next` / `done` so the keyboard's "next" jumps to
the right field.

## Color-only signals

Never. The attendance status chips use icon + color + label. Same for
unmarked pills on Today.

## Screen-reader sanity check

Every primary flow should be navigable with VoiceOver / TalkBack with
no dead ends. The single widget test covers login boot; manual SR
testing happens before release.
