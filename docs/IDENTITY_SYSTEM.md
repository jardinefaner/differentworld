# Identity System — "This is you, and these are your tools"

**Status:** design synthesis (2026-06-01). Fuses four lenses (archetype taxonomy · ID-card / one-template · role·ability·trait → affordance · minimal-data / the book) into one buildable brief. Grounded in the shipping capability system (`capabilities.dart`, `capability_keys.dart`), the viewer lens (`viewer.dart`), the toolkit template (`toolkit_screen.dart`), the 23 animal role cards (`roles.dart`), the additive entries ledger (`entries_providers.dart`), and `docs/ROLES_SMART_PRACTICE.md`, which already did half this synthesis.

> Companion to `docs/ROLES_SMART_PRACTICE.md`. That brief designed the *practice* (the SMART daily loop, the meeting runner, the non-punitive ledger). This one designs the *identity* (who you are, the tools that follow, the book it all becomes). They share one spine: `members.capabilities` JSONB + additive `EntryKind`s on the existing `entries` table — **no new sync table, no migration.**

---

## 1. The one principle

**Identity decides what's on your table; the app sets that table for you and never shows you the doors that aren't yours.** Three axes describe a person: **role** (what you're trusted with — gates real capabilities and RLS), **ability** (the verbs you hold — the floor of what's reachable), and **archetype** (how you show up — a self-chosen temperament that only *warms* the surface, never gates it). The app reads all three through one lens and renders them as an **ID card** (the cover: who you are, how you work) over a **book** (the contents: what you documented, assembled live from the device). It collects almost nothing to do this — archetype and work-style ride a JSONB blob the lens already reads, the book renders from local Drift, photos and voice live in Storage and only a path ever syncs — because the same contract that keeps the data minimal and on-device is exactly what licenses the book to feel like a gift rather than a record. **Abilities gate (hide, never disable — you see your tools, never a wall of greyed-out doors); traits flavor (reorder and spotlight, structurally unable to subtract); and everything a person makes is theirs, additive, with no place in the schema to record a verdict about them.** That is the whole system: *this is you, and these are your tools.*

---

## 2. The archetype catalog

The user named three — **visionary, doer, protector.** We extend to **eight**, because eight (a) gathers all 16 distinct traits the 23 animal cards `build` without forcing unrelated traits into one bucket, and (b) is small enough that a kid can learn the whole set and a director can scan a roster of glyphs at a glance.

An archetype is the answer to **"how do you show up?"** — orthogonal to role (authority) and specialty (subject matter). It is the *warmest* axis: role and specialty are assigned by the program; **your archetype is yours.** It maps 1:1 onto the kid side — a kid says *"Today I am a Fox"* (a Fox **builds** problem-solving); the staff reading is *"I'm a Sage — I figure things out."* Same object, labels swapped (`ROLES_SMART_PRACTICE.md` §1). A kid's animal role *expresses* an archetype; an adult's archetype is the grown-up name for the trait the animal builds.

**Hard rules (from the viewer lens + `ROLES_SMART_PRACTICE.md` §3):** not a test, not a diagnosis, no MBTI/clinical framing. No archetype is lesser — every one names a strength the group needs; there is no shadow-side or "weakness" column. It is **self-authored, never assigned by a manager.** It **decorates, never gates** (live-block `R0` — the cap is still the gate).

| Glyph | Archetype (staff reading) | Kid name | Essence (rendered verbatim on the card) | The gift to the group | `builds` traits it gathers | Animal cards that express it |
|---|---|---|---|---|---|---|
| ✨ | **Visionary** | Spark | *"I see what could be, and I get us excited to start."* | direction & momentum | confidence, optimism | 🦒 Giraffe · ✨ Firefly · 🌻 Sunflower |
| 🛠️ | **Doer** | Maker | *"Give it to me and it gets done."* | things actually ship | diligence, responsibility | 🐝 Bee · 🦀 Crab |
| 🛡️ | **Protector** | Guardian | *"I watch over us — the people and the rules that keep us safe."* | safety & trust | courage, persistence | 🌱 Seed · 🕷️ Spider |
| 🌿 | **Anchor** | Anchor | *"When it gets loud, I stay calm and keep us steady."* | stability | calm, patience | 🐳 Whale · 🦋 Butterfly · 🌳 Oak Tree |
| 💛 | **Connector** | Friend | *"I notice how everyone's doing, and I bring us together."* | belonging | kindness, connection | 🐬 Dolphin · 🐘 Elephant · 🍄 Mushroom |
| 🔍 | **Sage** | Sage | *"I figure it out — I look closely and find the way through."* | clarity | problem-solving, focus, cleverness | 🦊 Fox · 🐙 Octopus · 🐦‍⬛ Crow · 🦉 Owl · 🐰 Rabbit |
| 🌱 | **Seeker** | Seeker | *"I'm curious about everything — I try the new thing first."* | growth & courage | curiosity, perseverance | 🐦 Hummingbird · 🌊 River |
| 📣 | **Beacon** | Beacon | *"I see what you did well, and I make sure everyone knows."* | morale & recognition | teamwork | 🐜 Ant · 🐺 Wolf · 🐧 Penguin |

