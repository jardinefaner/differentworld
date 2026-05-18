---
name: auto-dispose-family
description: StreamProvider.family / FutureProvider.family providers always use .autoDispose to avoid keeping a watch alive per key forever. Triggered when adding a family provider.
---

# `StreamProvider.autoDispose.family<...>(...)`

Family providers spawn a new instance per key. Without `.autoDispose`,
every key the user visits stays alive in Riverpod's container — which
means every member detail screen you visited keeps its Drift watch
streaming forever.

## Right

```dart
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _memberProvider =
    StreamProvider.autoDispose.family<Member?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchMember(id);
  },
);
```

## Wrong

```dart
// No autoDispose — every visited member id leaks its stream.
final _memberProvider = StreamProvider.family<Member?, String>(...);
```

## When you'd skip autoDispose

The very few long-lived top-level providers without family keys:

- `appDatabaseProvider` (singleton DB)
- `routerProvider` (singleton router)
- `*ActionsProvider` (singletons that hold a Ref but no resources)
- `currentMemberProvider` (singleton stream for the signed-in user)

For anything keyed by a screen-bound ID — group, subject, member,
attendance day — always autoDispose.

## The lint comment

Riverpod 3's typed-property linter doesn't know how to express the
family provider's inferred type. Pair the provider line with:

```dart
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
```
