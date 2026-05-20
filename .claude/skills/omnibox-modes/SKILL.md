---
name: omnibox-modes
description: The bottom omnibox composer has three modes (search / capture / slash) plus voice dictation via Deepgram. Detection is automatic from query content. Triggered when adding entries to the catalog, a slash command, or anything affecting the composer.
---

# Omnibox modes — search / capture / slash + voice

The bottom bar in AppShell is the app's spine. It morphs visually +
behaviorally between three modes based on what the user has typed.
Hitting return in each mode does something different.

## Search mode (default)

- **Trigger**: anything that isn't a `/` prefix or a long enough
  no-match query
- **Bar visual**: surface tint, magnifier glyph, hint
  "Search anything — pages, actions, kids…"
- **Panel**:
  - Idle (no text): Recent captures strip + Pinned + Recent +
    "For you now" + categories
  - Typed: scored matches from `omniboxCatalogProvider`
- **Enter behavior**: open the top-scored result

## Capture mode

- **Trigger**: query is ≥ 5 chars (with a space) OR ≥ 10 chars, AND
  no catalog entry's `score(query) >= 200` (i.e. no strong match)
- **Bar visual**: primaryContainer tint, bolt glyph, hint
  "Save a quick note — press return"
- **Panel**: hero "Save as a capture" card echoing the typed text +
  primary "Save" button. Catalog results render underneath so the
  user can pivot back.
- **Enter behavior**: fire `captureActionsProvider.start(body: text)`,
  toast.

## Slash mode

- **Trigger**: query starts with `/`
- **Bar visual**: tertiaryContainer tint, chevron glyph, hint
  "Slash command — type /today, /log, /attendance…"
- **Panel**: prefix-matched command list from `allSlashCommands`
- **Enter behavior**: exec the unambiguous match's `exec(ctx, ref,
  args)` callback

## The catalog

`lib/features/omnibox/omnibox_catalog.dart` builds the search-mode
list. When you add a screen or surface, add an `OmniboxEntry`:

```dart
OmniboxEntry(
  id: 'page.myscreen',
  label: 'My screen',
  subtitle: 'one-line description',
  category: OmniboxCategory.page,  // page | action | person | classroom | place | activity | vehicle | setting
  icon: Icons.thing_outlined,
  keywords: const ['alt name', 'related concept'],  // for fuzzy search
  // capability gate (optional)
  // contextTags: const ['morning', 'arrival'],  // surfaces in "For you now"
  onSelect: (ctx, ref) => unawaited(ctx.push('/myscreen')),
),
```

Dynamic entries (per-kid, per-classroom, per-vehicle, etc.) are
generated inline in the provider. Add a new dynamic section when
you have a list of N entities each worth their own entry.

## Slash commands

`lib/features/omnibox/slash_commands.dart` holds the canonical
command set. Adding a new one:

```dart
SlashCommand(
  name: 'mycmd',
  label: '/mycmd {arg}',
  hint: 'Description of what it does',
  icon: Icons.bolt_outlined,
  aliases: const ['shortform'],
  exec: (ctx, ref, args) {
    // args is everything after the command name, or null
    if (args == null) {
      // open the index / picker
      unawaited(ctx.push('/mycmd'));
      return;
    }
    // resolve args (e.g. fuzzy-match a name to a Drift row) +
    // navigate via context.push
  },
),
```

Keep the set tight (~10 commands max). Power users will memorize
them; churn is expensive. Adding a command should add a real
capability not already covered by typed search.

## Voice (Deepgram)

`onMicTap` in the bar toggles a Deepgram WebSocket session via
`deepgramVoiceProvider`. The running transcript is APPENDED to
whatever the user already typed (preserves their prefix). Mic icon
turns red while listening.

- **Setup**: requires `DEEPGRAM_API_KEY` in `.env`. Without it the
  mic surfaces a "voice not configured" snackbar.
- **Permission**: requested at first tap via `permission_handler`.
- **Privacy**: audio is streamed, not stored. We don't proxy
  through our own backend.
- **Transcript handling**: interim transcripts overwrite the
  composer text in real time; final segments are committed.

When extending voice — e.g. specific transcription targets (a kid
detail screen wanting voice-into-the-note-field) — open a fresh
`DeepgramVoiceController.start()` rather than reusing the global.

## Detection function

`detectMode(query: query, catalog: catalog)` in
`lib/features/omnibox/omnibox_mode.dart` does the routing. Cheap —
one pass through the catalog. Recomputed on every keystroke inside
AppShell.build.

## Don't

- Don't render the bottom bar yourself — it's in AppShell.
- Don't bypass the mode detection. If you have a feature that needs
  the composer in a specific mode (e.g. always slash for some power
  surface), open the omnibox overlay instead via `showOmnibox()`.
- Don't add an OmniboxEntry that does heavy work in `onSelect` —
  collapse the panel + `addPostFrameCallback` + navigate, then let
  the destination do the work.
- Don't write to the composer's text from outside the bar (e.g.
  from a screen). The voice flow uses an internal hook; copy that
  pattern if you need something similar.