**Coverage check (verified against `roles.dart`):** all 16 distinct `builds` values land in exactly one archetype; all 23 animal cards map; no archetype is empty; no trait is orphaned. Sage gathers five cards because focus / problem-solving / cleverness all cluster on "thinking"; Beacon takes the three teamwork cards. (The deck was already weighted this way — teamwork ×3, focus / problem-solving / kindness / patience / confidence ×2 each, ten singletons.)

**One naming judgment to confirm:** teamwork → **Beacon** rather than its own 9th "Collaborator" archetype, because being a good teammate is an *outcome every archetype contributes to*, not a distinct way of showing up — and the Beacon (who makes teamwork *visible*) is the closest temperament. If you'd rather name collaboration explicitly, a 9th **⚡ Teammate / "the Collaborator"** cleanly takes 🐜 Ant / 🐺 Wolf / 🐧 Penguin. We lean 8 (tighter set, easier for a kid to hold); the deck supports 9. Your call.

**Naming notes for the user:** *Doer* is kept verbatim, though **Maker** (its kid name) carries more craft if you'd prefer it staff-side too. *Visionary / Protector* are yours unchanged. The five additions — Anchor, Connector, Sage, Seeker, Beacon — are the temperaments a real early-childhood team has beyond vision/execution/safety: the steady one, the glue, the thinker, the explorer, the encourager.

**Storage & holding.** A person holds a **primary** plus an optional **secondary** — never a full ranking, never percentages (the moment you allow "40% Spark / 30% Maker" it becomes a personality test). Two named strengths, warmly. That's the ceiling.

```
members.capabilities.archetype          // primary, e.g. "sage"   (string)
members.capabilities.archetypeSecondary // optional, e.g. "anchor" (string, nullable)
```

The primary renders as the ambient glyph everywhere; the secondary shows only on the full ID card ("Sage, with a touch of Anchor"). `Capabilities.getString` / `getStringList` already read both — **no migration.**

---

## 3. The ID card + the one-template

### 3a. There is ONE info-template — the `InfoCard`

Every reference surface in the app — a toolkit tool, a role's permission bundle, an animal role card, a program manual page, **and a person** — renders through the same frame: an accented breadcrumb, a title + lede, an optional hero, and an ordered stack of labelled `SectionCard`s with semantic tone. The Toolkit already *is* this template (`ToolkitToolDetailView` in `toolkit_screen.dart` — breadcrumb chip → script-first section → supporting sections → collapsed-by-default sensitive section). We lift the shape into a tiny presentation contract so "all manuals, all menus in ONE template" becomes a *type*, not an aspiration. **No data model, no DB** — same posture as the toolkit-lives-in-Dart rationale.

```dart
// lib/shared/widgets/info_card.dart  (NEW — ~120 lines)

/// The ONE template. Every reference / manual / menu / identity surface
/// renders as an InfoCard: an accent breadcrumb, a title + lede, and an
/// ordered stack of InfoSections. This is the toolkit detail screen's
/// shape, lifted so it's the app's single info vocabulary.
class InfoCard extends StatelessWidget {
  final InfoCrumb? crumb;     // accent pill: glyph + label + color (category color, role color, archetype color)
  final String title;         // "The Cool Down" / "Maria Lopez" / "Today I am a Fox"
  final String? lede;         // the "when" line / the identity sentence / the role summary
  final Widget? hero;         // PersonAvatar, big emoji, category glyph — the identity anchor
  final List<InfoSection> sections;
}

class InfoSection {
  final IconData icon;
  final String title;             // "Quick script" / "How I work best" / "Your tools" / "My 3 habits"
  final SectionTone tone;         // featured / neutral / danger / playful
  final Widget child;
  final Widget? trailing;         // copy button, expand toggle, edit pencil
  final bool collapsedByDefault;  // sensitive content starts closed (the toolkit "Instead of" pattern)
}
```

`ToolkitToolDetailView` then becomes `InfoCard(crumb: …, title: tool.name, lede: tool.when, sections: [Quick script (featured), Try this, Why this works, Instead of (collapsed)])` — a ~40-line refactor that proves the extraction by reuse and is **golden-stable** (no behavior change). This is the **first wave**.

### 3b. The ID card = an `InfoCard` whose subject is a person

Four sections, always in this order, because the order is the message:

| # | Section | Tone | Holds | Kid voice | Staff voice |
|---|---|---|---|---|---|
| hero | identity anchor | — | `PersonAvatar` (staff) / big emoji (kid) + name | "Today I am a Fox 🦊" | "Maria Lopez" + avatar |
| 1 | **Who I am** | playful (kid) / featured (staff) | archetype(s) + the one-line essence | "I'm a Sage — I figure things out" | "🛡️ Protector · I watch the room's edges" |
| 2 | **How I work best** | neutral | Way-of-Working chips (staff) / the 3 habits (kid) | "gather · point the way · stay busy" | "I think in writing — send me the agenda the night before" |
| 3 | **Your tools** | featured | role-gated affordances as an *empowering toolset* | "Things I can do today" | live shortcuts: Observe · Attendance · Schedule · Pickup… |
| 4 | **On file** | neutral, **collapsed** | certs + role label + specialty (the formal record) | *(omitted)* | "Group Leader · CPR on file · Reading Specialist" |

