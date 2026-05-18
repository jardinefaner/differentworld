---
name: new-provider
description: Scaffold a Riverpod 3 provider — stream / future / family / actions — with the conventions used across this codebase.
---

# /new-provider — Riverpod 3 templates

## Singleton stream (signed-in user's data)

```dart
final fooStreamProvider = StreamProvider<Foo?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return Stream<Foo?>.value(null);
  final dbAsync = ref.watch(appDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) return Stream<Foo?>.value(null);
  return db.watchFooForUser(session.user.id);
});
```

## Family stream (keyed by id)

```dart
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final fooByIdProvider = StreamProvider.autoDispose.family<Foo?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchFoo(id);
  },
);
```

**Always use `.autoDispose.family`** — see the `auto-dispose-family` skill.

## Actions (commands, not state)

```dart
class FooActions {
  FooActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> create({required String name}) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final member = _ref.read(currentMemberProvider).value;
    final spaceId = member?.spaceId;
    if (spaceId == null) {
      throw StateError('No Space selected for the current Member.');
    }
    await db.createFoo(
      id: _uuid.v4(),
      spaceId: spaceId,
      name: name,
    );
  }

  Future<void> update({required String id, String? name}) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.updateFoo(id: id, name: name);
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.deleteFoo(id);
  }
}

// Long-lived singleton — Actions hold a Ref and are reused.
final fooActionsProvider = Provider<FooActions>(FooActions.new);
```

## Where the files go

- `lib/features/<feature>/<feature>_providers.dart` — all providers
  for one feature in one file
- The `*Actions` class lives alongside the StreamProviders
- The Drift mutators live in `lib/core/db/app_database.dart` so they're
  shared across features

## Don't

- Don't use `riverpod_generator` (`@riverpod`) — this codebase dropped
  it because of an analyzer version conflict
- Don't expose state via `StateNotifier` — use Notifier for the few
  cases we need it (see `pendingInviteCodeProvider`)
- Don't do work in `onChanged: (v) => provider.notifier.foo(v)` — wire
  through an Actions class
