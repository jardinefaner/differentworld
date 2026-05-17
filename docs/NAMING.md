# Universal naming conventions

The core engine of this app is intentionally **domain-agnostic**. The
same code can be templated for an early-childhood program (our v1
use), a personal life tracker, a team workspace, a game / campaign
log, a fleet of assets — anything that involves a container of
actors recording things about subjects over time.

To keep the core generic, we name structural things generically.
Domain-specific words ("classroom", "child", "teacher") live only in
the UI labels and i18n strings.

---

## The five primary nouns

Every use case maps onto these five. If a new feature can't be
expressed in terms of them, the feature is probably wrong-shaped or
we're missing a primary noun.

| Generic | Definition | Classroom (v1) | Personal | Game | Fleet |
|---|---|---|---|---|---|
| **Space** | The top-level container; everything inside is scoped to one | Program | Year / Life | Campaign | Company |
| **Member** | An actor who can read/write inside the Space | Staff | You + partner | Player | Operator |
| **Subject** | A thing being tracked / observed inside the Space | Child | Person, project, area | Character | Vehicle, machine |
| **Group** | A sub-container — Subjects and Members can belong to one or more Groups | Classroom | Life area (Health, Work, Family) | Party, faction | Route, depot |
| **Entry** | A timestamped event recorded by a Member, usually about a Subject, often within a Group | Attendance, observation, meal, nap, pickup | Journal entry, habit check, mood log | Quest, battle, level-up | Trip, refuel, maintenance |

These are NOT five rigid things — they're five **slots**. Most apps
fill all five. Some apps don't have Groups. Some apps have Members
who are also Subjects (a personal tracker). The slots are stable;
their fill varies.

---

## Supporting concepts

| Generic | Definition |
|---|---|
| **Capability** | An opt-in flag on a Space, Member, Subject, or Group that gates behavior |
| **Role** | A coarse default bundle of Capabilities for a Member (e.g., `director`, `teacher`) |
| **Invite** | A pending offer for someone to become a Member of a Space |
| **Template** | A predefined Entry kind, Group setup, or Subject profile, instantiable on demand |
| **Report** | A derived view aggregating Entries — generated, not stored |
| **Event** | Internal: a notification fired when an Entry is created, so other modules can react |

---

## Vocabulary rules

### In code (Dart, schema, providers)
- Use the generic names: `Space`, `Member`, `Subject`, `Group`, `Entry`, `Capability`.
- Singular for class names, plural for tables and collections.
- Foreign keys: `space_id`, `group_id`, `subject_id`, `member_id`.
- Providers: `currentSpaceProvider`, `subjectsProvider(groupId)`, `entriesProvider(subjectId, dateRange)`.
- Routes: `/space/<id>`, `/group/<id>`, `/subject/<id>`, `/entry/<id>` (composable).
- Folder structure: `lib/features/spaces/`, `lib/features/groups/`, `lib/features/entries/`.

### In UI labels (the strings users see)
- Use **domain-specific** terms — "Program," "Classroom," "Child" for the v1 classroom app.
- All domain labels live in the i18n layer (`lib/l10n/`). Swapping the app's domain = swapping the label map; no code changes elsewhere.

### Examples

```dart
// ✅ Generic in code
class Subject { ... }
final subjectsInGroupProvider = ...

// ✅ Domain-specific in UI
Text(AppLocalizations.of(context).children)   // "Children" / "Hijos" / etc.
Text(AppLocalizations.of(context).classroom)  // "Classroom"

// ❌ Domain-specific in code (don't do this)
class Child { ... }
final childrenInClassroomProvider = ...

// ❌ Generic in UI (jarring — users see "Subjects")
Text('Subjects')
```

---

## Mapping our current schema → the universal model