The crumb's **color is the archetype's color** — so your card is *tinted by your temperament* (a Protector reads in steady blue, a Spark in warm amber). This is the most literal possible rendering of "the app highlights those — are they a visionary, a doer, a protector?": the highlight is the card's own color.

**Section 3 ("Your tools") is the answer to "these are your TOOLS."** It is not a settings checklist of booleans — it is a grid of `FeatureCard`s, each a *live entry point* derived from the viewer lens. A teacher taps "Observe" and lands in the observation flow; the permission *becomes* the affordance. This is the inverse of the read-only `roles_screen.dart` (which lists caps as ✓/🔒 rows for a director auditing a role — *permissions granted*). The ID card reads as *powers held*. Same data (`viewerProvider`), opposite emotional valence — and that valence flip is the entire "empowering, not a permission list" ask. Cert-gated tools (`canDrive`, `canAdministerMedication`) appear here **only when the cert is on file** — the card shows you the tool the day you earn it. Because it's `viewerProvider`, the **dev role-impersonation override already works on it** (`viewerKindOverrideProvider`): a director can "try on" a substitute's card and literally see the smaller toolset.

**Section 2 ("How I work best")** is the Way-of-Working fields from `ROLES_SMART_PRACTICE.md` §3, edited in place via `InlineEditableText` (no form, no save button — tap, type, done, optimistic Drift write to `member.capabilities`). All ride the JSONB blob, **no migration:**

| Key (`CoreCaps`) | Card chip reads | What it quietly does elsewhere |
|---|---|---|
| `processingStyle` | "I think in writing" | meeting assistant sends *you* the agenda the night before |
| `transitionNeed` | "5 min between blocks" | Today stops auto-nudging you; live-block grants 15-min grace |
| `commsWindow` | "Batch my pings at 3pm" | non-urgent staff messages hold until your window |
| `bestHours` | "Sharpest 8–11am" | advisory chip the scheduler + substitute-handoff read |
| `hardNo` | "Don't cold-call me in all-staff" | advisory chip; overriding it logs an `honor_gap` (§3 mechanism) |
| `freeText` | one sentence, **verbatim, never normalized** | the human note nothing else parses |

For the **kid card**, section 2 is the chosen role's three habits as the existing 3-line checklist (`role_cards_screen.dart` already builds exactly this) — each tap writes a `habit_mark`. The kid doesn't author prose; their habits *are* their way of working for the day.

### 3c. Where it lives

