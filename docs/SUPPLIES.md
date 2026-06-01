# Supplies — the program's inventory, wired in

The design for [VISION.md](VISION.md) **#15**.

> "we have a list of our inventory... the best way of storing them and
> having them be used by our other things in here"

Two questions, two answers: **how to store it**, and **how the rest of
the app uses it**.

---

## 1. How to store it — a catalog, not notes

A single synced table `supplies` — one row per thing the program owns.
It follows the architecture invariants (carries `space_id`, uuid PK
generated client-side, RLS gated on space, syncs via `by_space`).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | client-side `Uuid().v4()` |
| `space_id` | uuid | the program (every synced table carries it) |
| `name` | text | "Washable markers" |
| `category` | text | "Art", "Sports", "Snack"… (free text, suggested chips) |
| `quantity` | real? | how many on hand (nullable — not everything is counted) |
| `unit` | text? | "boxes", "reams", "balls" |
| `location` | text? | "Cabinet B", "Gym closet" |
| `low_stock_threshold` | real? | surfaces a "running low" flag when set |
| `photo_url` | text? | **Storage path**, not bytes (binary-media rule) |
| `notes` | text? | |
| `created_at` / `updated_at` | timestamptz | ISO strings locally |

Why a real table and not a JSON list on the program: you want to
**reference** items by id from other features, aggregate across them
("what do we need for today"), and restock/rename in one place. A blob
can't do any of that.

Photos of a supply go to Supabase Storage and the row carries the path —
same path as person photos (`person-photos` bucket pattern), never bytes
over PowerSync.

---

## 2. How other things use it — reference by id, never by copied name

The dream is "having them be used by our other things." That's a
**reference** model: supplies is the catalog; consumers point at it.

### Activities → a bill of materials

A join table `activity_supplies`:

| Column | Type |
|---|---|
| `id` | uuid (PK; join tables still need an explicit id — see CLAUDE.md) |
| `space_id` | uuid |
| `activity_id` | uuid → activities |
| `supply_id` | uuid → supplies |
| `quantity` | real? (how many this activity needs) |

So the activity card shows **"You'll need: 12 markers · 1 ream paper"**,
pulled live from the catalog. Rename "markers" → "washable markers" once,
and every activity updates.

### Schedule blocks / trips → a derived pack list

A schedule block already references an activity. So a block's pack list is
**derived** — `block.activity → activity_supplies → supplies` — no new
table needed for the common case. A day view can roll up **"everything
today's blocks need"** by unioning across blocks. (A block with ad-hoc
extras beyond its activity could get a direct `block_supplies` later; not
in v1.)

### Why not denormalize

Copying supply names into activities would mean: rename in N places,
no aggregate "what's needed today," no low-stock view. The id-reference
keeps one source of truth — the same principle as the rest of the schema.

---

## Surfaces

Per CLAUDE.md, **library surfaces live under Settings, not the drawer**
(like Activities and Locations). So:

- **Settings → "Supplies"** → a list (grouped by category) + add/edit
  sheet. The inventory you maintain.
- **Omnibox:** `/supplies` slash command (+ per-item search entries so
  "markers" finds the row).
- **Activity edit screen:** a "Supplies needed" picker (slice 2) that
  writes `activity_supplies`.
- **Block / day view:** a "Pack list" section (slice 2) derived from the
  blocks' activities.

Not in the main drawer (it's a library, not a daily destination).

---

## Build slices

1. **The catalog.** `supplies` table (6-place checklist) + DAO + the
   Settings list + add/edit sheet + `/supplies`. *Single-device
   testable.* The inventory exists.
2. **The link.** `activity_supplies` table + a picker on the activity
   editor + the activity card "you'll need…" + a block/day pack list.
   *This is the "used by our other things" payoff.*
3. **Stock awareness (optional, keep minimal-data).** Low-stock flag from
   the threshold; maybe a quick "−1 / restock" adjust. Deliberately light —
   we are not building a warehouse system; we're making the list useful.

## Sync activation checklist (when slice 1's migration lands)

Adding `supplies` to `by_space` is the documented synced-table flow:
migration → `supabase db push` → **paste sync rules into the PowerSync
dashboard + Deploy** → regen → **clear local storage on every device**
(uninstall on mobile). Until the dashboard deploy + local wipe, the table
works locally (offline-first) but won't propagate.

## Privacy

Supplies are program property, not child data — low sensitivity. Still
space-scoped by RLS like everything else. Supply photos avoid incidental
children in frame (a UI nudge, not enforced).
