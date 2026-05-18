---
name: no-jank-on-build
description: Move CPU work out of build() and out of the main isolate when it's > 1 ms. Use Isolate.run for heavier work. Triggered when image processing, JSON parsing, or sorting large lists appears in build().
---

# No CPU work in build()

The build method runs at 60+ fps target. 16 ms budget (or 8 ms on
120 Hz devices). Anything that nibbles at it produces visible jank.

## Move out of build()

- JSON decoding of large blobs → into provider memoization
- Sorting / filtering long lists → into provider derivation
- Image decoding / resizing → `Isolate.run`
- Crypto / hashing → `Isolate.run`
- Heavy date math → memoize outside build

## Right — derived state in a provider

```dart
final filteredSubjectsProvider = Provider.family<List<Subject>, String>(
  (ref, groupId) {
    final all = ref.watch(subjectsInGroupProvider(groupId)).value ?? [];
    return all.where((s) => /* ... */).toList();
  },
);
```

## Right — Isolate.run for image work

The PhotoService runs `_compressSync` inside `Isolate.run`. ~1 second of
CPU stays off the main isolate:

```dart
final compressed = await Isolate.run(() => _compressSync(bytes));
```

The function must be top-level or static so it can serialize across the
isolate boundary.

## Right — DateFormat memoized

`DateFormat.yMMMMEEEEd().format(when)` is cheap because `DateFormat`
caches internally. Don't recreate it per build — declare const-like:

```dart
class _ScreenState extends State<...> {
  static final _df = DateFormat.yMMMMEEEEd();
  // ... _df.format(when) in build
}
```

## Don't

- Don't optimize prematurely — the Performance Guard catches actual
  hot paths
- Don't move trivial work into providers for the sake of it — single
  ListTile builds with a few `Text(...)` widgets are fine
- Don't pre-allocate everything in initState — that bottlenecks startup
  instead of build time

## Pair with

- The flutter-performance-guard agent for systematic auditing
- `prefer-const` — const widgets skip rebuilds entirely
- `select-not-watch` — fewer rebuilds, less work
