---
name: fab-clearance
description: Lists on screens with a FAB use 96 dp bottom padding so the last row isn't obscured. Triggered when adding a list under a FAB.
---

# 96 dp bottom padding on lists with a FAB

The `FloatingActionButton.extended` lands ~80 dp tall + 16 dp from the
edge in `EdgeScaffold`. List items at the bottom otherwise live under
the FAB and become un-scrollable-to.

## Right

```dart
ListView.builder(
  padding: const EdgeInsets.only(bottom: 96),
  itemCount: items.length,
  itemBuilder: (_, i) => YourRow(items[i]),
)
```

## Right with horizontal padding too

```dart
ListView(
  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
  children: [...],
)
```

## Right when ListView is wrapped in Expanded inside a Column

If the FAB lives at the Scaffold level, the inner ListView still needs
the bottom padding — the Expanded clips the bottom but the FAB renders
over it.

```dart
Column(
  children: [
    SomeHeader(),
    Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 96),
        ...
      ),
    ),
    SomeFooter(),  // ← if you have a footer, leave the padding;
                   //   user will see both footer and FAB clear at the bottom
  ],
)
```

## Skip when no FAB

If there's no FAB on the screen, drop the bottom padding to 16 dp or
similar. `EdgeScaffold` lets content extend under the gesture nav, so
the last row visually flows under the system pill.

## Common mistake

```dart
ListView.builder(
  padding: const EdgeInsets.symmetric(vertical: 8),  // ✗ FAB obscures last row
  ...
)
```

Use `EdgeInsets.only(top: 8, bottom: 96)` instead.
