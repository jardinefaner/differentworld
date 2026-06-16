# Card games — the picture-deck pipeline

Build plan for turning a sheet of labeled items (docs: the image slicer) into a
**deck of picture cards** that powers many kid-facing games. The thesis, proven
by the survey of the existing framework:

> **One `picture` content kind + one round-generator → every game is a thin
> `GameDefinition`.** You don't build 12 games; you build the deck + the
> round-gen once, then each game is a small cast surface that reads the deck.

This rides entirely on systems that already exist — the **content bank**
(`content_items` + `ContentSource`), the **games framework**
(`GameDefinition` + `liveGames` registry), and the **present/control cast
spine** (`LiveSession` + `GameController`). Nothing new at the engine layer.

---

## The least-cost pipeline (the whole point)

```
Author (once, off-device)        Store              Index                 Play
─────────────────────────        ─────              ─────                 ────
sheet → slice (deterministic) →  assets/ (bundled)  picture content_items round-gen → games
        + manifest.json          or Supabase Storage (manifest ∪ banked)  (cast surfaces)
```

Cost discipline, stage by stage:

- **Slice ONCE, off-device.** The splitter is deterministic — run it at
  author/build time, never per-device. No Dart slicer needed for curated decks
  (that's only for teacher-dropped sheets — phase 2). **No AI in the path** —
  AI is optional and only at the *source* (generating a sheet to slice).
- **Bundle the starter deck** (≈1–2 MB / 40-card deck, each PNG 10–30 KB):
  `$0` backend, offline, instant. Move to Storage only for scale / teacher
  decks (the binary-media rule already covers it — row carries a path, bytes
  live in Storage, PowerSync ships only the string).
- **Tag once → generate infinite rounds.** A card's metadata (label /
  category / first-letter / world) is the leverage: the round-generator
  composes every game's round from it. No hand-authored levels, `$0` per round.

---

## 1. The card — a `picture` content kind

A picture card is **one shape, read by every card game** (unlike `this_or_that`
which bakes `{a,b}` pairs — we generate those on the fly instead).

New constant in `ContentKind` (`lib/features/activity_runtime/content_bank.dart`):

```dart
static const picture = 'picture';
```

`content_items.payload` (jsonb) for a `picture` row:

```jsonc
{
  "id":       "violin",                       // stable slug
  "label":    "violin",                       // the word
  "image":    "assets/card_games/everyday/violin.png",  // bundled asset OR storage path
  "category": "instrument",                   // for sorting / odd-one-out / distractors
  "letter":   "v",                            // derived from label[0] — phonics
  "deck":     "everyday"                      // which pack
}
```

`fingerprint` = `picture:<deck>:<id>` (dedupe). `source` = `curated` for
bundled, `crowd`/`local` for teacher-made. `space_id` = null for the global
curated deck. **No schema migration** — `content_items` already has every
column; this is just a new `kind` + payload shape.

### The deck provider (manifest ∪ banked)

Mirror the existing `bankedContentProvider` pattern (curated seeds ∪ synced
rows), but source the curated seeds from **bundled manifests** instead of an
inline list (decks are big):

```
pictureDeckProvider  (Provider<List<PictureCard>>)
  = bundled manifests (rootBundle → assets/card_games/*/manifest.json)
  ∪ banked content_items rows where kind == 'picture'
```

`PictureCard` is a tiny model (`id, label, image, category, letter, deck`).
Bundled cards are offline-first by construction; banked cards sync like any
other `content_items` row. A `ContentSource` over `kind:'picture'` lets game
`initialState(content)` call `content.take(ContentKind.picture, n)` unchanged.

---

## 2. The manifest format

One per deck, bundled next to its images, declared in `pubspec.yaml` assets:

```
assets/card_games/everyday/
  manifest.json
  violin.png  banana.png  telescope.png  …
```

```jsonc
// assets/card_games/everyday/manifest.json
{
  "deck": "everyday",
  "title": "Everyday objects",
  "version": 1,
  "cards": [
    { "id": "violin",    "label": "violin",    "category": "instrument", "image": "violin.png" },
    { "id": "banana",    "label": "banana",    "category": "food",       "image": "banana.png" },
    { "id": "telescope", "label": "telescope", "category": "tools",      "image": "telescope.png" }
    // …
  ]
}
```

`letter` is derived (`label[0]`), `image` is resolved to the full asset path at
load (`assets/card_games/<deck>/<image>`). The slicer emits this manifest
directly — naming + categories come from the sheet's labels, so authoring a
deck is: **slice → done.**

---

## 3. The round-generator API

Shared helpers (`lib/features/games/cards/card_rounds.dart`) that turn a
`List<PictureCard>` into a game's **wire-state** round. Each game's
`initialState` calls one. They must embed everything the round needs (card
`image` path + `label`) **inside the state** — the cast constraint below.

```dart
// pick a hidden card (Grid Reveal, Name It)
({String image, String label}) hiddenCard(List<PictureCard> deck, int seed);

// N this-or-that pairs (Image-or-That)
List<({Card a, Card b})> pairs(List<PictureCard> deck, int n);

// 3 same-category + 1 different (Odd One Out)
({List<Card> options, int answer}) oddOneOut(List<PictureCard> deck);

// shuffled pairs for matching (Memory)  /  picture↔word pairs
List<Card> memory(List<PictureCard> deck, int pairs, {bool words = false});

// a set with one removed (What's Missing)
({List<Card> shown, Card missing}) whatsMissing(List<PictureCard> deck, int n);

// group by first letter (Beat-the-Letter / phonics)
Map<String, List<Card>> byLetter(List<PictureCard> deck);

// category buckets (Sort It)
Map<String, List<Card>> byCategory(List<PictureCard> deck);

// a board + a call order (Bingo)
({List<Card> board, List<Card> calls}) bingo(List<PictureCard> deck, int side);

// N random cards for a prompt (Three-Card Story, Act It Out)
List<Card> draw(List<PictureCard> deck, int n);
```

