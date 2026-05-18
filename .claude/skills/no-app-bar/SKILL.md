---
name: no-app-bar
description: Never use Material AppBar in the app's screens. Triggered when an AppBar widget is added or proposed.
---

# No AppBar

The app removed all persistent top chrome in the no-nav-bars redesign.
Titles live in scrollable content via `ContentHeader`; back / actions
live in floating glass pills via `EdgeScaffold`.

## Forbidden in screens (`lib/features/**/*_screen.dart`)

- `Scaffold(appBar: AppBar(...))`
- `SliverAppBar`
- `CupertinoNavigationBar`
- Custom widgets that mimic a horizontal title bar across the top edge

## OK to use

- **Modal bottom sheets** (`showModalBottomSheet`) don't have AppBars and
  never did — they're fine.
- **Dialogs** (`AlertDialog`) are fine.
- **Photo source sheet / invite share sheet / form sheets** — these
  internal sheets are not screens; they keep their existing structure.

## When adding a new screen

Use the `new-screen` skill or:

```dart
return EdgeScaffold(
  actions: const [SyncStatusIndicator()],
  body: ListView(
    padding: const EdgeInsets.only(bottom: 96),
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ContentHeader(title: 'Screen name', subtitle: 'optional'),
      ),
      // ...
    ],
  ),
);
```