Three surfaces, in priority order (the CLAUDE.md four-discovery-surface rule applies; claim all four in `docs/FEATURES.md` so `feature-mapper` doesn't flag drift):

1. **`/me` — the canonical route.** The signed-in viewer's own ID card; the "this is YOU" home. Router (`/me`, sibling of `/today`), omnibox ("Your ID card", keywords `me, my card, who am i, my tools`), settings row. **Re-point the drawer header tap** (`main_drawer.dart:87`, today → `/settings/team/${member.id}`) to `/me` — the most-used tap in the drawer now lands on your card, not your editable member-detail.
2. **Other people's cards** — from the team list, tapping a member opens *their* card (sections 1/2/4 read-only; section 3 shows what *they* can do, useful for a director deciding who to assign). The card's "Edit details" action (director-gated via `viewer.canEditMember(other)`) drops into the existing `member_detail_screen.dart` editor. **ID card = the read/identity view; member-detail = the admin/edit view.**
3. **First launch** — after a teacher accepts an invite, a one-time, skippable **"Set up your card"** (pick your archetype from one sheet of eight `FeatureCard`s; optionally fill a Way-of-Working chip). Self-introduction as onboarding. Gate on `archetype == null` so it shows once and never nags.

### 3d. The generalized one-template

Point the existing toolkit renderer (`toolkit_screen.dart`'s phone-feed / tablet-master-detail) at the **affordance catalog** (§4) through the resolver: a "My Tools" / manual surface where each section is an affordance group (Document · Track · Care · Lead · Connect), each row a tool you actually have, each detail page an `InfoCard` of its how/when/why. The **filter** is the resolver (only your tools show — the floor); your **archetype orders the sections** (the flavor — a Connector's manual opens on Team/Meetings; a Sage's on Observations). So "one template" is satisfied by reusing the toolkit renderer rather than building a third screen alongside toolkit / roles-reference / quick-actions that don't know who's looking.

---

## 4. Role · ability · trait → affordance

> **One sentence:** abilities decide what's on your table (the **floor** — gated, hide-don't-disable); traits decide how it's arranged for your hand (the **flavor** — reorder/spotlight-only, structurally unable to subtract); one resolver computes both from the `members.capabilities` blob the viewer lens already reads.

This is a direct inversion of the live-block law (`R0 — it decorates; it never gates`) pointed at the affordance layer. **Floor gates. Flavor decorates. They are different code paths and must never collapse into one.**

### 4a. The problem it fixes

Today the *floor* logic is correct but **scattered** — `if (viewer.canObserve && visibleGroups.isNotEmpty)` is hand-written in `quick_actions.dart`, again ~15× in the omnibox catalog, again in `today_sections.dart`, `group_detail_screen.dart`, `subject_detail_screen.dart`. Each surface re-derives "is this mine, and is it reachable right now." When the rule changes you must edit every site. And the *flavor* layer (traits) **does not exist at all.** The fix: **one resolver, two layers, every surface reads it.** (`quick_actions.dart` already documents the target instinct in its header — *"Hide, don't disable… avoids the disable-by-error anti-pattern."* — this generalizes that one widget's instinct into a law every surface obeys.)

### 4b. The data model — an affordance is declared once

```dart
// lib/core/affordances/affordance.dart  (NEW)

/// A single thing the user can DO or GO — a button, a menu row, a tile,
/// an omnibox action. Declared once; rendered by every surface that asks
/// the resolver for its slice.
class Affordance {
  const Affordance({
    required this.id,            // stable: 'observe.new', 'attendance.take'
    required this.label,         // i18n key
    required this.icon,
    required this.surfaces,      // {AffordanceSurface.quickAction, .omnibox, .drawer, …}
    required this.gate,          // THE FLOOR — pure (Viewer) => bool. Abilities only.
    this.reachable,              // runtime precondition — (Ref) => bool (assignments, data)
    this.route, this.action,     // deep-link target, or imperative handler
    this.affinities = const {},  // THE FLAVOR — which archetypes float this. NEVER gates.
    this.keywords = const [],    // omnibox discovery
  });
}
enum AffordanceSurface { quickAction, omnibox, drawer, settings, contextMenu }
```

The catalog (`lib/core/affordances/affordance_catalog.dart`) is plain Dart — editorial, static, offline-forever, zero sync cost (same rationale as `toolkit_catalog.dart`). Each entry lifts logic inline today:

```dart
Affordance(
  id: 'observe.new', label: L.newObservation, icon: Icons.edit_note_outlined,
  surfaces: {AffordanceSurface.quickAction, AffordanceSurface.omnibox},
  gate: (v) => v.canObserve,                       // FLOOR
  reachable: (ref) => _hasVisibleGroup(ref),       // PRECONDITION
  action: startNewObservation,                     // reuse existing fn verbatim
  affinities: {Archetypes.connector, Archetypes.protector}, // FLAVOR — these float it
  keywords: ['note', 'document', 'moment'],
),
```

### 4c. The resolver — two layers, in this exact order

```dart
// lib/core/affordances/affordance_resolver.dart  (NEW)

/// THE one provider every surface reads. .family on the surface so a screen
/// asks only for its slice. .autoDispose per the auto-dispose-family skill.
final affordancesForProvider =
    Provider.autoDispose.family<List<ResolvedAffordance>, AffordanceSurface>((ref, surface) {
  final viewer = ref.watch(viewerProvider);
  final archetype = viewer.archetype;              // NEW getter (reads CoreCaps.archetype)

  // ── LAYER 1: THE FLOOR (abilities) ──────────────────────────────
  // Pure capability gate + runtime reachability. TRAITS NOT CONSULTED.
  // This is the only place `visible` is decided.
  final onTable = _catalog
      .where((a) => a.surfaces.contains(surface))
      .where((a) => a.gate(viewer))                 // hide if not yours
      .where((a) => a.reachable?.call(ref) ?? true) // hide the tap-to-deadend
      .toList();

  // ── LAYER 2: THE FLAVOR (traits) ────────────────────────────────
  // Reorder + spotlight ONLY. Receives an already-filtered list; the
  // type literally cannot remove an entry — only .map + sort, no .where.
  return _applyFlavor(onTable, archetype);
});
```

**Why this shape makes the iron rule unbreakable:** `_applyFlavor` takes `List<Affordance>` (already filtered to the floor) and returns `List<ResolvedAffordance>` of the **same length** — a `.map` + sort, no `.where`. It is type-impossible for the trait layer to drop an entry. The justice property is encoded in the function signature, the same way `certifications.dart` encodes "no fail state" by having no fail column. (Mirror of `ROLES_SMART_PRACTICE.md`'s "the missing column is the guarantee" — here, *the missing parameter is the guarantee*.)

### 4d. The iron rule: a trait NEVER subtracts

- A trait can move a tool **up** (raise sort weight), **spotlight** it (a soft "for you" accent, never a lock), or **suggest** it (one rung higher in the omnibox).
- A trait **cannot** set `visible = false`, grey a tile, or remove an omnibox entry. **A Doer still sees the Insights tile a Visionary loves — it just sits further right.** Trait-driven UI *brightens what fits you*; it never dims what doesn't. (The inverse of the capability lens, which legitimately gates — and that distinction is the whole safety story: **caps gate, archetypes only warm.**)

### 4e. The no-shame justice rule — three guarantees baked into the resolver

1. **Hide, never disable.** The floor `.where`s tools OUT rather than emitting a disabled tile. No `enabled: false`, no greyed "you don't have permission" row, no lock on a door you can't open. A kitchen-staff member opening Today sees *Capture* and *Record meal* — a clean, full surface — **not** five greyed-out tiles announcing everything they can't touch.
2. **Empty is calm, never an error.** When the floor leaves a surface with zero affordances, render the designed `EmptyState` — *"You're all set for today."* — never a wall or "insufficient permissions." The narrowest role gets a complete-feeling screen.
3. **The path to MORE is an invitation, never a wall.** Where a tool is cert-gated, the absence isn't shamed; the member's own ID card shows *"Add a certification to unlock driving"* as an additive invitation on *their own* surface (mirroring `certifications.dart`'s "on file / not on file, never *fail*"). Expansion is a doorway you're invited through.

Because the resolver filters rather than flags, the shame surface (greyed walls) is **structurally absent.**

### 4f. What every surface does instead

`quick_actions.dart`'s hand-built list collapses to:

```dart
final tiles = ref.watch(affordancesForProvider(AffordanceSurface.quickAction));
if (tiles.isEmpty) return const SizedBox.shrink();   // "the whole row hides" — kept
// render each: spotlit ones get the soft "for you" accent; tap → route or action(ref)
```

The omnibox catalog's ~15 `if (viewer.canX)` blocks → one read, with `spotlit` raising rank and `keywords` already on the affordance. Drawer, settings — same. **One catalog, one resolver, every surface a thin renderer.** Migration is incremental and behavior-preserving for the floor (same gates, same preconditions) and purely additive for the flavor (archetype defaults to null → no reorder → identical to today). **A member who never picks an archetype sees exactly today's app.**

The new `Viewer.archetype` getter mirrors the existing `specialty` getter (`viewer.dart:142`): reads `member.caps.getString(CoreCaps.archetype)`. `Archetypes` becomes a closed catalog beside `SpecialtyKeys` in `capability_keys.dart` (`visionary, doer, protector, anchor, connector, sage, seeker, beacon`).

---

## 5. Minimal data · on-device · the book

The ID card is the **cover**. This section designs the **contents** — and the load-bearing reframe: **privacy is not the constraint that limits the book — it's the property that makes the book worth keeping.** A keepsake you'd hand your kid in fifteen years is precious only if it was *only ever theirs*. The contract that keeps the data minimal and on-device is exactly what licenses the book to feel like a gift.

### 5a. "Minimal data collection" as a checkable contract

Elevate the scattered privacy posture into a single artifact a future contributor (or a parent, or a regulator) can read and check. Mirror the patterns the codebase already trusts: `CAPABILITIES.md`'s rot-guard and `certifications.dart`'s "the missing column is the guarantee."

**Deliverable: `docs/THE_BOOK_CONTRACT.md`** — short, declarative, written *to the person whose book it is* (second person). Each clause names what's true in code today and what column/event deliberately does not exist:

| Clause (to the person) | Enforced by (real, in code) | The guard that keeps it true |
|---|---|---|
| **"Your book lives on your device first."** | Architecture invariant #1 — local SQLite is the source of truth; reads are Drift streams, writes optimistic. | The `offline-first` skill + "any `Supabase…from()` from UI is a bug." A future "just fetch it live" shortcut is a contract breach. |
| **"Your pictures and voice never become traffic we meter."** | "Binary media never goes through PowerSync" — the row carries a path; bytes go to private Storage via signed URLs (`attachments.url`). | The `photo-via-storage` skill. No image/audio bytes in any synced column, ever. |
| **"Nothing about a child is ever counted at the row level."** | "No analytics events that include child identifiers… event-level, never row-level." Insights are local `GROUP BY` in Drift. | No analytics SDK with a child/subject/member id in the payload. |
| **"There is no place to record a verdict about a person."** | `entries` columns (verified): `id, spaceId, groupId, subjectId, kind, body, photoUrl, details(JSON), recordedBy, recordedAt, updatedAt` — **no `score`, `rating`, `compliance`.** `certifications.dart` has expiry but **no "fail" state.** | *You cannot use a tool to punish if the tool has no place to record a punishment.* Copy this posture into every new `EntryKind`. |
| **"Your book is yours to give, never taken."** | `exports` pipeline: draft → owner previews → `markSent` with explicit recipients → `archive`. Signed URLs short-lived. | Sharing is opt-in, previewable, revocable — never a default-on sync of personal content to anyone but the owner. |

**The contract is a product feature, not legal boilerplate:** a tappable **"Why this stays yours"** affordance (a `showGlassSheet`) on the book's cover renders these five clauses in warm second-person. The parent doesn't see "we are compliant" — they see *"this is why I can trust the book,"* which makes them document more, which makes the book richer. **The contract is a growth loop, not a tax.**

**The teeth (rot-guard):** add one check to `feature-mapper` (or a sibling) — flag any new synced column named `score`/`rating`/`flag`/`compliance`/`deduction`/`verdict`, any new analytics call carrying a `subject_id`/`member_id`, and any new `Supabase…from()` read in UI/provider/repo code. The codebase already automated the four-places audit this way; the book contract gets the same treatment.

### 5b. The smallest "my book" surface

The endgame (showcase reel, year-end keepsake) is heavy and rightly deferred. But the *feel* — "this is becoming **my** book" — ships now, on-device, **zero new sync table, zero migration**, by reusing what exists.

**`/children/:id/book`** — a warm, page-like, chronological view of one child's documented life *as it exists today*: every observation, photo, recording, role habit-mark, grouped by day, newest first. Not a report (no PDF, no "sent" state) — a **living scrapbook the device renders for free.** For the family lens it's the natural expansion of the **"Photo of the moment"** card already in `family_today_screen.dart` (`_PhotoOfTheMomentPeek` is *one* page; this is the whole book).

Built entirely from existing parts: `entriesForSubjectProvider` / `familyEntriesForSubjectProvider` (spine), `attachmentsForEntityProvider` + `AttachmentsX.thumbUrls` (pictures + voice — recordings ride the same attachment rows with an `audio/*` mime, no new model), `PersonAvatar` + `ContentHeader` + `SectionCard` + `FeatureCard` + `PersonPhotoNetwork` (chrome), `dateKey` / `relativeTimeAgo` (grouping). The **cover** is the child's avatar + "{N} moments since {first entry date}" — the ID-card-as-cover, made literal — and under it the "Why this stays yours" sheet.

**The one genuinely new concept — a flag, not a feature:** a per-entry `inBook` flag stored in the entry's existing `details` JSON column (already a synced JSON string — verified — same home `ROLES_SMART_PRACTICE.md` used for member fields). Everything is in the book by default; the flag's real job is the inverse — letting the owner **gently set a moment aside** ("this incident note isn't a keepsake") without deleting the record. **Curation by subtraction, never by judgment** — the same shape as the no-fail-state contract: you can keep a moment *out*, but there's no place to mark it "bad." `EntryActions.setInBook({id, inBook})` reads-modifies-writes the `details` map (one optimistic Drift write); the book reads `details['inBook'] != false` (default-in); a long-press → "Set aside / Add back" is the entire authoring surface.

### 5c. How documenting compiles into the book

The deferred **showcase/growth-arc** (CLAUDE.md ~1719: `showcases` table mirroring `exports` — author/subject/format/storage_path/status — + `showcase_items` join referencing `attachment_id` or `entry_id`, backend render job) is the **bound** version of the same book; §5b is the **unbound, live** version. The cadence the user named maps cleanly:

| Cadence | What it is | Built from | Contract clause it leans on |
|---|---|---|---|
| **Daily highlight** | "{Name}'s day" — `inBook` entries from `todayKey()`. | The §5b book, filtered to today. Half-shipped as `_PhotoOfTheMomentPeek`. | On-device; nothing leaves. |
| **Weekly wrap** | A week's pages, optionally one `showcase` row (format=`web`). | `showcase_items` pointing at the week's ids — **references, not copies.** | "Yours to give" — shareable only via the owner-initiated, previewable, revocable export flow. |
| **Term portfolio / Year keepsake** | The reel/film. | `showcase` (format=`mp4`) + backend render job (encoding is heavy — *off* device, as sketched). Source stays on-device; only the previewed output is rendered. | All five clauses. |

**The single most important structural fact:** because the showcase reuses the `exports` shape (already opt-in, previewable, revocable, signed-URL-gated, owner-authored), **compiling the book upward into a keepsake requires no new privacy machinery.** The book contract is preserved *for free* by building the showcase as a sibling of `exports` rather than a new pipeline. The curation surface is the `inBook` flag plus a `showcase_items` selection step that looks exactly like the recipient-picker in `send_export_screen.dart`. **Don't invent a second sharing system; the export system already encodes the justice.**

---

## 6. Maps onto what exists

The capability + viewer-lens + role-bundle + toolkit-template + kid-role-card machinery is **all real and load-bearing.** The identity/archetype/work-style layer and the generalized one-template are green-field, but ride existing storage.

| This needs… | …already shipping as | …or new primitive |
|---|---|---|
| Togglable UI by ability | `members.capabilities` JSONB + `viewerProvider` cap lenses (66 read sites) | — |
| Typed cap keys (no magic strings) | `capability_keys.dart` — `CoreCaps` / `ChildcareCaps` / `SpecialtyKeys` / `RoleBundles` | add `CoreCaps.archetype` + `archetypeSecondary` + a closed `Archetypes` catalog (one-line, no migration) |
| "Who's looking" → which tools | `viewer.dart` — `Viewer` + `GuardianViewer`, impersonation override (`viewerKindOverrideProvider`) | add `viewer.archetype` / `archetypeCard` getters (mirror the `specialty` getter at `viewer.dart:142`) |
| The kid trait card | `roles.dart` — 23 `RoleCard`s, each with `builds` + `role_cards_screen.dart` (`_RoleCardFace` is 80% of the kid ID card) | `archetypeForTrait(builds)` lookup map (the animal→archetype bridge; `roles.dart` stays untouched) |
| The "one template" | `toolkit_screen.dart` (`ToolkitToolDetailView` section grammar) + `toolkit_catalog.dart` (lives-in-Dart rationale) | extract `InfoCard` / `InfoSection`; refactor toolkit onto it; feed it the affordance catalog |
| Centralized affordance gating | the scattered `if (viewer.canX)` sites (`quick_actions.dart`, `omnibox_catalog.dart`, …) | `affordance.dart` + `affordance_catalog.dart` + `affordance_resolver.dart` (the floor/flavor resolver) |
| Self-authored work-style fields | `members.capabilities` JSONB (`ROLES_SMART_PRACTICE.md` §3 designed the fields) | add the WoW keys to `CoreCaps`; render/edit via `InlineEditableText` on `/me` |
| Edit home for identity | `member_detail_screen.dart` (already edits `specialty` via a director-gated picker; imports `CapSwitch`) | the trait band — **self-editable** (unlike specialty), beside the existing specialty picker |
| The ambient identity chip | `FeatureCard` / `SectionCard` / `PersonAvatar` tone vocabulary | small `ArchetypeChip` (glyph + label) |
| The book's spine | `entriesForSubjectProvider` / `familyEntriesForSubjectProvider` + `attachmentsForEntityProvider` + `AttachmentsX.thumbUrls` | `EntryActions.setInBook` (RMW on `entries.details` — no new column) |
| The book's "becomes a film" endpoint | the deferred `showcases`/`showcase_items` sketch (CLAUDE.md) + `exports_providers.dart` share pipeline | build `showcases` as a sibling of `exports` (no new sharing/privacy machinery) |
| The minimal-data promise | scattered across CLAUDE.md (local-first, binary-via-Storage, no row-analytics, no-fail-state) | `docs/THE_BOOK_CONTRACT.md` + one `feature-mapper` check |
| The emergent kid roll-up | additive `EntryKind`s (`habit_mark`) on the existing `entries` table (`ROLES_SMART_PRACTICE.md` §4) | presence-only `GROUP BY` over `habit_mark` → `archetypeForTrait` |

**Per the `CAPABILITIES.md` rot-guard ("don't add a capability you can't toggle yet"): ship `CoreCaps.archetype` *with* its picker in the same slice** — never the key alone.

---

## 7. Build seed

The smallest slice that proves the feel, then the next two.

### (a) `/me` ID card — role + a self-chosen archetype + your tools

1. **`Archetypes` closed catalog + `WorkStyle`-style cards** in `lib/core/identity/archetypes.dart` (pure Dart: `key, glyph, label, kidName, essence, gift, color` ×8) + `archetypeForTrait` map. Add `CoreCaps.archetype` constant. Add `viewer.archetype` / `archetypeCard` getters.
2. **The archetype picker** — `showGlassSheet` of eight `FeatureCard`s, wired onto `member_detail_screen.dart` as a **self-editable** field beside the existing specialty picker. One optimistic Drift write to `member.capabilities`.
3. **`/me` rendering an `InfoCard`** with the four sections: **Who I am** (archetype + essence, tinted by the archetype color), **How I work best** (placeholder if no WoW fields yet), **Your tools** (driven directly by `viewerProvider` cap getters — the §3b grid), **On file** (collapsed; certs + role + specialty). Wire the four discovery surfaces + repoint the drawer header tap + claim in `FEATURES.md`.

> **Proof of feel:** pick "Sage" on your card → the card tints, the essence renders, and your tools grid shows exactly what `viewerProvider` grants — offline, one frame, no greyed-out doors. If a teacher opens `/me` and sees *themselves* — their temperament, their powers — the rest is mechanical extension.

### (b) Extract `InfoCard` + the affordance resolver (the two spines)

1. **`InfoCard` / `InfoSection`** in `lib/shared/widgets/info_card.dart`; refactor `ToolkitToolDetailView` onto it (golden-stable, no behavior change). The `/me` card from (a) re-homes onto it.
2. **`affordance.dart` + `affordance_catalog.dart` + `affordance_resolver.dart`**; seed ~8 affordances by lifting the inline gates from `quick_actions.dart`; **convert `QuickActions`** to read `affordancesForProvider(.quickAction)`. Behavior-identical for the floor; the row now reorders by archetype with a soft "for you" accent on spotlit tiles. *This is the proof: the floor is unchanged and centralized; the flavor is new and never subtracts.*

### (c) The book + the contract

1. **`docs/THE_BOOK_CONTRACT.md`** (the five clauses) + the **"Why this stays yours"** `showGlassSheet`.
2. **`/children/:id/book`** rendering existing entries + attachments grouped by day + the avatar cover + the contract sheet. The `inBook` set-aside (`EntryActions.setInBook` on `entries.details`), recording-medium artifacts, and role habit-mark pages are additive once the spine renders.

> **Proof of feel:** a parent scrolls their kid's book-so-far — months of moments assembled beautifully — and notices *the app did it without taking anything.* The keepsake endgame is then a render job away.

Each slice is independently shippable and behind no new sync table.

---

## 8. The throughline (for the user)

- **"All manuals, menus, info in ONE template"** → `InfoCard`, lifted from the toolkit you already built. A toolkit tool, a role's permissions, a manual page, the ID card — all the same frame.
- **"This is YOU"** → `/me`, the front door of the drawer, your card tinted by your archetype.
- **"These are your TOOLS"** → section 3, the viewer lens re-read as a grid of *powers you hold and can tap*, not a checklist of permissions granted.
- **"Visionary / doer / protector — help me name them"** → eight named archetypes (**Visionary · Doer · Protector · Anchor · Connector · Sage · Seeker · Beacon**), self-chosen, stored with no migration, the adult analog of the kid deck's `builds` trait — so a kid who keeps choosing Foxes and Owls **discovers** they're a Sage while their counselor **chooses** to be one, same word, same glyph, pen always in the owner's hand.
- **"Togglable UI based on role AND abilities AND traits"** → one resolver: **abilities gate (the floor, hide-don't-disable); traits flavor (reorder/spotlight, structurally unable to subtract).** Every surface shows you what's yours and never shames you for what isn't.
- **"How they work, work style, communication style"** → the Way-of-Working chips, self-authored, that quietly bend the meeting assistant / schedule / pings to honor how you actually work.
- **"Minimal data, everything on the device, each their own book"** → self-authored identity (the cover) over a chronological life assembled live from local Drift (the contents), additive, with no punitive column anywhere, and a checkable contract that makes the privacy the *reason the book is a gift.*

---

**Save as:** `docs/IDENTITY_SYSTEM.md`.

**Relevant files (all absolute):**
- `/Users/jardinefaner/differentworld/lib/core/capabilities/capability_keys.dart` — add `CoreCaps.archetype` + `archetypeSecondary` + `Archetypes` closed catalog (no migration)
- `/Users/jardinefaner/differentworld/lib/core/capabilities/capabilities.dart` — `getString` / `getStringList` / `setting` already support the keys
- `/Users/jardinefaner/differentworld/lib/core/viewer/viewer.dart` — add `archetype` / `archetypeCard` getters (mirror `specialty` at line 142); impersonation override at line 255
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/roles.dart` — 23 `RoleCard`s; `builds` is the trait the archetype gathers (the animal→archetype bridge)
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/role_cards_screen.dart` — `_RoleCardFace` is the kid ID card, 80% built
- `/Users/jardinefaner/differentworld/lib/features/toolkit/toolkit_screen.dart` — `ToolkitToolDetailView` (the template to extract) + the feed/master-detail renderer (the one-template surface)
- `/Users/jardinefaner/differentworld/lib/features/toolkit/toolkit_catalog.dart` — the lives-in-Dart rationale for the affordance catalog
- `/Users/jardinefaner/differentworld/lib/features/settings/member_detail_screen.dart` — the ID-card edit home (specialty-picker pattern; imports `CapSwitch`)
- `/Users/jardinefaner/differentworld/lib/features/settings/roles_screen.dart` — the read-only "permissions as audit" contrast to the card's "powers held"
- `/Users/jardinefaner/differentworld/lib/features/today/widgets/quick_actions.dart` — first resolver conversion (its "hide don't disable" header is §4's thesis)
- `/Users/jardinefaner/differentworld/lib/features/omnibox/omnibox_catalog.dart` — ~15 inline `if (viewer.canX)` → one resolver read
- `/Users/jardinefaner/differentworld/lib/features/entries/entries_providers.dart` — `EntryActions` (add `setInBook`, RMW on `details`); `EntryKind`
- `/Users/jardinefaner/differentworld/lib/features/family/family_today_screen.dart` — `_PhotoOfTheMomentPeek` is one book-page; the book generalizes it
- `/Users/jardinefaner/differentworld/lib/features/family/family_providers.dart` — guardian-side `familyEntriesForSubjectProvider` / `familyAttachmentsForEntityProvider`
- `/Users/jardinefaner/differentworld/lib/features/photos/attachments_providers.dart` — `attachmentsForEntityProvider`, `AttachmentsX.thumbUrls`
- `/Users/jardinefaner/differentworld/lib/features/exports/exports_providers.dart` — the opt-in/previewable/revocable share pipeline the showcase must mirror
- `/Users/jardinefaner/differentworld/lib/core/db/app_database.dart` — `Entries` (`details` JSON = the `inBook` home; **no `score` column** = the contract), `Attachments`, `Exports` (the showcase's shape)
- `/Users/jardinefaner/differentworld/lib/core/capabilities/certifications.dart` — the "no fail-state, the missing column is the guarantee" posture to copy verbatim
- `/Users/jardinefaner/differentworld/lib/shared/widgets/inline_editable_text.dart` — formless authoring of the Way-of-Working fields
- `/Users/jardinefaner/differentworld/docs/ROLES_SMART_PRACTICE.md` — §3's non-punitive ledger + the Way-of-Working design; this brief is its identity half
- **New:** `/Users/jardinefaner/differentworld/docs/THE_BOOK_CONTRACT.md` — the five-clause, in-product, code-enforced promise
