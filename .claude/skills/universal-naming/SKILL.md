---
name: universal-naming
description: Engine uses Space / Member / Group / Subject. UI uses domain-specific labels (Program / Staff / Child / Classroom). Triggered when naming a class, field, or screen.
---

# Universal naming: engine vs UI

The app is designed to be templated for non-classroom use cases later.
The data model uses generic engine terms; the UI strings use domain
labels. CLAUDE.md has the full contract.

## The mapping

| Engine (DB, Dart, code) | UI (strings, route hints, button labels) |
|---|---|
| `Space` | "Program" |
| `Member` | "Staff member" |
| `Group` | "Classroom" |
| `Subject` | "Student" / "Child" |
| `Entry` (future) | "Observation", "Meal", etc. |
| `space_id` | n/a (column name) |
| `group_id` | n/a (column name) |
| `subject_id` | n/a (column name) |
| `member_id` | n/a (column name) |

## Right

```dart
// Code:
class SubjectActions {
  Future<void> create({required String groupId, ...}) async {...}
}

// UI string:
const Text('Add student')

// Route:
GoRoute(path: '/groups/:id', ...)  // group not classroom

// Drift class:
class Subjects extends Table {...}
```

## Wrong

```dart
// Don't mix engine + domain in the same name:
class StudentRecord { final String spaceId; ... }  // ✗ Student + Space mixed
class ClassroomService { ... }                      // ✗ Classroom is UI, not engine

// Don't put UI labels in column names:
TextColumn get childName => text()();  // ✗
TextColumn get firstName => text()();  // ✓
```

## Why

- We can ship the same engine for a personal task tracker (Spaces =
  "Projects", Subjects = "Tasks"), a game (Spaces = "Saves",
  Subjects = "Characters"), etc.
- Renaming the database after the fact is expensive (we did it once
  in migration `20260518000001_universal_rename.sql` — don't do it
  again)

## Where the contract lives

`docs/NAMING.md`. Read it before naming anything new.
