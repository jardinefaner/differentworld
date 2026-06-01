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

## Making it more useful — the connections (roadmap)

A flat list of things is a notebook. Supplies earn their keep when they're
**connected** to the rest of the app along the dimensions that already
exist — *where* (locations), *what needs them* (activities), *who tends
them* (missions), and *what's running out* (low-stock). In rough
value-per-effort order:

1. **Location lens** — the dimension the user named ("different
   locations"). Each supply optionally points at a **real location** from
   the Locations catalog (Art Barn, Gym, Pool) *plus* a free-text sub-spot
   ("Cabinet B"). Then:
   - The supplies list gains a **"By location"** view → *"what's in the Art
     Barn?"*
   - Each **Location** shows **its own inventory** (Locations + Supplies
     become two views of one truth).
   - Schema: add nullable `location_id` (→ locations) beside the existing
     free-text `location`. Keep free-text for fine spots / programs that
     don't model locations.
   - *Low-fork, unblocked, makes two features richer at once.*

2. **Restock list** — the low-stock flag (already stored) becomes a
   one-screen **shopping list**: "Running low (5)". Pairs with the **Supply
   Keeper mission** — the kid who flags low items feeds the director's
   reorder list. *Pure UI over existing data; no migration.*

3. **Quick adjust** — a `−1 / +restock` tap on a supply so counts stay
   real without opening the editor. Deliberately light — not a warehouse
   ledger, just "we used some."

4. **Activity bill-of-materials** (the original "used by our other
   things") — `activity_supplies` join → an activity declares *"needs 12
   markers"*; a schedule block / day rolls up a **pack list**; a trip gets
   a **checklist**. Linked by id, never copied names.

5. **Recognize-it photos + "how it's put away"** — a photo per supply so
   anyone can identify it; the *putaway* shot doubles as the **Mission
   manual** image ("this is how the bin should look when done"). The
   `photo_url` column already exists.

The throughline: **location · activity · mission · low-stock** are the four
wires. The Location lens (#1) is the natural next build — it's exactly what
the user pointed at, it's unblocked + solo-testable, and it makes the
Locations catalog and Supplies reinforce each other instead of sitting
apart.

## Privacy

Supplies are program property, not child data — low sensitivity. Still
space-scoped by RLS like everything else. Supply photos avoid incidental
children in frame (a UI nudge, not enforced).
