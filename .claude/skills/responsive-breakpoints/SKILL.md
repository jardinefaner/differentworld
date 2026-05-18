---
name: responsive-breakpoints
description: Layout pattern across phone / phone-landscape / iPad / desktop. Use FormFactor + LayoutBuilder, never MediaQuery.size.
---

# Responsive layout — 4 form factors, 1 pattern

| Form factor | Width | Pattern |
|---|---|---|
| Phone portrait | < 600 dp | Single column |
| Phone landscape / small tablet | 600–840 dp | Single column, side nav rail |
| iPad / desktop window | 840–1200 dp | Two-column master-detail |
| Desktop / wide | > 1200 dp | Three-column, persistent side panel |

## Use `FormFactor.fromWidth(...)`

`lib/shared/breakpoints.dart` exposes the constants. Never inline magic
numbers.

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    final formFactor = FormFactor.fromWidth(constraints.maxWidth);
    final horiz = formFactor.isExpanded ? 48.0 : 16.0;

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: horiz),
      children: [...],
    );
  },
);
```

## Don't

- Don't use `MediaQuery.of(context).size` in `build()` — rebuilds on
  every metric change (keyboard, rotation)
- Don't gate layout on `Platform.isAndroid` — gate on width
- Don't sprinkle magic numbers like `if (constraints.maxWidth > 600)`
  — use `FormFactor`

## Conventions

- **Touch targets ≥ 48 dp** on every form factor — even desktop
- **Forms wrapped in `ConstrainedBox(maxWidth: 480)`** centered so text
  doesn't stretch uncomfortably wide on desktop
- **Mouse + touch + keyboard** all work on every interactive element

## Where breakpoints land in the app

- Today: switches horizontal padding 16 → 48 at expanded width
- Form sheets: `ConstrainedBox(maxWidth: 480 or 520)`
- Settings: single-column always (lists scale fine)
