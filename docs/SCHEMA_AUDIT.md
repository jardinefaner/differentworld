# Schema audit — childcare assumptions baked into Postgres

What's still childcare-specific at the schema layer, and what the
multi-vertical migration design needs to address before a
non-childcare deployment goes live. Companion to
`docs/APP_GUIDE.md` Part 2 (the product-level generalization
argument) and `docs/ROADMAP.md` (the prioritized punch list).

The Wave 1-7 code-side work (council-audit batches in this
session) gives us `VerticalLabels`, `CoreCaps` / `ChildcareCaps`,
and the omnibox header / yearly-review / settings labels routed
through the active vertical. But the SCHEMA layer is still
childcare-shaped. The choices below are the ones the multi-vertical
migration design will have to make.

---

## What's still childcare-shaped in Postgres

### `public.member_role` enum

```sql
create type public.staff_role as enum (
  'director', 'lead_teacher', 'teacher', 'assistant'
);
-- renamed to member_role in 20260518000001_universal_rename.sql
-- + extended with 'guardian' in 20260519000004_member_role_guardian.sql
```

**Problem**: Postgres enum values are hardwired. Construction
needs `foreman / pm / journeyman / apprentice / subcontractor`;
healthcare needs `physician / np / rn / tech / ma / admin`;
hospitality needs `gm / manager / server / cook / host`. The
current enum can't grow side-by-side.

**Migration options**:

1. **Drop the enum to plain `text`.** Roles become free-form
   strings; per-Space `capabilities['roles']` holds the canonical
   list for that vertical. Cheapest migration, most flexible. Loss:
   no type-safety at the SQL layer.
2. **Add new enum values for every vertical's role names.**
   Conservative but pollutes the global enum — a construction
   user's role gets a value like `foreman` that's meaningless to
   a childcare query. Forever-growing.
3. **Per-vertical enum types** (e.g. `construction_role` enum).
   Requires a vertical column on `spaces` + a check constraint or
   conditional FK. Most complex.

**Recommendation**: option 1 (text + per-Space role catalog). Pair
with a trigger that validates the typed-text value against
`spaces.capabilities['roles']` for that row's space_id. The Dart
side already uses string keys (`RoleLabels.of`); the schema
hardness is the only place the enum bites us.

### `public.spaces.capabilities` — generic, fine

The `capabilities` JSONB on spaces is already vertical-agnostic by
design. Adding a `vertical text not null default 'childcare'`
column to `public.spaces` (or storing it under
`capabilities['vertical']`) is the unblocking change. The
`verticalLabelsProvider` is ready to read it.

### `public.subjects` — has childcare-specific columns

Schema has `first_name`, `last_name`, `date_of_birth`, `photo_url`
— all generic. But also:

- `photo_consent boolean` — childcare-specific (parental consent)
- `pickup_strict boolean` — childcare-specific
- `authorized_pickup_guardian_ids uuid[]` — childcare-specific
- `medical_conditions text[]` / `allergies jsonb` /
  `medications jsonb` — healthcare-flavored but applicable to
  childcare too. Construction's "subject" (a project) has no
  medical context.

**Migration approach**: leave the columns; gate the form sections
behind `Space.capabilities['vertical'] == 'childcare'` (or a per-
section feature flag). Subjects can have NULL in irrelevant columns;
construction `project` rows never touch them. JSONB columns
default to `{}` / `[]` so nothing rejects.

### `public.groups` — childcare-shaped via capabilities

Schema-wise generic (`name`, `space_id`, capacity, `capabilities
jsonb`). Childcare baking comes through the JSONB:
- `age_band` (infant / toddler / preschool / prek / mixed)
- `tracks_diapers` / `tracks_naps` / `tracks_bottle_feeds`
- `has_field_trips`

Construction's `crew` analog needs different flags (`crew_size_band`?
`union_local`? `osha_certified`?).

**Migration approach**: per-vertical capability vocabulary, same as
`MemberCaps` → `CoreCaps` + `ChildcareCaps`. New verticals add
`ConstructionGroupCaps.crewSizeBand` etc. The JSONB schema is
already extensible.

### `public.attendance_records` — childcare-specific name

The fast path for "who's here today." Schema is generic — `space_id`,
`group_id`, `subject_id`, `recorded_at`, `status` — but the **table
name** is childcare-flavored. Construction's "who's onsite" is the
same shape with a different label; healthcare's "shift roll call"
likewise.

**Migration approach**: leave the table name; the UI surface
already routes through `VerticalLabels.attendanceNoun` (added in
Wave 1) so the user-facing text swaps. SQL queries / RLS / sync
rules unchanged.

### `public.guardians` and `public.subject_guardians`

Childcare-specific entities — the parent / authorized-pickup
contact layer. Construction has no analog (well, an emergency
contact maybe, but that's a degenerate version).

**Migration approach**: gate the entire surface behind
`Space.capabilities['feature_family_login']` (or a derived
`vertical == childcare`). The tables stay; non-childcare verticals
just never write to them and never expose the family-side routes.

### `public.invites.role`

Type is `public.member_role` enum. Same vertical-readiness issue
as the enum itself — fixed when we move roles to text.

### Sync rules (`supabase/sync_rules.yaml`)

The `by_space` stream gates every query on
`space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`.
That's vertical-agnostic. The sync rules don't need to change for
multi-vertical.

The childcare-specific bit is which TABLES are in `by_space` —
e.g. `guardians`, `subject_guardians`, `permission_slips`,
`headcounts`. Construction's hypothetical `rfis`, `purchase_orders`
would join `by_space` alongside. Same pattern, just more tables.

### RLS policies

Every table has policies gating on `space_id = app.current_space_id()`.
Vertical-agnostic. New verticals don't need new RLS patterns; just
write tables with the same `space_id` shape and add policies.

---

## What WOULD need a schema migration for construction

The minimum vertical-readiness migration:

1. **`alter table public.spaces add column vertical text not null
   default 'childcare';`** — the single config flip. Plus an enum
   check constraint for valid values.
2. **`alter type public.member_role rename to legacy_member_role;`
   + `alter table public.members alter column role type text;`** —
   drop the enum constraint so construction roles can land.
3. **`alter table public.members add column role_canonical text;`**
   (optional) — a normalized role string the omnibox catalog can
   group by, separate from the display label.
4. **New tables for construction-specific entries** (`rfis`,
   `purchase_orders`, `safety_briefings`, etc.) with the same
   `space_id` + RLS + sync-rule pattern.
5. **A `public.role_catalog (space_id, role_key, label, default_caps
   jsonb)` table** — replaces `RoleBundles.defaultsFor` with a
   per-Space row. Lets construction's "foreman" have a different
   capability seed than childcare's "lead teacher" within the same
   binary.

That's it. No sweeping schema rewrite. The engine is already
domain-agnostic at the table-shape layer — only the role enum +
the missing `vertical` column are hard blockers.

---

## What's deferred until the construction pilot is real

- The actual ALTER TYPE / data backfill (~30-min migration once we
  commit)
- The `role_catalog` table + per-Space role seeding
- Per-vertical feature folder gating in Dart (the
  `lib/features/pickup/` example)
- Per-vertical `OmniboxEntry` registration (today the catalog is a
  single global list; would split into per-vertical bundles)

When that pilot lands, this doc is the checklist.

---

## Maintenance

When you change anything that affects the multi-vertical readiness
of the schema (new table, new enum, new RLS policy that references
a childcare-flavored column), come back and update the relevant
section here. The doc earns its keep by being the single artifact
the migration design will read.