| Current (DW v1) | Universal |
|---|---|
| `programs` table | `spaces` |
| `profiles` table | `members` |
| `students` table | `subjects` |
| `classrooms` table | `groups` |
| `attendance_records` table | `entries` (with `kind = 'attendance'`) |
| `student_guardians` table | `subject_relations` or similar (many-to-many between Subjects) |
| `guardians` table | `subjects` again (Guardians ARE subjects from the engine's view — they're tracked, they have relationships) OR a `related_entities` table |
| Drift class `Profile` | `Member` |
| Drift class `Student` | `Subject` |
| Drift class `Classroom` | `Group` |
| Riverpod `classroomsProvider` | `groupsProvider` |
| Riverpod `currentProfileProvider` | `currentMemberProvider` |
| Feature folder `classrooms/` | `groups/` |
| Feature folder `roster/` | `subjects/` |
| Feature folder `attendance/` | `entries/` (filtered by kind) |

This is the destination. We don't have to refactor everything today
— but every new file follows the universal naming, and the
domain-specific terms get pushed to UI strings.

---

## The Entries table — the unifier

Today we have `attendance_records` as a dedicated table. The
universal model says **every recordable event is an Entry**:

```sql
create table public.entries (
  id           uuid primary key default gen_random_uuid(),
  space_id     uuid not null references public.spaces(id) on delete cascade,
  group_id     uuid references public.groups(id) on delete set null,
  subject_id   uuid references public.subjects(id) on delete cascade,
  member_id    uuid references public.members(id) on delete set null,  -- recorded_by
  kind         text not null,        -- 'attendance' / 'observation' / 'meal' / 'nap' / ...
  occurred_at  timestamptz not null,
  data         jsonb not null default '{}'::jsonb,   -- kind-specific payload
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index entries_subject_idx on public.entries(subject_id, kind, occurred_at desc);
create index entries_group_idx   on public.entries(group_id, kind, occurred_at desc);
create index entries_kind_idx    on public.entries(kind);
```

Pros:
- One table covers attendance, observations, meals, naps, diapers,
  pickups, incidents, medications — every Entry kind.
- New Entry kinds require zero migrations.
- "Everything that happened to subject X today" = one query.
- Cross-kind reporting is one query.

Cons:
- `data` is JSONB → no DB-level type safety. Validation lives in
  the Drift layer + per-kind models in Dart.
- Some queries (attendance counts for the month) are slightly
  awkward without dedicated columns.

This is a real engineering decision; we'll commit when we re-do the
schema. Until then, `attendance_records` is the existing fast path
and we'll add Entries for new kinds.

---

## What changes today, what doesn't

**Adopted immediately (for all new code):**
- New classes named generically (`Subject`, `Group`, `Member`, `Entry`)
- New providers named generically
- New folders use generic names
- New routes use generic paths

**Not changing yet (existing code keeps domain names):**
- The `students`, `classrooms`, `profiles`, `attendance_records`
  tables stay named what they are. Renaming is a 1-day refactor
  that's planned but not urgent.
- The existing Drift classes (`Profile`, `Student`, `Classroom`)
  stay named what they are until we do the rename pass.

**Documented destinations:**
- This file is the destination naming.
- DOMAIN.md will be updated to use the generic names with
  domain-specific labels in parentheses.

---

## Templating for new use cases

When this engine is templated for a new domain:

1. Write a `domain.json` (or l10n .arb) that maps generic names to
   domain labels:
   ```json
   {
     "space": "Campaign",
     "member": "Player",
     "subject": "Character",
     "group": "Party",
     "entry": "Adventure log"
   }
   ```
2. Define which Capabilities are on by default.
3. Define which Entry kinds exist (each Entry kind has a Dart class
   and a UI affordance).
4. Define which Capabilities gate which Entry kinds.

That's the entire customization surface. The Flutter code, the
Supabase schema, the PowerSync sync rules, the auth flow — all
unchanged.

---

## The decision-shortcut

When designing or naming something:

- Is this a structural thing (data model, provider, route)? → Use
  the generic name.
- Is this a user-visible string? → Use the domain-specific label.
- Is the abstraction not one of the five primary nouns? → Pause.
  Is it really an Entry, a Group, a Capability? Or is it a sixth
  primary noun we're missing? Discuss before adopting a new one.
