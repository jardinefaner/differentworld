---
name: edge-of-edge-status
description: System UI overlay style adapts per theme via AnnotatedRegion in EdgeScaffold. Don't set it globally. Triggered when proposing SystemUiOverlayStyle changes.
---

# Status bar contrast: AnnotatedRegion, per screen

`EdgeScaffold` wraps every screen in an `AnnotatedRegion<SystemUiOverlayStyle>`
that picks light icons on dark themes, dark icons on light themes. The
boot-time global in `main.dart` sets the transparent colors; the per-screen
region sets the icon brightness so contrast matches the theme.

## How it works

```dart
// Inside EdgeScaffold.build:
final isDark = Theme.of(context).brightness == Brightness.dark;
final overlay = isDark
    ? SystemUiOverlayStyle.light.copyWith(/* transparent backgrounds */)
    : SystemUiOverlayStyle.dark.copyWith(/* transparent backgrounds */);

return AnnotatedRegion<SystemUiOverlayStyle>(
  value: overlay,
  child: Scaffold(/* edge-to-edge */),
);
```

## Don't

- Don't call `SystemChrome.setSystemUIOverlayStyle(...)` outside
  `main.dart` — that's a global override and contradicts the per-screen
  region
- Don't try to detect light/dark from the background widget — the
  Material theme is the source of truth
- Don't add a separate `AnnotatedRegion` inside a screen — `EdgeScaffold`
  already does it

## When to override

Almost never. If a specific screen has a contrasting background image
(e.g. a hero photo that fills the top), wrap that one screen with its
own `AnnotatedRegion`:

```dart
return AnnotatedRegion<SystemUiOverlayStyle>(
  value: SystemUiOverlayStyle.light,  // photo background is dark
  child: EdgeScaffold(...),
);
```

## Test it

Look at the system clock + battery icons on:
- Today (light theme)
- Today (dark theme, if device is dark)
- Group detail (different background hue)

If you can't see the time, your status bar icons aren't matching the
content underneath.