Seeded RNG (pass an int) so a round is reproducible across the present +
control devices from the same wire-state. The generator is a **pure library**,
not an engine — it plugs into each game's `initialState`; the games stay pure
`GameDefinition`s and reuse the existing `reduce` / `buildStage` / cast.

### The cast constraint (load-bearing)

Wire-state is **self-describing**: the controller renders from the broadcast
with no content fetch. So the round embeds the **image PATH**, and both
devices resolve it:
- **bundled deck** → both devices have the asset → `Image.asset(path)`. ✅ the
  cheap default.
- **Storage deck** → embed the signed/URL → both fetch via
  `cached_network_image` (already transitive). Same wire-state, different
  resolver.

Never embed bytes in the state; embed the path.

---

## 4. Build order — foundation, then games rain down

**Wave 1 — the foundation (this is the only "engine" work).**
- `ContentKind.picture` + `PictureCard` model.
- Slice the sheets we have → `assets/card_games/everyday/` (40) +
  `assets/card_games/starter/` (20) + manifests; declare in `pubspec.yaml`.
- `pictureDeckProvider` (manifest ∪ banked `content_items`).
- `card_rounds.dart` round-generator helpers + unit tests (pure, easy to test).
- A shared `CardStage`/`CardTile` widget (image + optional label, themed).

**Wave 2 — pour the deck into SHIPPED games (near-zero new code).**
- **Reveal the Picture / Grid Reveal**: swap its bundled-emoji source for
  `hiddenCard(deck)` → render `Image.asset` behind the grid. Drop-in.
- **This-or-That → Image-or-That**: `pairs(deck, 8)` → stage renders two card
  images. A sibling game or a payload extension.
- **Charades → Act It Out**: feed `draw(deck, 1)` to the existing secret-role
  game (it already has the actor-only screen).

**Wave 3 — new card games (each = one `GameDefinition` + a deck-seeding
screen).** Each reuses an existing `GameIntent`:
- **Name It** ✅ — `draw`; `reveal` shows the word (`i/n/d/r`). Pure Reveal.
  Routes `/present/name-it` + `/live/name-it`.
- **Odd One Out** ✅ — `oddOneOut`; `reveal` rings the stranger, the other
  three dim (`i/n/d/r`). Routes `/present/odd-one-out` + `/live/odd-one-out`.
  Coral vibe `0xFFFF7043`.
- **What's Missing?** ✅ — `draw` + a marked card; three beats per round
  (study → quiz → reveal) so it overrides `buildControls`. Routes
  `/present/whats-missing` + `/live/whats-missing`. Pink vibe `0xFFEC407A`.
- **Memory / Match** ✅ — `pick` two to flip; a match locks, a miss clears on
  the next tap (host-paced, no timer). Big board = `buildStage` (casts to the
  room), compact mirror = `buildControls` (the teacher's remote). Routes
  `/present/memory-match` + `/live/memory-match`. Indigo vibe `0xFF5C6BC0`.
- **Sort It** — `byCategory`; `pick` a bucket.
- **Bingo** — `bingo`; `tally` / `pick` marks.
- **Three-Card Story** — `draw(3)`; `reveal`/`next` (the *Three* primitive).

> **Registry + cast.** All four deck games are `seedsFromContentBank = false`
> (hidden from the cast launcher's content-bank browse loop, since they need a
> deck seed) BUT they ARE registered in `liveGames` — like `WorldCast` /
> `Conductor` — so `gameById` resolves them. That's what lets the cast
> receiver, the join-by-code path, and the live-session banner render them
> from the deck seed that rides the wire-state. (Registering a
> `seedsFromContentBank=false` game is the documented pattern; Name It
> originally missed it — fixed alongside the wave-3 trio + Memory.)

Every wave-3 game is a single file + one registry line. No engine, no cast
wiring, no new schema.

**Phase 2 (deferred) — teacher-made decks.** The in-app **Dart slicer** port
(connected-components on the `image` package, already a dep) + a "card maker"
screen: drop a sheet → set rows×cols (or auto) → preview → save as banked
`picture` rows + upload PNGs to Storage. Reuses this whole pipeline; only the
*author* stage moves on-device.

---

## Discovery surfaces (the 4-places rule)

Each new game needs: a `liveGames` registry entry, a Present-hub card
(`present_hub_screen.dart`), a route (the `/activity/<id>` + `/live/<id>`
pattern), and an omnibox entry. A "Card games" deck-picker screen can group
them so the hub doesn't sprawl. Claim them in `docs/FEATURES.md` per the
feature-mapper contract.

## Acceptance bar

- Round-generator is **pure + unit-tested** (deck in → round out; seeded).
- Each game renders from wire-state alone (no content fetch on the control
  device) — the cast invariant.
- Bundled decks work **fully offline**; no network in the kid-facing path.
- Pre-readers: every game is **picture-first with voiceover**; no typing.
