---
name: prefer-const
description: Use const constructors everywhere they compile. Triggered when writing widget trees.
---

# const everywhere it works

Const widgets skip rebuilds. The analyzer flags missing `const` with
the `prefer_const_constructors` lint — never suppress, always add.

## Common spots that should be const

- `const SizedBox(height: 16)`
- `const Divider(height: 1)`
- `const Text('Static label')`
- `const Icon(Icons.search)`
- `const EdgeInsets.symmetric(horizontal: 16)`
- `const _SectionLabel(label: 'Members')` (private widgets too)

## What blocks const

- Expressions that aren't const (theme lookups, ref.watch, non-const constructors)
- `EdgeInsets.fromLTRB(16, _padding, 16, 16)` if `_padding` is non-const
- Widgets whose constructor isn't marked `const`

## Hidden const opportunities

When defining a new internal widget, mark its constructor `const` if at
all possible. Most stateless widgets can.

```dart
class _Greeting extends StatelessWidget {
  const _Greeting({required this.text});  // const ← do this
  final String text;
  ...
}
```

`very_good_analysis` (already enabled) catches missed `const` keywords.
Fix on the spot.
