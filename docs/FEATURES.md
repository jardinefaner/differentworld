# Feature registry

The canonical map of every feature in the app. Folder-grained: one
section per immediate subdirectory of `lib/features/`. Each section has
a fixed shape; if you find yourself wanting a new field, propose it to
the user — don't invent it.

**Maintained by**: the `feature-mapper` agent. Re-runs whenever files
under `lib/features/`, `lib/app/router.dart`,
`lib/features/omnibox/omnibox_results.dart`,
`lib/features/omnibox/omnibox_catalog.dart`,
`lib/shared/widgets/main_drawer.dart`,
`lib/features/settings/settings_screen.dart`, or
`supabase/migrations/` change.

**Queryable**:
- `Agent blast-radius` — "if I touch X, what else moves?"
- `Agent persona-audit` — "is each persona served?"

**Schema** (any "Discovery surface" claim is verified against the
code; mismatches show up as drift warnings):

```
## <FeatureName>
**Path**: `lib/features/<dir>/`
**Purpose**: One sentence — what the user gets, not how it works.
**Personas served**: Maya | Jordan | Lauren | Devon | Coach Sam | Helen | Marcus | Brianna | Pat | Ava | All staff | All guardians
**Discovery surfaces**:
- Routes: <go_router paths>
- Omnibox: <yes/no with labels + keyword aliases>
- Slash: <command names or "none">
- Drawer: <yes/no — label + position>
- Settings: <yes/no — row label + _SettingsGroup>
**Capabilities**: <required caps, or "None — open to all signed-in members">
**Data**: <synced tables touched — names only, see docs/SCHEMA.md>
**Surfaces**:
- *<surface name>* — `<file>`. One line of what + what action.
**Depends on**: <other features it imports>
**Consumed by**: <other features that import this>
**Last verified**: <ISO date>
```

---

## Top-level orientation

The drawer (mobile) and desktop nav rail both render from the single
canonical list in `lib/shared/widgets/nav_destinations.dart`
(`buildNavDestinations(viewer)`). Top-level destinations in canonical
order: **Today**, **Schedule**, **Observations** (gated `canObserve`),
**Action Words** (gated `canObserve`), **Program** (gated `canObserve`),
**Captures**, **Tasks**, **Tools**, **Present**, **Brain Breaks**,
**Missions**, **Brainstorm Board**, **Insights**, **Surveys**,
**Vehicles** (gated `canDrive || canManageSpace`), **Reflect**,
**Settings**. Everything narrower is reachable via the
omnibox (`/search`) or slash commands. Settings is the library / admin
surface — preferences + roster + fleet, not primary workflows.

---

## Action Words
**Path**: `lib/features/action_words/`
**Purpose**: The world-reveal loop (docs/ACTION_WORDS.md, from the developer brief) — kids pick 3 of 12 action words each morning; the combo reveals an animal/element/archetype **world**; over time a title forms from their most-practiced verbs. The app touches the kid ~5 min/day; the room is the product.
**Personas served**: All staff (Conductor — primary), Ava (Kid Explorer — kid-facing pick screen + growth arc), Parent (Witness — V1 is the generated text / growth arc sent home).
**Discovery surfaces**:
- Routes: `/action-words` (the morning pick roster), `/action-words/send` (Send home — end-of-day copy-to-clipboard parent messages), `/action-words/worlds` (Our worlds — the class’s invented-world book), `/action-words/different-worlds` (Different Worlds — gallery of the program’s six themed worlds: Books, Movies, Songs, Dreams, Space, Time; each tappable to a glass sheet with sensory “Become it” beats + five world-building facets), `/action-words/activities` (Activity matcher — filter activities by verb), `/action-words/pick/:subjectId` (ActionWordsKidScreen — the kid-facing morning pick; device handed to ONE child; kid mode locked + `kidModeLockedRouteProvider` PIN-gated staff exit via 5-tap corner; saves via `ActionWordsActions.setPicks`; no omnibox entry — launched from the “Let {name} pick” `IconButton` on each `_KidRow`), `/action-words/job/:subjectId` (KidJobScreen — **Role-4: the kid verb-job reshapes kid-mode**; shows ONE child the verb-jobs their picks gave them as big “You are The Mover!” cards (jobTitle + level-1 mission from `verb_roles.json`) with a kid-tappable “I did it!” toggle → `ActionWordsActions.toggleDone`; same kid-mode lockdown + `kidModeLockedRouteProvider` PIN-gated 5-tap staff exit as the pick screen; no omnibox entry — launched from the “Hand {name} their jobs” `IconButton` on each `_KidRow` when the child has picks), `/action-words/:subjectId` (the collection — worlds grid + verb bars + emerging title), `/this-week` (This Week hub — the live curriculum hub; shows the current world, “Cast to the room” + “Worksheets” + “Activities” actions; director manages journey start date from here), `/present-world/:id` (WorldPresentScreen — fullscreen immersive world slideshow, “Cast to the room”; reached from the This Week hub + the gallery world sheet; no omnibox entry — it is a per-world contextual action), `/book/:subjectId` (BookScreen — a child’s 10-week journey grouped by curriculum week; reached via a “Book” IconButton on the kid story screen; no omnibox entry — per-subject contextual), `/play-today` (DayRunScreen — immersive run-of-show assembled from the live world; the whole day on rails, teacher just advances; reached via “Play today” hero button on This Week; no back-stack destination), `/arc` (ActivityArcScreen — the teleprompter for teaching; presents ANY activity through its play→name→bridge→question arc as a castable full-screen sequence; typed activity passed via go_router `extra` from `/lens`, empty runs the generic arc; wears the live world’s colour when one is active; no back-stack destination), `/growth/:subjectId` (GrowthArcScreen — the child’s whole story so far cast on the shared present spine; auto-compiled from their `ActionWordsCollection` into a `buildGrowthArc` beat list rendered by `BeatPresenter` — words lived most, worlds collected, emerging title; no omnibox entry — launched from the “Play their story” `FilledButton` in `_Links` on `CharacterSheetScreen`), `/program` (ProgramHubScreen — the season hub; the whole 10-week program on one screen: hero (active world + “Day N of 50 · Week W of 10” + 50-day progress bar), today’s authored day (tap → showJourneyDaySheet), the two layers of skin (world-you-live-in + week-focus verb chips), 10-world journey strip with “NOW” marker, cast row (Play today / The journey / This week), each child’s growing arc (tap → /growth/:id); empty state for directors when journey not started; no back-stack destination), `/run-day` (BlockRunScreen — the live daily schedule as an ordered, advanceable, castable run-of-show deck; scopes to the viewer’s cohort with a cohort-switcher in the actions pill when several are assigned; reads `schedule_blocks` via `scheduleDayForGroupProvider(today)` + maps via `buildBlockRun`; renders via `DeckOverview` + `BeatPresenter`; a block carrying a `curriculum_session_slug` drills into its `SessionRunScreen`), `/run-day/present` (nested immersive `BeatPresenter` route — mirrors `/play-today/present`; receives a `DeckPresentArgs` via go_router `extra`; falls back to `BlockRunScreen` if args are absent), `/routines` (RoutineScriptEditorScreen — edit how the everyday routine blocks run: pick a routine (arrival / meals / rest / pickup / transition / welcome / free-play), drag-reorder its steps + edit its tools, Save; per-space overrides on `spaces.capabilities.routine_scripts`, shared with the team; the day-run reads them as the highest-priority `scriptOverride`. Reached from Settings → Resources and omnibox `page.routines`)
- Omnibox: `page.action-words` — “Action Words” (keywords: verbs, words, worlds, pick, reveal, collection, animal; morning contextTag). `page.this-week` — “This week’s world” (keywords: this week, this week’s world, current world, live world, journey, week, cast, worksheets). `page.different-worlds` — “Different Worlds” (keywords: books, movies, songs, dreams, space, time, different world, room). `page.play-today` — “Play today” (keywords: play today, play the day, run of show, run the day, present the day, slideshow, sequence, today’s plan, cast today). `page.arc` — “Present an activity” (keywords: present, present an activity, teleprompter, prompt, on rails, story arc, play name bridge question, cast activity, walk me through, teach the arc). `page.program` — “The program” (keywords: program, season, the whole program, season hub, where are we, 10 week, 50 day, journey overview, dashboard, overview). `page.run-day` — “Run the day” (keywords: run, run the day, run of show, present the day, slides, deck, arc, schedule run; contextTags: morning, afternoon) → `/run-day`. `page.routines` — “Routine scripts” (keywords: routine, routines, routine scripts, arrival, pickup, transition, edit steps, how the day runs) → `/routines`, gated `canManageSchedule`. No omnibox entries for `/send`, `/worlds`, `/activities`, `/present-world/:id`, `/action-words/pick/:subjectId`, `/action-words/job/:subjectId`, `/growth/:subjectId`, or `/run-day/present` — reached via chrome action buttons, in-context links, or the nested present route.
- Slash: none
- Drawer/Rail: yes — "Action Words" nav destination, gated `onlyFor: canObserve`; "Program" nav destination in "More" group, gated `onlyFor: canObserve`; "Run the day" nav destination in "Activities" group, gated `onlyFor: canObserve`, route `/run-day`
- Settings: Resources group → "Routine scripts" → `/routines` (the routine-script editor; the tile + the omnibox entry + the screen are all gated `canManageSchedule` — editing routines is a team-wide write). No opt-in cap gates the Action Words loop itself.
**Capabilities**: Pick / run: `can_observe` (the daily-staff gate). Present-surface timer tuning: reads `SpaceCaps.timerPresets` (`timer_presets`) via `houseTimerPresetsProvider` and `SpaceCaps.suggestPlayMinutes` (`suggest_play_minutes`) via `houseSuggestPlayMinutesProvider` (both on `spaces.capabilities`); these are program-policy caps written by the director in program settings; no separate member cap gates reading them.
**Data**: Reuses [entries](SCHEMA.md#entries) `kind='action_words'` — one row per (subject, date); `details` = `{verb_picks:[3], done:[…], note, word_of_day, world_name?}`. The revealed world is DERIVED from `verb_picks` (deterministic lookup), not stored. NO new table. Also writes [entries](SCHEMA.md#entries) `kind='world_rule'` — one row per room-added rule; `body` = the rule text; `details` = `{world_id}`. Written via `EntryActions.addWorldRule`; read via `addedWorldRulesProvider(worldId)` (filters `kind=world_rule` in space, matches `details.world_id`). Reads [spaces](SCHEMA.md#spaces) capabilities via `SpaceCaps.programStartDate` (`program_start_date` key) — the journey start date that drives `currentCurriculumWeekProvider` + `currentWorldProvider` + `currentProgramDayProvider`. No new table; the cap is written by `WorldScheduleActions.setStartDate`. Writes [activities](SCHEMA.md#activities) — `CurriculumImporter.importActivities` seeds ~75 curriculum activities (verb-tagged via `action_verbs` cap, idempotent via `curriculum_key` cap marker in `activities.capabilities` JSONB). Reads [schedule_blocks](SCHEMA.md#schedule_blocks) — `BlockRunScreen` reads `scheduleDayForGroupProvider(today)` (from the Schedule feature) to build the day's run-of-show via `buildBlockRun`; READ-ONLY from this feature's perspective (no writes to `schedule_blocks` here). Reads + writes [spaces](SCHEMA.md#spaces) capabilities via `SpaceCaps.routineScripts` (`routine_scripts` key) — per-space overrides of the everyday-routine run-scripts (a JSON object keyed by `RoutineKind.name` → `{steps,tools}`), authored in `RoutineScriptEditorScreen` through the serialized `RoutineScriptActions` read-modify-write queue and read back into the day-run as `scriptOverride`. No new table. Bundled content: `assets/curriculum/world_blocks.json` — the 50-day journey as ten weekly worlds (aligned 1:1 with `ten_worlds.json`); loaded via `rootBundle` (NOT a synced Drift/Supabase table, no SCHEMA.md entry).
**Surfaces**:
- `verbs.dart` — the 12 permanent verbs (id/emoji/label).
- `worlds.dart` — `World` + `matchWorld(picks)` (exact / closest ≥2 / fresh), the ~40-world lookup (8 canonical + 7 starter extras; user owns the rest). Also exports `InventedWorld` and `kNamedWorlds`.
- `themed_worlds.dart` — `ThemedWorld` catalog + `themedWorldById()`. Const starter set of 6 weekly themed worlds (all_about_me, wildlife, travel, water_world, icons, space); each carries emoji/name/room/blurb + a list of `SenseBeat` (sense + prompt) for the "Become it" invitation.
- `action_words_providers.dart` — `ActionWordsDay` (typed per-day), `ActionWordsCollection` (lifetime worlds + practiced-verb totals + emerging title), `ActionWordsActions` (setPicks/toggleDone/setNote/setWordOfDay/setWorldName — optimistic, find-or-create per day in a txn). `inventedWorldsProvider` (derived from the collection: worlds where `world_name` was user-authored).
- `action_words_screen.dart` — the pick roster + the per-kid pick sheet (12-verb grid → live world preview → save). Top chrome carries two icon buttons: "Our worlds" → `/action-words/worlds` and "Send home" → `/action-words/send`. Embeds `_ThisWeekBanner` at the top of the child list — a tappable banner linking to the themed worlds gallery; tapping pushes `/action-words/different-worlds`.
- `themed_world_screen.dart` (`ThemedWorldScreen`) — `/action-words/different-worlds`: gallery of the program's six themed worlds (Books, Movies, Songs, Dreams, Space, Time); each world card is tappable to a `showGlassSheet` sheet showing its sensory "Become it" SenseBeat rows + the five world-building facets (People / Culture / Map / Tools / Dreams).
- `widgets/verb_grid.dart` (the selectable 12-grid, max-3), `widgets/world_badge.dart` (the reveal badge — emoji/name/title/verbs, handles the fresh case).
- `reveal_overlay.dart` — the closing reveal: a fullscreen dark "moment" (root-navigator route, breathing gold glow) "Maya was 🐬 Dolphin today", with the fresh-world naming flow. Reachable from each roster row's ✨ button.
- `collection_screen.dart` — `/action-words/:subjectId`: the worlds grid (collected = bright + ×count, uncollected = grey silhouette), most-practiced verb bars, and the emerging "Becoming The Owl Who Listens" title. Reached by long-pressing a roster row (+ deep-linkable).
- `parent_message.dart` — `buildParentMessage(childName:, day:)` pure function. Generates the end-of-day text a teacher pastes into their messaging app.
- `send_screen.dart` — `/action-words/send`: lists every child with picks today; each card shows the auto-generated parent message + a Copy button (writes to clipboard + snackbar). Reached from the "Send home" icon on the Action Words screen.
- `world_book_screen.dart` — `/action-words/worlds`: the class's invented-world catalog (worlds named by the teacher/kids during a fresh-world reveal); each entry shows the world name + the verb trio that generated it + the day count. Reached from the "Our worlds" icon on the Action Words screen.
- `activity_match_screen.dart` — `/action-words/activities`: activity matcher — filter the activity library by verb. Reached from the "Activities for this world" button on `ThemedWorldScreen` (passes the current world's sense verbs as `?verbs=`).
- `world_blocks.dart` — `WorldBlock` + `JourneyDay` models; `worldBlocksProvider` (FutureProvider loading `assets/curriculum/world_blocks.json` from the bundle); pure lookups `blockForDay` / `journeyDayForDay` / `wallQuestionForDay` / `programDayFor`; derived providers `currentProgramDayProvider` (today's 1–50 day number, null when journey inactive), `currentBlockProvider` (the active weekly WorldBlock), `todaysJourneyDayProvider` (the authored JourneyDay for today), `todaysWallQuestionProvider` (the authored wall question for today). All providers depend on `programStartDateProvider` from `world_schedule.dart`.
- `journey_day_sheet.dart` — `showJourneyDaySheet(context, day:, journeyDay:, block:, wallQuestion:, isToday:)` shared glass sheet (day number + block name header; focus text; "On the wall" question card; block-boundary callout — "Set up the room today" (`block.arrival`) on the first day of a block, "Hand off to the next world" (`block.transition`) on the last; room/soundtrack/key-moment section; "Run today" FilledButton when `isToday: true` → pushes `/play-today`). Also exports `JourneyDayRow` — a tappable list tile (day number + title; today badged; room-setup icon on first day, flip icon on last day) used by `_FortnightSection` on `/this-week`.
- `curriculum.dart` — `CurriculumWorld` model + `curriculumWorldsProvider` (loads `assets/curriculum/ten_worlds.json`; the 10-world program catalog each carrying week, name, emoji, color, question, featuredVerbs, activities).
- `world_schedule.dart` — `currentCurriculumWeekProvider` (derives current week from `spaces.capabilities.program_start_date`), `currentWorldProvider` (maps week → `CurriculumWorld`), `WorldScheduleActions` (setStartDate / jumpToWeek / clear — write the `program_start_date` cap on the spaces row).
- `this_week_screen.dart` — `ThisWeekScreen` at `/this-week`: the live curriculum hub. Shows the active world (hero card: week number, name, question); primary actions: "Play today" → `/play-today`; "Cast to the room" → `showCastToRoom`; "More" overflow sheet → Activities / Make one / Worksheets / The Wall / Time capsules / Explore all worlds. This week's verbs as chips. **The rules of this world** — the three authored `kWorldRules` entries PLUS any room-added rules from `addedWorldRulesProvider(world.id)`; an "Add a rule" `TextButton` opens `_AddRuleSheet` (one-field glass sheet; writes via `entryActionsProvider.addWorldRule(text:, worldId:)` — an `EntryKind.worldRule` row). Authored rules marked `§`; room-added rules marked `+` with an italic "your room" tag. Embeds `_FortnightSection` — the block's five authored days (`JourneyDayRow` list, today badged; tapping each opens `showJourneyDaySheet`). Director "Manage journey" action opens a glass sheet to set/jump/clear the journey start date.
- `world_present_screen.dart` — `WorldPresentScreen` at `/present-world/:id`: fullscreen immersive slideshow for the current world (Cast to the room). Enters `SystemUiMode.immersiveSticky`; restores `edgeToEdge` on dispose. No omnibox entry — reached from the This Week hub and from individual world sheets in the gallery.
- `worksheet_pdf.dart` — `printWorldWorksheets(world)` / `printAllWorksheets(worlds)`. Generates printable PDF worksheets for one or all curriculum worlds; dispatches via the OS print sheet. No route — action from the This Week hub + each gallery world sheet app bar.
- *Today card* — `_ThisWeekWorldCard` in `lib/features/today/widgets/today_sections.dart`. Embedded on Today; reads `currentWorldProvider`; shows the live world name + "Start the journey" prompt when no start date is set (director-only CTA). Tapping pushes `/this-week`.
- *Today's focus card* — `_TodaysFocusCard` in `lib/features/today/widgets/today_sections.dart`. Embedded on Today below `_ThisWeekWorldCard`; reads `currentProgramDayProvider`, `todaysJourneyDayProvider`, `currentBlockProvider`, `todaysWallQuestionProvider`; shows "Today · Day N of 50" + the day's title + wall question; renders nothing until the journey is active. Staff-only (`viewer.isDailyLogger`). Tapping opens `showJourneyDaySheet` with `isToday: true` (includes the "Run today" → `/play-today` button).
- *Wall question of the day banner* — `_QuestionOfTheDayBanner` in `lib/features/action_words/wall_screen.dart`. Embedded in `/wall` above the sticky notes; reads `todaysWallQuestionProvider`, `currentProgramDayProvider`, `currentBlockProvider`; renders the day's authored wall question ("TODAY'S QUESTION · DAY N") as the framing prompt staff write big before the room opens; renders nothing when the journey isn't active.
- `book_screen.dart` (`BookScreen`) — `/book/:subjectId`: a child's 10-week journey grouped by curriculum week. Each section shows the week's world header (emoji, name, question), the verbs practiced that week, and `MomentTile` rows for every captured moment. A `_LastPage` summary closes the screen. Reads `entriesForSubjectProvider` + `curriculumWorldsProvider` + `programStartDateProvider`; no new data. Reached via a "Book" `IconButton` on `kid_story_screen.dart`; no omnibox entry.
- `curriculum_import.dart` (`CurriculumImporter`) — no route; in-place action. Reads `curriculumWorldsProvider`, iterates `w.activities`, inserts into `activitiesDao.create` with `action_verbs` + `curriculum_key` + `curriculum_world` caps. Idempotent (skips rows whose `curriculum_key` is already present). Surfaced as a director-only app-bar action on `activity_match_screen.dart` and as an empty-state CTA on the same screen. `curriculumImporterProvider` is the Riverpod entry point.
- `thinking_games.dart` — `ThinkingGame` model + `thinkingGamesProvider` (FutureProvider loading `assets/curriculum/thinking_games.json`); `systemThinkingGames` (games tied to RPG systems); `systemThinkingGameProvider` (family Provider by system id — used by the character sheet to resolve "the game under this system"). `ThinkingGame` gained a `system` field ('' = anytime / world game); 13 system-tied games added to the JSON.
- `thinking_screen.dart` (`ThinkingScreen`) — `/thinking`: the Big Thinking deck. Leads with this week's world game(s), then one game per RPG system ("Under each system"), then the rest of the deck. Each card opens `showThinkingGameSheet`. `page.thinking` omnibox entry → `/thinking`.
- `widgets/thinking_game_sheet.dart` — `showThinkingGameSheet(context, game)`. Glass bottom sheet presenting a game's play/name/bridge/question. Used both by the deck and by `_SystemGameLink` chips on the character sheet.
- `day_run.dart` — `DayBeat`, `DayBeatKind` enum (open/question/verbs/rule/watch/play/name/bridge/ask/activity/**photo**/close). `DayBeatKind.photo` is a keepsake-image beat that carries `imageUrl` (a signed Storage URL) for the growth arc's weave of child work-sample photos through the worlds. `beatGuidance(DayBeat)` — pure function that returns the staff "YOUR MOVE" cue for each beat (shown phone-side only — the conductor's score); reads `DayBeat.guidance` if authored, else returns a template default per kind; empty string for `photo` beats (no staff cue — a moment to sit with). `beatKindShortLabel(DayBeatKind)` — short label for the "Next — {…}" control. `buildDayRun(world, rules, thinking)` assembles the ordered slide sequence. Also exports `buildActivityArc(String activity)` and `buildJourneyTour(worlds)` — both pure functions.
- `widgets/beat_presenter.dart` (`BeatPresenter`) — the single shared immersive present surface. `PageView` of full-screen `DayBeat` slides; enters `SystemUiMode.immersiveSticky` + `castImmersiveProvider` on mount; restores on dispose. Accepts `beats`, `accent`, `emoji`. On `DayBeatKind.photo` slides renders the `imageUrl` full-bleed via `PersonPhotoNetwork`. Staff-side "YOUR MOVE" card — shows `beatGuidance(beat)` in a bottom glass pill on the phone; not cast to the room screen. Backs `DayRunScreen`, `ActivityArcScreen`, and `GrowthArcScreen` — the one correct immersive lifecycle lives here.
- `day_run_screen.dart` (`DayRunScreen`) — `/play-today`: thin `ConsumerWidget` over `BeatPresenter`; assembles the live world's day-run beats and delegates all presentation. Reached via "Play today" hero button on This Week screen. `page.play-today` omnibox entry → `/play-today`.
- `activity_arc_screen.dart` (`ActivityArcScreen`) — `/arc`: the teleprompter for teaching. Takes a typed activity name (via go_router `extra` from `/lens`, empty = generic arc), calls `buildActivityArc`, renders through `BeatPresenter` wearing the live world's colour. Reachable via `page.arc` omnibox entry ("Present an activity") and via the "Present this →" `FilledButton` on `/lens` when the text field is non-empty.
- `verb_voice.dart` (`VerbVoice`) — on-device TTS voiceover for the kid pick screen, using `flutter_tts` (platform speech engine — offline-first, no network). `speakVerb(verb)` speaks "{label}. {lens}." (e.g. "Help. Do it together.") at a slower rate/higher pitch for pre-readers. `say(text)` speaks any arbitrary kid-facing line. Failures are silently swallowed — silent audio degrades experience; it never breaks the flow. Owned per-screen (created in `initState`, `stop()`-ed in `dispose`).
- `action_words_kid_screen.dart` (`ActionWordsKidScreen`) — `/action-words/pick/:subjectId`: kid-facing morning pick. Device is handed to ONE child; they tap 3 of 12 verbs and confirm. Tapping a verb in the grid speaks it via `VerbVoice` (voiceover for pre-readers). Enters kid mode on mount via `kidModeProvider.notifier.enter()` + pins the route with `kidModeLockedRouteProvider`; staff exit is 5 taps in the top-left corner within 800 ms each, opening `showKidModeExitDialog`. On save calls `ActionWordsActions.setPicks` (same path as teacher pick — no new table). Post-save shows a `_Celebration` screen with the three chosen verbs; child shows a grown-up. Launched from the "Let {name} pick" `IconButton` trailing on each `_KidRow` in `ActionWordsScreen`.
- `kid_job_screen.dart` (`KidJobScreen`) — `/action-words/job/:subjectId`: **Role-4 — the kid verb-job reshapes kid-mode.** During-the-day surface handed to ONE child to DO the verb-jobs their morning picks gave them. Reads `actionWordsForDayProvider` (the child's picks) + `verbRolesProvider` (bundled `verb_roles.json`); renders one big card per picked verb — "You are {jobTitle}!" + the level-1 mission — with a kid-sized "I did it!" toggle that writes through `ActionWordsActions.toggleDone` (in-flight guarded so a double-tap stays done). Every child's screen differs because their three verbs differ. Same kid-mode lockdown as `ActionWordsKidScreen` (microtask enter + mounted guard, resume re-engage, `kidModeLockedRouteProvider` pin, `PopScope`, 5-tap staff corner → `showKidModeExitDialog`). No self-navigation out of the lock (the no-picks state is a "show a grown-up" message, not a button). Launched from the "Hand {name} their jobs" `IconButton` on each `_KidRow` when the child has picks.
- `growth_arc.dart` — `GrowthPhoto` typedef (`{url, caption}`). `buildGrowthArc(firstName:, collection:, photos:)` pure builder. Compiles an `ActionWordsCollection` + the child's keepsake photos into an ordered `List<DayBeat>`: opening beat (name + day count), top-4 verb totals, then worlds and photos WOVEN alternately (world beat, photo beat, world beat, photo beat — so the arc plays as a visual story, not a stat sheet), world-count beat, emerging title, closing beat. Photo captions are always a date string (never the observation `body`, which can name other children — privacy-safe for this family-facing surface). Capped at 6 photos. Empty-collection path produces a two-beat "story starts" arc. Deterministic, unit-testable, zero network.
- `growth_arc_screen.dart` (`GrowthArcScreen`) — `/growth/:subjectId`: the child's growth arc cast on the shared present spine (`BeatPresenter`). Reads `actionWordsCollectionProvider(subjectId)` + `subjectByIdProvider(subjectId)` + `growthArcPhotosProvider(subjectId)` (the child's OWN shots via `attachmentsCapturedByProvider` FIRST, then observation attachment photos as backfill, deduped + capped 6, date-captioned for privacy); calls `buildGrowthArc`; delegates all presentation to `BeatPresenter` (accent `0xFF7C4DFF`, emoji ✨). `DayBeatKind.photo` slides render full-bleed via `PersonPhotoNetwork` (signed Storage URLs). Loading state shows a "Gathering the story…" text + Close button on a black scaffold. Launched from the "Play their story" `FilledButton` in `_Links` at the bottom of `CharacterSheetScreen`. Cast to the room at closing ceremony or sent home to family at pickup; no staff-PIN gate (this is a cast surface, not a kid-operated surface).
- `world_blocks.dart` — `SeasonPosition` typedef (`{day, week, block, world?, journeyDay?, wallQuestion?}`) + `seasonPositionProvider` (Provider; the single canonical "where are we" bundle, derived by combining `currentProgramDayProvider` + `currentCurriculumWeekProvider` + `currentBlockProvider` + `currentWorldProvider` + `todaysJourneyDayProvider` + `todaysWallQuestionProvider`; null when the journey is inactive). The canonical entry point for any surface that needs the full season context in one watch.
- `program_hub_screen.dart` (`ProgramHubScreen`) — `/program`: the season hub. Shows the active world hero (emoji, name, "Day N of 50 · Week W of 10", 50-day linear progress bar), today's authored day card (title + wall question snippet, tap → `showJourneyDaySheet` with `isToday: true`), a "two layers of skin" section (world-you-live-in block label + this-week verb chips), a 10-world journey strip (all ten WorldBlocks with a "NOW" marker on the active one), a cast row (Play today → `/play-today`, The journey → `/journey`, This week → `/this-week`), and a children-arcs list (every enrolled subject with collected-worlds count + emerging title, tap → `/growth/:subjectId`). Director empty state offers a "Set up the journey" CTA → `/this-week`. Staff-non-director empty state is read-only until the journey starts. Loading/error states guard against slow bundle parsing on cold launch. Staff + director only; guardians are redirected off `/program`.
- `block_run.dart` — `BlockRunInput` typedef + `buildBlockRunAligned` / `buildBlockRun(List<BlockRunInput>)` pure builder (schedule → ordered `List<DayBeat>` run-of-show deck) + `liveBlockOrder(blocks)` (filter + sort helper exposed for index-alignment) + `blockEnergy` (arc). Also the routine library: `RoutineKind` enum (arrival / meal / rest / pickup / transition / welcome / free-play), `classifyRoutine(kind, title)`, `defaultRoutineScript(kind)`, and `blockRunScript` (now delegates to those, behavior unchanged) + `recipeBeats` / `routineRunBeats` sub-decks. Drift-decoupled; unit-tested in `test/unit/block_run_test.dart` (13 cases) + `test/unit/routine_scripts_test.dart` (9 cases). Consumed by `BlockRunScreen` + the routine editor.
- `block_run_screen.dart` (`BlockRunScreen`) — `/run-day`: the live daily schedule as one ordered, advanceable, castable run-of-show deck. Scopes to the viewer's group (cohort-switcher chip in the actions pill when several are assigned); reads `scheduleDayForGroupProvider(today)` (from Schedule), maps via `buildBlockRun`, renders via `DeckOverview` + `BeatPresenter`. A block carrying a `curriculum_session_slug` is flagged runnable — tapping drills into its `SessionRunScreen` (`/session/run?slug=…`). Each routine block's `scriptOverride` resolves as `customRoutineScripts[routine] ?? worldScriptFor(...)` (director's hand-edit > world flavour > baked-in default). Reachable via omnibox `page.run-day` and the "Run the day" nav destination in the Activities group.
- `block_actions.dart` — the run-of-show slide's "use right now" tray (docs/VISION.md "the slide is a launchpad"): `BeatAction` (icon/label/onTap), `BlockActionKind` enum, pure `blockActionKindsFor(scheduleKind, title, hasSession)` (reuses `classifyRoutine` for per-kind precedence; unit-tested in `test/unit/block_actions_test.dart`, 10 cases), and `blockActionsFor(context, …)` binding kinds → launchers that REUSE existing routes (capture `/captures/new`, observe `/observations/new`, check-in/headcount `/groups/:id/attendance`, incident `/incidents/new`, message `/messages`, pickup `/pickup`, words `/action-words`, run-deck `/session/run`, run `/arc`, trip `/trips/:id`, notify `/recap`, cast `showCastToRoom`). Drops any action whose context is missing — no dead buttons. Rendered host-only on the (never-mirrored) `DeckOverview` card via its new `actionsForBeat` param + `_ActionTray`; the dark, mirrorable `BeatPresenter` is deliberately untouched so the room keeps the clean slide.
- `routine_script_providers.dart` — per-space routine-script overrides on the `routine_scripts` cap: `decode/encodeRoutineScripts`, `customRoutineScriptsProvider` / `customRoutineScriptProvider(kind)` / `effectiveRoutineScriptProvider(kind)` (override-or-default), and `RoutineScriptActions` (serialized `_pending` read-modify-write — `setScript` / `resetScript`). Mirrors `DayTemplateActions`.
- `routine_script_editor_screen.dart` (`RoutineScriptEditorScreen`) — `/routines`: the routine-script editor. ChoiceChip routine picker (per-routine drafts kept alive across switches so typed text survives), a `ReorderableListView` of step `TextField`s, an `InputChip` tool row + add field, Save (dirty-gated) / Reset-to-default (shown only when overridden), `DismissGuard`. Reached from Settings → Resources + omnibox `page.routines`.
**Status**: This Week hub + world projection (Cast) + worksheets + Today card shipped (waves "week engine" + "worksheets" + "cast", commit range fbfdda3–206b108). Book screen + curriculum importer shipped (waves "the Book" + "import curriculum activities", commits 2021813 + 5d4db52). Play Today (DayRunScreen) + Big Thinking system games + thinking_screen shipped (waves feat/kid-book + feat/curriculum-activity-import, commit 1320864). ActivityArcScreen + BeatPresenter refactor shipped (wave feat/present-arc, commit b4abd80). House timer caps (`timer_presets` + `suggest_play_minutes`) shipped (batch D1 commit 2b5937a — `house_timer.dart`, program-settings tiles, injected into `buildDayRun`/`buildActivityArc`). 50-day journey content layer shipped (commits dbdd137, d91e8e4, 5df388c, af650ad — `world_blocks.json` bundle, `world_blocks.dart` models + providers, `journey_day_sheet.dart` shared sheet, `_TodaysFocusCard` on Today, `_FortnightSection` on `/this-week`, `_QuestionOfTheDayBanner` on `/wall`, wall-question-deck PDF in Printable Toolkit). Block-boundary room-prep callouts shipped (commit f4768b8 — `journey_day_sheet.dart` shows "Set up the room today" / "Hand off to the next world" on block boundary days; `JourneyDayRow` shows room-setup / flip icons on those rows). Kid-facing Action Words pick shipped (commit 247f2c9 — `action_words_kid_screen.dart` at `/action-words/pick/:subjectId`). Role-4 kid verb-job kid-mode surface shipped (`kid_job_screen.dart` at `/action-words/job/:subjectId` — the kid's picks reshape a kid-mode "do your jobs" screen; `toggleDone` write pinned by `action_words_actions_db_test.dart`). Growth arc / showcase shipped (commit 337ef4f — `growth_arc.dart` + `growth_arc_screen.dart` at `/growth/:subjectId`). Season hub shipped (commit 47b323d — `program_hub_screen.dart` at `/program`, `seasonPositionProvider` in `world_blocks.dart`, nav destination "Program" after Action Words, omnibox entry `page.program`). Run the day shipped (branch feat/day-block-run — `block_run.dart` + `block_run_screen.dart` at `/run-day` + `/run-day/present`; nav destination "Run the day" in Activities group; omnibox `page.run-day`). Routine-script editor shipped (branch feat/routine-scripts — `RoutineKind` library in `block_run.dart`, `routine_script_providers.dart` + `routine_script_editor_screen.dart` at `/routines`; `routine_scripts` cap; Settings → Resources + omnibox `page.routines`; the day-run reads overrides as the top-priority `scriptOverride`). Slide-as-launchpad shipped (branch feat/slide-launchpad — `block_actions.dart` + a host-only "use right now" action tray on the run-day `DeckOverview` cards via `actionsForBeat` / `_ActionTray`; each block surfaces its relevant app features, one tap away, reusing existing routes; the mirrored `BeatPresenter` left clean). Activity matcher verb-tagging library hookup, spell timers still deferred.
**Depends on**: Entries (`kind='action_words'` + `kind='world_rule'` — add-a-rule mechanic), Subjects, Viewer, Spaces (program_start_date cap via world_schedule.dart; timer_presets + suggest_play_minutes caps via house_timer.dart), Activities (curriculum importer writes), Schedule (`scheduleDayForGroupProvider` — BlockRunScreen reads today's schedule_blocks via this Schedule provider to build the run-of-show deck), LiveSession (castImmersiveProvider — DayRunScreen + GrowthArcScreen + BeatPresenter use cast immersive flag), Kid mode (ActionWordsKidScreen + KidJobScreen lock via kidModeProvider + kidModeLockedRouteProvider), Photos (GrowthArcScreen reads `growthArcPhotosProvider` which reads `attachmentsForEntityProvider` for observation photos; `PersonPhotoNetwork` renders signed-URL images on `photo` beats), `flutter_tts` (VerbVoice on-device TTS for pre-reader voiceover on kid pick screen).
**Consumed by**: Today (`_ThisWeekWorldCard` + `_TodaysFocusCard` mounted in today_sections.dart reads `currentWorldProvider` / `currentProgramDayProvider` / `todaysJourneyDayProvider` / `currentBlockProvider` / `todaysWallQuestionProvider`; also `contextLeadProvider` in `context_lead.dart` reads `currentWorldProvider`), World (character_sheet_screen.dart reads `systemThinkingGameProvider` + imports `thinking_games.dart` + `widgets/thinking_game_sheet.dart` to surface "the game under this system" on each character-sheet section; also launches `GrowthArcScreen` via `_Links` "Play their story" button and `ActionWordsKidScreen` is launched from `ActionWordsScreen._KidRow`), Settings (program_settings_screen.dart reads `houseTimerPresetsProvider` + `houseSuggestPlayMinutesProvider` for the timer tiles; writes via `houseTimerActionsProvider`), Toolkit (`toolkit_pdf.dart` + `print_toolkit_screen.dart` import `world_blocks.dart` for `printWallQuestionDeck` — 50 wall-question posters), ProgramHubScreen (consumes `seasonPositionProvider` + `worldBlocksProvider` + `curriculumWorldsProvider` + `actionWordsCollectionProvider` + `subjectsInSpaceProvider` — all within this same feature folder), Family (`welcome_actions.dart` reads `currentWorldProvider` for the dinner-question fact on the welcome PDF).
**Last verified**: 2026-07-13

---

## ActivityRuntime
**Path**: `lib/features/activity_runtime/`
**Purpose**: Short, card-shaped brain-break activities that a teacher (or a kid) can launch mid-session to reset the room.
**Personas served**: All staff (Jordan, Coach Sam, Brianna launch breaks, and launch Do It with the room), Ava (Photography is kid-locked; Role Cards, Group Discussions, Pattern Maker, and Do It are teacher-paced — Do It is the kids' real-world action that leaves a record, kid-first per docs/VISION.md).
**Discovery surfaces**:
- Routes: `/breaks` (deck), `/activity/do-it` (Do It — `?group=` scopes the room record), `/activity/math` (Many Paths), `/activity/math-game` (Math Game), `/activity/photo` (Photo Studio — route exists on all platforms; screen degrades to "No camera here" off-mobile), `/activity/this-or-that` (Quick Picks), `/activity/starts-with` (Beat the Letter), `/activity/as-if` (Act It Out), `/activity/roles` (Role Cards), `/activity/pattern` (Make a Pattern), `/activity/discussions` (Group Discussions), `/activity/riddles` (Riddles), `/activity/breathe` (Mindful Minute), `/activity/fact-or-fib` (Fact or Fib), `/activity/story` (Story Starters), `/activity/rhyme-time` (Rhyme Time), `/activity/fill-blank` (Fill in the Blank), `/activity/letters` (Letters — `?group=` selects a cohort to pair), `/activity/penny` (Penny for a Thought), `/activity/potions` (Potions), `/activity/grid-reveal` (Reveal the Picture), `/live/charades` (Charades — deck card destination, hosted by Games/LiveSession feature)
- Omnibox: **Do It** is the one activity with a direct catalog entry (`page.do-it`, label "Do It", guardian-gated, broad off-screen keywords); every other individual activity has no direct entry and is reached through the Brain Breaks deck (`/breaks`, in the drawer) or its slash command
- Slash: `/breaks` (aliases: `break`, `brainbreaks`, `games`, `play`), `/do-it` (aliases: `doit`, `do`, `real`, `action`, `challenge`, `try this`, `build`, `move`), `/math {answer}` (aliases: `paths`), `/mathgame` (aliases: `quiz`, `quickmath`), `/photo {prompt}` (aliases: `camera`, `photos`) **— mobile-only (gated by `isMobileCapturePlatform`; not present on web or desktop)**, `/thisorthat` (aliases: `this`, `tot`, `wouldyourather`), `/startswith` (aliases: `letters`, `ck`, `words`), `/asif` (aliases: `acting`, `drama`, `act`), `/roles` (aliases: `role`, `animal`, `animals`, `people`, `jobs`, `cards`, `pretend`), `/pattern` (aliases: `patterns`, `tile`, `kaleidoscope`, `symmetry`, `repeat`), `/discuss` (aliases: `discussion`, `talk`, `circle`, `grouptalk`, `conversation`), `/riddles` (aliases: `riddle`, `brainteaser`, `brainteasers`, `guess`), `/breathe` (aliases: `breath`, `calm`, `mindful`, `relax`, `breathing`), `/factorfib` (aliases: `fact`, `fib`, `trueorfalse`, `truefalse`, `trivia`), `/story` (aliases: `stories`, `storytime`, `imagine`, `tale`, `twist`), `/rhyme` (aliases: `rhymes`, `rhymetime`, `words`), `/fillblank` (aliases: `adlibs`, `madlibs`, `blank`, `fill`, `fillintheblank`), `/letters` (aliases: `letter`, `write`, `penpal`, `notes`, `writetoeachother`), `/penny` (aliases: `pennies`, `count`, `counting`, `thought`, `tally`), `/potions` (aliases: `potion`, `magic`, `garden`, `mix`, `brew`, `spell`)
- Drawer: yes — "Brain Breaks" under the "Activities" collapsible group (between Present and Missions)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Photography is the only kid-locked activity; all others are teacher-paced and exit via the back arrow.
**Data**: [content_items](SCHEMA.md#content_items) — read via `bankedContentProvider` (`lib/features/activity_runtime/content_bank_providers.dart`); the `LocalContentBank.seededWith` factory merges the curated Dart floor with any synced DB rows. Growing the bank means adding seed migrations through Claude Code — see `docs/CONTENT_BANK.md §1.3`. Live multi-device activities (Charades, live This-or-That) intentionally read the curated floor only (`LocalContentBank.seeded`) for deterministic shared order across devices. Pattern Maker captures a photo via `image_picker` but does not write to any synced table. **Do It is the exception that writes durable data**: each completion is an [entries](SCHEMA.md#entries) row of `kind = 'did_it'` (via `EntryActions.recordDidIt`) — a room record (`group_id`, no `subject_id`) plus an opt-in attribution row per tagged child (`subject_id`); an optional proof photo rides the room record as an [attachments](SCHEMA.md#attachments) row through the standard `PhotoService.uploadOnly` → Storage path. This is the accumulative "Do It" genre (docs/VISION.md 2026-06-18) — unlike the ephemeral games, doing leaves evidence.
**Surfaces**:
- *Brain Breaks deck* — `lib/features/activity_runtime/brain_breaks_screen.dart`. 21 cards on mobile (Android/iOS), 20 off-mobile (Photo Studio hidden via `isMobileCapturePlatform`) + a Surprise button; each card pushes its activity route. **Do It leads the deck** (first card, unconditional). The toggle-gated Heroes / Routines / Daily / Calm / Spellbook cards slot in after Do It when their settings switch is on.
- *Fill in the Blank* — `lib/features/activity_runtime/fill_blank_screen.dart`. Ad libs: a silly template (`ContentKind.fillBlank` — `{n}` placeholders + a `blanks` prompt list) hides its words; the room shouts one per blank, the host types it, then the goofy sentence is REVEALED big with the words underlined — and read aloud. Teacher-paced; ephemeral. "Another one" re-shuffles.
- *Letters* — `lib/features/activity_runtime/letters_screen.dart` (+ pure `letters.dart`). Write to each other: a kind prompt (`ContentKind.writePrompt`) + `letterPairs(roster, salt)` pairs the cohort into a write-to CYCLE so everyone writes one note and receives one (nobody left out, no self-letters). Cohort chip selector; "New prompt" / "Shuffle pairs". Paper-first (no kid phone), teacher-paced, ephemeral.
- *Penny for a Thought* — `lib/features/activity_runtime/penny_screen.dart`. "It's math, it's counting": a question (reused from `ContentKind.question`) sparks thoughts; each shared thought taps a penny into the pile; the pile is drawn in rows of ten (count by tens) and the big number is the answer. Undo / New question / Start over. Teacher-paced, ephemeral — sharing + counting in one.
- *Potions* — `lib/features/activity_runtime/potions_screen.dart` (+ pure `potions.dart`). "Creating our own potions… go to the garden": `brewPotion(salt)` generates a potion-of-the-moment — 2–3 counted garden ingredients (the counting), a stir count, and a magical effect to reveal — for the room to gather + mix + NAME for real. "Brew another" re-rolls. Garden-first (no kid phone), teacher-paced, ephemeral.
- *Do It* — `lib/features/activity_runtime/do_it_screen.dart`. One real-world action at a time, big and host-present, filtered from `bankedContentProvider` to `ContentKind.doIt`. Two ways to mark done: an instant **We did it!** quick tap (room `did_it` record) and a tertiary **Snap the proof or tag who led it** that opens `_DoItEvidenceSheet` — single-photo proof (`pickPhoto`/`uploadOnly`, camera hidden on web) + opt-in multi-select of the cohort roster (`subjectsInGroupProvider`). The photo rides ONLY the room record (offline-attachment id contract); tagged children get photo-less attribution rows. Teacher-paced. The accumulative genre (docs/VISION.md 2026-06-18).
- *Role Cards screen* — `lib/features/activity_runtime/role_cards_screen.dart`. Deck-switcher chip row; Animals & Nature deck (23 cards) + People & Jobs deck (12 profession cards). Catalog + `RoleDeck` struct in `roles.dart`. Teacher-paced.
- *Group Discussions screen* — `lib/features/activity_runtime/discussions_screen.dart`. Teacher picks a topic + age band; one curated open-ended prompt at a time; optional "Go deeper" follow-up. Pure-Dart catalog. Teacher-paced.
- *Make a Pattern screen* — `lib/features/activity_runtime/pattern_maker_screen.dart`. Snap a tile → kaleidoscope-tiled repeating pattern. `image_picker` camera. Teacher-paced.
- *Photo Studio* — `lib/features/activity_runtime/photography_runner_screen.dart`. Full-screen camera with a teacher-provided prompt. Mobile-only deck card + slash command (gated by `isMobileCapturePlatform`); the `/activity/photo` route still exists on all platforms but the screen shows "No camera here" off-mobile. The ONLY kid-locked break (enters kid mode in `initState`, exits in `dispose`; 5-tap top-left staff exit).
- *Many Paths (math runner)* — `lib/features/activity_runtime/math_runner_screen.dart`. How many ways to a target number? Teacher-paced. `?target=N` seeds the answer; defaults to 12.
- *Math Game* — `/activity/math-game` renders `GameRunner(def: MathQuizGame())` (`lib/features/games/games/math_quiz_game.dart`). Mixed-mechanic one-question-at-a-time arithmetic. Teacher-paced. Ported to GameRunner 2026-06-03; bespoke screen deleted.
- *Beat the Letter* — `/activity/starts-with` renders `GameRunner(def: LetterWordsGame())` (`lib/features/games/games/letter_words_game.dart`). Words that start with a given letter. DB-backed via `bankedContentProvider`. Teacher-paced. Ported to GameRunner 2026-06-03.
- *Act It Out* — `/activity/as-if` renders `GameRunner(def: AsIfGame())` (`lib/features/games/games/as_if_game.dart`). Perform a line in an emotion/character. DB-backed via `bankedContentProvider`. Teacher-paced. Ported to GameRunner 2026-06-03.
- *Quick Picks* — `/activity/this-or-that` renders `GameRunner(def: ThisOrThatGame())` (`lib/features/games/games/this_or_that_game.dart`). Binary this-or-that questions. DB-backed via `bankedContentProvider`. Teacher-paced.
- *Riddles* — `/activity/riddles` renders `GameRunner(def: RiddlesGame())` (`lib/features/games/games/riddles_game.dart`). Guess-the-answer riddles. DB-backed via `bankedContentProvider`. Teacher-paced.
- *Reveal the Picture* — `/activity/grid-reveal` renders `GameRunner(def: GridRevealGame())` (`lib/features/games/games/grid_reveal_game.dart`). Call a square, guess the picture. DB-backed. Teacher-paced.
- *Mindful Minute* — `lib/features/activity_runtime/breathe_screen.dart`. Calm breathing break. Teacher-paced.
- *Fact or Fib* — `/activity/fact-or-fib` renders `GameRunner(def: FactOrFibGame())` (`lib/features/games/games/fact_or_fib_game.dart`). True/false claims; room votes; Reveal shows the verdict + real fact. DB-backed via `bankedContentProvider`. Teacher-paced.
- *Story Starters* — `/activity/story` renders `GameRunner(def: StoryStartersGame())` (`lib/features/games/games/story_starters_game.dart`). Build a story aloud with plot twists. DB-backed via `bankedContentProvider`. Teacher-paced. Ported to GameRunner 2026-06-03.
- *Rhyme Time* — `/activity/rhyme-time` renders `GameRunner(def: RhymeTimeGame())` (`lib/features/games/games/rhyme_time_game.dart`). How many rhymes can the room find for a given word? DB-backed via `bankedContentProvider`. Teacher-paced. Ported to GameRunner 2026-06-03.
- *Charades (deck launcher)* — deck card in `brain_breaks_screen.dart` pushes `/live/charades`; the route and screen are owned by the Games/LiveSession feature. The deck card is unconditional (not platform-gated).
- *Kid mode lock mixin* — `lib/features/activity_runtime/kid_mode_lock.dart`. Shared `KidModeLock<T>` mixin used ONLY by Photography; other activities do not use it.
- *Content bank* — `lib/features/activity_runtime/content_bank.dart`. `ContentItem`, `ContentKind`, `ContentSource`, `LocalContentBank` — the source-agnostic interface all DB-backed activities depend on. `curatedSeeds` is the offline floor. `LocalContentBank.seededWith(extra)` merges banked DB rows on top.
- *Content bank providers* — `lib/features/activity_runtime/content_bank_providers.dart`. `bankedContentProvider` (StreamProvider, keepAlive) — watches `content_items` via `ContentBankDao` and yields `curatedSeeds ++ banked` rows; falls back to `curatedSeeds` on DB error.
**Depends on**: Kid mode (Photography only), Photos (pattern_maker uses image_picker; bytes are not stored in any synced table; Do It uses `PhotoService.uploadOnly` for proof photos), Entries (Do It writes `did_it` rows via `EntryActions.recordDidIt`), Subjects (Do It reads `subjectsInGroupProvider` for the opt-in "who led it" roster).
**Consumed by**: LiveSession + games framework (`content_bank.dart` seeds every `GameDefinition`'s `initialState`).
**Last verified**: 2026-06-19

---

## ClassMemory
**Path**: `lib/features/class_memory/`
**Purpose**: What a ROOM remembers — questions it hasn't answered, things it discovered, words it started using. Not everything worth keeping belongs to a child; until this existed, every artifact was subject-tagged and a room accumulated nothing of its own.
**Personas served**: All staff running a cohort (Coach Sam, Jordan); the room itself is the subject.
**Discovery surfaces**:
- Routes: `/groups/:id/memory`
- Omnibox: yes — "Remembers · {Group.name}" per cohort, keyed on what people search for ("questions", "what we wondered", "words") rather than the feature's name
- Slash: no
- Drawer: no — reached from the room, which is where the room's memory belongs
- Settings: no
**Capabilities**: none — any staffer in the room can keep something
**Data**: [entries](SCHEMA.md#entries) with `kind = 'class_memory'`, `group_id` set and `subject_id` NULL. **No migration**: `entries.group_id` has always been nullable alongside `subject_id`, so a room-owned entry was representable before the surface existed.
**Surfaces**:
- *What this room remembers* — `class_memory_screen.dart`. Three bands (question / discovery / word), each with an inline capture. Every heading renders even when empty — a heading is a prompt as much as a label.
**Depends on**: Groups, Entries.
**Consumed by**: nothing yet. `returnableQuestionProvider` exposes the oldest still-open question for contextual Return (docs/VISION.md), which is NOT built — that card exists only as mockup 005.
**Last verified**: 2026-08-26

---

## Attendance
**Path**: `lib/features/attendance/`
**Purpose**: Daily check-in / check-out for one cohort at a time.
**Personas served**: All staff (Maya for oversight, Jordan + Coach Sam day-to-day).
**Discovery surfaces**:
- Routes: `/checklist`, `/groups/:id/attendance`
- Omnibox: yes — "Morning checklist", "Take attendance · {Group.name}" (per cohort), "Mark absent today · {Child name}" (per subject, single-tap write with snackbar + "Open attendance" action for course-correction)
- Slash: `/attendance {group}` (alias `/atd`)
- Drawer: no
- Settings: no
**Capabilities**: `can_take_attendance`
**Data**: [attendance_records](SCHEMA.md#attendance_records), [groups](SCHEMA.md#groups), [subjects](SCHEMA.md#subjects)
**Surfaces**:
- *Morning checklist* — `lib/features/attendance/morning_checklist_screen.dart`. Today's cohorts list; one tap opens a cohort's check-in.
- *Attendance screen* — `lib/features/attendance/attendance_screen.dart`. Per-cohort grid of subjects with present/absent/late toggles.
**Depends on**: Groups, Subjects.
**Consumed by**: Insights (late streaks), Today (morning card).
**Last verified**: 2026-05-21

---

## Auth
**Path**: `lib/features/auth/`
**Purpose**: Google-only sign-in; gates the whole app.
**Personas served**: All staff, All guardians.
**Discovery surfaces**:
- Routes: `/login`
- Omnibox: no — pre-auth surface
- Slash: none
- Drawer: no — drawer is signed-in-only; sign-out lives in the drawer header
- Settings: no
**Capabilities**: None — pre-auth.
**Data**: None directly — reads `auth.users` via Supabase; member resolution happens in `viewer.dart`.
**Surfaces**:
- *Login screen* — `lib/features/auth/login_screen.dart`. "Continue with Google" → `supabase.auth.signInWithOAuth(provider: google, redirectTo: com.jardine.differentworld://login-callback)`.
**Depends on**: Supabase client configuration in `main.dart`.
**Consumed by**: Every signed-in feature (via `viewerProvider`).
**Last verified**: 2026-05-21

---

## Calm
**Path**: `lib/features/calm/`
**Purpose**: "What to do instead" — the room's calm, co-held reference of what to do for big feelings (mad / worried / sad / bored / wiggly) + the agreements that are common ground (docs/VISION.md 2026-06-19; "not noise, just a list"). Read-only, offline, in-proximity.
**Personas served**: Ava (the child reaching for a calmer choice), All staff (host it / point to it in the moment).
**Discovery surfaces**:
- Routes: `/calm`. Always resolves; surfaces below are gated.
- Omnibox: `page.calm` ("What to do instead" — crisis-retrieval keywords: calm / mad / angry / bored / worried / anxious / sad / feelings / agreements). **Toggle-gated** (`calmEnabledProvider`) + guardian-gated off.
- Slash: none (a static slash list can't honor the toggle).
- Drawer: no — reached via the Brain Breaks deck's "What to do instead" card (when the toggle is on) or the omnibox.
- Settings: yes — "What to do instead" switch in Preferences (`_CalmTile`, off by default).
**Capabilities**: None — open to all signed-in staff once the director switches it on.
**Data**: None — pure bundled Dart (`calm_catalog.dart`). No synced table, no writes, no entry kind. A reference, not a record.
**Surfaces**:
- *Calm screen* — `lib/features/calm/calm_screen.dart`. `/calm`; a feeling selector → its calm actions; the agreements underneath. No persistence (a plain `StatefulWidget` — just a selected index).
- *Catalog* — `lib/features/calm/calm_catalog.dart`. `CalmFeeling` + the feelings/actions + `roomAgreements`.
- *Toggle* — `lib/features/calm/calm_setting.dart`. `calmEnabledProvider`, default off.
**Depends on**: None (self-contained content + the shared scaffold widgets).
**Consumed by**: ActivityRuntime (Brain Breaks deck injects the card), Omnibox (`page.calm`), Settings (`_CalmTile`).
**Last verified**: 2026-06-19

---

## Captures
**Path**: `lib/features/captures/`
**Purpose**: One-tap "I noticed…" inbox. Quick thoughts triaged later into observations, tasks, or discarded.
**Personas served**: All staff (Jordan + Coach Sam on the floor; Maya triaging the inbox).
**Discovery surfaces**:
- Routes: `/captures`, `/captures/new`
- Omnibox: yes — "Capture inbox", "Capture a note" (action), also Recent Captures strip on `/search`
- Slash: `/captures` (alias `/inbox`)
- Drawer: yes — "Captures" (main destinations, position 3)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Promotion to task/observation requires the respective cap.
**Data**: [captures](SCHEMA.md#captures), [tasks](SCHEMA.md#tasks), [entries](SCHEMA.md#entries)
**Surfaces**:
- *Capture inbox* — `lib/features/captures/capture_inbox_screen.dart`. List of open captures; swipe to promote / dismiss.
- *Capture screen* — `lib/features/captures/capture_screen.dart`. Free-text input; on submit, writes a new capture row.
- *Composer integration* — the omnibox bar's "capture mode" (lightning-bolt) writes through this feature.
- *Promotion actions* — `CaptureActions.promoteToObservation` and `promoteToTask` in `lib/features/captures/captures_providers.dart`. Both wrap their two-row writes (create entry / task + mark capture promoted) in a single `db.transaction(...)` so a mid-flight failure can't leave an orphan entry/task or a half-flipped capture status. Blast-radius flagged the prior "atomic-ish" two-write path 2026-05-22.
**Depends on**: Tasks (promotion destination), Entries (observation promotion destination).
**Consumed by**: Today (composer + recent strip), Review (open-captures stat + "Capture a reflection" CTA).
**Last verified**: 2026-05-22

---

## Certifications
**Path**: `lib/features/certifications/`
**Purpose**: Track staff certs (MAT, CPR, Driver) with issue + expiration dates; gate caps that require them.
**Personas served**: Maya (compliance oversight), All staff (read their own).
**Discovery surfaces**:
- Routes: none — embedded in Member detail
- Omnibox: no
- Slash: none
- Drawer: no
- Settings: no — reached via `/settings/team/:id`
**Capabilities**: Reading certs is open; writing requires `can_manage_staff` (lives on director / lead).
**Data**: [member_certifications](SCHEMA.md#member_certifications)
**Surfaces**:
- *Cert section in Member detail* — embedded in `lib/features/settings/member_detail_screen.dart`. Per-member list + add/edit form.
**Status**: provider-only feature folder; no top-level screen. Cert UI lives inline in Member detail.
**Depends on**: Members.
**Consumed by**: Vehicles (Driver cert gates `can_drive`), Insights (expiring-cert signal).
**Last verified**: 2026-05-21

---

## ChildWorld
**Path**: `lib/features/child_world/`
**Purpose**: Each child's personal weekly hub — their intention for the week, their own project (title + steps + progress), today's daily answer + hero, and their growth arc title + days — making the dailies/weeklies/projects arc personal per child.
**Personas served**: Maya, Jordan, Coach Sam, Pat (all staff who author or view a child's progress; the hub is reached from the child detail screen, so the same staff who manage the roster).
**Discovery surfaces**:
- Routes: `/subjects/:id/world` — nested inside the subjects shell, the same depth as `/subjects/:id/day` and `/subjects/:id/me`. Registered in `lib/app/router.dart` at `path: 'subjects/:id/world'` rendering `ChildWorldScreen(subjectId: id)`.
- Omnibox: no — per-child screen; no catalog entry. Reached from the child detail screen only.
- Slash: none — same rationale as `/subjects/:id/day`; per-child contextual, not a top-level command.
- Drawer: no — per-child screen, not a top-level destination. Absence is BY DESIGN (same pattern as `/subjects/:id/day`, `/subjects/:id/me`, `/growth/:subjectId`).
- Settings: no — no opt-in toggle; available to all staff who can view the child detail screen.
**Capabilities**: None beyond staff roster access — same gate as the child detail screen.
**Data**: [entries](SCHEMA.md#entries) — writes `kind='weekly_intention'` (one UPSERTED row per (subject, week); `details` = `{week, text}`) and `kind='project'` (one UPSERTED row per (subject, week); `details` = `{week, title, steps[], done}`), via `EntryActions.setWeeklyIntention` / `setProject` / `setProjectProgress` (all go through `_upsertSubjectWeek`). Reads those kinds plus the existing `kind='daily_response'` (today's answer via `todaysAnswerProvider`) and `kind='hero'` (via `heroForSubjectProvider` from Heroes feature) per subject.
**Surfaces**:
- *ChildWorldScreen* — `lib/features/child_world/child_world_screen.dart`. `/subjects/:id/world`; a `BentoGrid` of four tiles: `_IntentionTile` (wide — set/edit the child's weekly intention; taps to `_IntentionSheet` glass sheet), `_ProjectTile` (hero — start or advance the child's project; taps to `_ProjectSheet` glass sheet for create/edit or `_ProjectChecklistSheet` for step-by-step tick-off), `_DayTile` (shows today's daily answer + hero name; read-only reflecting data from Daily + Heroes), `_GrowthTile` (shows emerging title + days in the world from `actionWordsCollectionProvider`; read-only reflecting Action Words data). All four tiles are offline-first (Drift-watched via `weeklyIntentionProvider`, `childProjectProvider`, `todaysAnswerProvider`, `heroForSubjectProvider`, `actionWordsCollectionProvider`).
- *ProjectView model* — `lib/features/child_world/child_world_model.dart`. Pure view model parsed from a `project` entry's details JSON; carries `title`, `steps[]`, `done`, and helpers (`progress`, `nextStep`, `isComplete`).
- *Providers* — `lib/features/child_world/child_world_providers.dart`. `weeklyIntentionProvider(SubjectWeekKey)`, `childProjectProvider(SubjectWeekKey)`, `todaysAnswerProvider(subjectId)` — all `StreamProvider.autoDispose.family`, Drift-watched, offline-first.
- *"Their world" EdgeAction* — `lib/features/subjects/subject_detail_screen.dart`, line ~148. An `IconButton`-style action in the child detail screen's top chrome, label "Their world", pushes `/subjects/$subjectId/world`.
**Depends on**: Entries (`EntryActions.setWeeklyIntention` / `setProject` / `setProjectProgress`; reads `kind='daily_response'` via `todaysAnswerProvider`), Heroes (`heroForSubjectProvider` for the day tile), Action Words (`actionWordsCollectionProvider` for the growth tile; `currentCurriculumWeekProvider` for the week key), Subjects (`subjectByIdProvider` for the child's first name).
**Consumed by**: Subjects (subject_detail_screen.dart hosts the "Their world" EdgeAction that pushes to this route).
**Last verified**: 2026-07-13

---

## Cockpit
**Path**: `lib/features/cockpit/`
**Purpose**: The clock-driven home — `/now` shows ONE beat at a time (getting ready → good morning → now → field trip → reveal → pickup → send), chosen by the time of day and what's live; you never navigate. The finished shape of "context is the navigation" (docs/VISION.md 2026-06-15; build map in docs/COCKPIT.md).
**Personas served**: All staff (Maya | Jordan | Coach Sam | Pat — the daily-logger spine)
**Discovery surfaces**:
- Routes: `/now`, `/conductor`, `/today`
- Omnibox: yes — `page.now` "Now — the cockpit" (keywords: now, cockpit, focus, focus mode, the clock, right now, beat); `page.conductor` "Conductor — the planning desk" (keywords: conductor, dashboard, planning, desk, reports, books, export, the deep, laptop, overview)
- Slash: none
- Drawer: no — opt-in beta reached via omnibox + Settings; the cockpit can replace Today as the home surface via "Cockpit as home" in Settings; Today is always reachable at `/today` (the cockpit's curiosity bar links there)
- Settings: yes — "Now — the cockpit" row (navigate to `/now`) and "Cockpit as home" switch (promotes `/now` to the home slot, demoting Today to `/today`), both in the Preferences group
**Capabilities**: None beyond staff — the contextual lead returns null for guardians, and the router's guardian gate bounces them off `/now`
**Data**: [subjects](SCHEMA.md#subjects) (read by `ConductorScreen` via `subjectsInSpaceProvider` to populate the every-child-book grid). All other state is composed from other features' providers (`dayPhaseProvider`, live-block providers, `contextLeadProvider`, `seasonPositionProvider`) — no new table. `cockpit_home_setting.dart` persists `settings.cockpit_as_home` in SharedPreferences (not a synced table).
**Surfaces**:
- *Beat engine* — `cockpit_beat.dart`. `computeCockpitBeat(phase, liveBlockKind, sendable, closingReveal)` (pure, unit-tested in `test/unit/cockpit_beat_test.dart`) → a `CockpitBeat`; `cockpitBeatProvider` adapts the live providers (honors the context room override). A live field trip bends the clock (wins over the phase). `closingRevealProvider` (StreamProvider.autoDispose) ticks each minute and is true in the last 20 minutes of program time when a world is active, auto-flipping `DayPhase.program` to `CockpitBeat.reveal`.
- *The cockpit screen* — `now_cockpit_screen.dart`. `NowCockpitScreen`: full-bleed single beat. Slice 2 adds beat-specific body widgets: `_MorningCard` (good-morning beat — verb-pick CTA + season position + arrival lead moves), `_RevealCard` (closing-window beat — "Start the reveal" → `/play-today`), `_AfterPickupCard` (send/closed — now routes to `/action-words/send`, not `/messages`). Live beats (getting-ready / now / field-trip / pickup) continue to use `_LeadCard` (contextual lead). Curiosity bar destinations updated: "Today" now links to `/today` (not `/`).
- *Conductor screen* — `conductor_screen.dart`. `ConductorScreen` at `/conductor`: the Layer-3 planning desk designed for larger screens. Shows the season position (week / day / world name), two week-anchor actions (The week's plan → `/program`; Send home → `/action-words/send`), and a full child-roster grid (each child's `FeatureCard` → `/book/:subjectId`). Reuses `seasonPositionProvider` + `subjectsInSpaceProvider`; no new data.
- *Cockpit home setting* — `lib/features/settings/cockpit_home_setting.dart`. `cockpitAsHomeProvider` (AsyncNotifierProvider<CockpitAsHomeNotifier, bool>) — persists `settings.cockpit_as_home` in SharedPreferences. When true, `_SignedInHome` (router) renders `NowCockpitScreen` at `/`; Today is still reachable at `/today`.
**Depends on**: Today (`contextLeadProvider` / `dayPhaseProvider`), Schedule (live-block providers), Subjects (`subjectsInSpaceProvider` in ConductorScreen), Action Words (`seasonPositionProvider` in ConductorScreen + `_MorningCard`); delegates to Present (`/play-today`), Action Words (`/action-words/send`), Action Words (`/book/:subjectId`).
**Consumed by**: Router (`_SignedInHome` reads `cockpitAsHomeProvider` to pick the home surface at `/`).
**Last verified**: 2026-06-15

---

## Daily
**Path**: `lib/features/daily/`
**Purpose**: The daily ritual — the day's Question, Quote, and Mission, host-presented in sequence, each answered with a captured response (a sentence or a drawing) that becomes part of the record (docs/VISION.md 2026-06-19; "document the now… the things they'll write in their books"). Visible growth, not grades.
**Personas served**: Ava (answers the prompts), All staff (host the daily, scribe responses).
**Discovery surfaces**:
- Routes: `/daily` (`?group=` scopes the record). Always resolves; surfaces below are gated.
- Omnibox: `page.daily` ("The Daily" — keywords daily / today / question of the day / quote of the day / mission of the day / qotd). **Toggle-gated** (`dailyEnabledProvider`) + guardian-gated off.
- Slash: none (a static slash list can't honor the toggle).
- Drawer: no — reached via the Brain Breaks deck's "Today" card (when the toggle is on) or the omnibox.
- Settings: yes — "The Daily" switch in Preferences (`_DailyTile`, off by default).
**Capabilities**: None — open to all signed-in staff once the director switches it on.
**Data**: [entries](SCHEMA.md#entries) (`kind='daily_response'` — one accumulative row per answer; `details` = `{prompt_kind, prompt_text}`; `body` = the written response; subjectId → the child's Book, null → the room; via `EntryActions.recordDailyResponse`), [attachments](SCHEMA.md#attachments) (the optional drawing, offline-safe pinned id). Also writes `kind='did_it'` when the Mission is done (reuses `recordDidIt`). Reads the content bank (`ContentKind.question` / `quote` seeds + `doIt` for the mission) via `todaysDailyProvider`.
**Surfaces**:
- *Daily screen* — `lib/features/daily/daily_screen.dart`. `/daily`; presents the day's Question + Quote + Mission. Question/Quote open a response sheet (a sentence and/or a snapped drawing → `recordDailyResponse`); Mission gets "We did it!" → `recordDidIt`. Camera gated `isMobileCapturePlatform`.
- *Providers* — `lib/features/daily/daily_providers.dart`. `todaysDailyProvider` picks the day's three DETERMINISTICALLY (`dailyIndexFor(date)` — same for the whole room, rotates across days, no randomness). Mission reuses the Do It bank.
- *Toggle* — `lib/features/daily/daily_setting.dart`. `dailyEnabledProvider`, default off.
- *Content* — `ContentKind.question` + `ContentKind.quote` seeds in `content_bank.dart` (20 each, curated, kid-safe).
**Depends on**: ActivityRuntime / content bank (question/quote/doIt seeds + `bankedContentProvider`), Entries (`recordDailyResponse` + `recordDidIt`), Photos (drawing via `uploadOnly`).
**Consumed by**: ActivityRuntime (Brain Breaks deck injects the "Today" card), Omnibox (`page.daily`), Settings (`_DailyTile`).
**Last verified**: 2026-06-19

---

## Entries
**Path**: `lib/features/entries/`
**Purpose**: Unified daily log — observations, meals, naps, diapers, incidents, work samples — all rows in one table with a `kind` discriminator.
**Personas served**: All staff (Jordan + Coach Sam log; Maya reviews; Marcus + Lauren read).
**Discovery surfaces**:
- Routes: `/observations`, `/observations/new`, `/observations/:id/edit`, `/groups/:id/observations`
- Omnibox: yes — "Observations" (gated by `can_observe`), "Observations · {Group.name}" (per cohort), "New {entry label}" (action), "Quick observation · {Name}" (per subject)
- Slash: `/log {kid}` (aliases `/observe`, `/obs`)
- Drawer: yes — "Observations" (canonical nav, gated `canObserve`; position between Schedule and Captures)
- Settings: no
**Capabilities**: `can_observe`
**Data**: [entries](SCHEMA.md#entries), [attachments](SCHEMA.md#attachments)
**Surfaces**:
- *Observations index* — `lib/features/entries/observations_index_screen.dart`. Newest-first feed across all groups (filterable).
- *Observations screen* — `lib/features/entries/observations_screen.dart`. Per-cohort feed.
- *Observation form* — `lib/features/entries/observation_form_screen.dart`. Create / edit a single entry; photo attach, voice dictation via Deepgram mic (suffix-icon on the body TextField; owns its own `DeepgramVoiceController` instance — does NOT consume the shared `deepgramVoiceProvider` singleton, to avoid the dual-listener race against AppShell's composer mic).
- *Entry actions — work sample* — `EntryActions.createWorkSample` + `EntryActions.setWorkSampleInBook` in `lib/features/entries/entries_providers.dart`. `createWorkSample` inserts an `entries` row (`kind='work_sample'`) plus one `attachments` row (photo) in a transaction; `details` = `{world_id?, day?, in_book?}`. `setWorkSampleInBook` amends `details.in_book` on an existing row (curate for Summer Book). No new route — called from `work_sample_capture.dart` (`snapWork`) and from `WorkGallery`'s star button. `EntryKind.workSample = 'work_sample'` is the discriminator constant.
**Depends on**: Subjects, Groups, Attachments, Photos, Voice (Deepgram dictation on the body field).
**Consumed by**: Exports (Progress Report compiles entries), Captures (promotion destination), Insights (pattern detection), Family (Lauren read), Today (recent activity card), Subjects (`WorkGallery` reads `entriesForSubjectProvider` filtered by `EntryKind.workSample`; "Snap work" calls `createWorkSample`).
**Last verified**: 2026-06-13

---

## Entities
**Path**: `lib/features/entities/`
**Purpose**: Every named thing in the app (child, staff member, cohort, activity, place, vehicle, role, world, action-word) is tappable anywhere it appears — structured chips open a detail peek instantly; free-text prose auto-detects the same names on-device and links them too.
**Personas served**: All staff (ambient — no persona-specific gate; the peek and autotag work wherever staff prose appears).
**Discovery surfaces**:
- Routes: none — no destination route. Entities is an ambient enhancement wired into existing screens, not a navigable section. The peek (`showEntityPeek`) is a modal glass sheet that opens from a tap, never from a URL. Absence of a route is BY DESIGN.
- Omnibox: no — not a destination; no catalog entry. The feature makes OTHER destinations' content tappable, rather than adding an entry of its own.
- Slash: none — same rationale as Omnibox.
- Drawer: no — not a top-level destination.
- Settings: yes — "Live entities" switch (`_LiveEntitiesTile`, `SwitchListTile`) in the **Preferences** `_SettingsGroup` of `lib/features/settings/settings_screen.dart`. Default ON; the toggle is the escape hatch if auto-detection over-matches.
**Capabilities**: None — open to all signed-in staff. The feature is staff-scoped at the `EntityScope` level: `LinkifiedText` degrades to plain `Text` in `EntityScope.family` so guardian-facing surfaces never auto-link other children's names (the family-scope privacy boundary; pairs with `scrubOtherNames`).
**Data**: No new tables and no migration. Reads existing local Drift streams only: [subjects](SCHEMA.md#subjects), [members](SCHEMA.md#members) (via `membersInSpaceProvider`), [groups](SCHEMA.md#groups), [activities](SCHEMA.md#activities), [locations](SCHEMA.md#locations), [vehicles](SCHEMA.md#vehicles). Roles (`roleDecks`) and worlds (`curriculumWorldsProvider`) come from bundled Dart catalogs, not synced tables. All matching is on-device — PII never leaves the device.
**Surfaces**:
- *EntityRef / EntityKind* — `lib/features/entities/entity_ref.dart`. Value type `EntityRef` (kind + id + label) and `EntityKind` enum (subject / member / group / activity / location / vehicle / role / world / verb). `EntityKindVisual` extension supplies per-kind accent colour, icon, and noun label. `readableEntityTint` + `entityChipFill` are the two AA-safe color helpers that every consumer reaches for.
- *Matcher* — `lib/features/entities/entity_match.dart`. `findEntityMatches(text, terms, {exclude})` — pure function, zero Flutter, unit-testable (`test/unit/entity_match_test.dart`). Whole-word, proper-noun-gated for people names, longest-match-wins on overlap, `exclude` set is the family-scope guard hook.
- *Index provider* — `lib/features/entities/entity_providers.dart`. `liveEntitiesProvider` (AsyncNotifierProvider<bool>, SharedPreferences-backed, default ON) + `liveEntitiesOn(ref)` sync helper. `entityIndexProvider` (Provider<List<EntityMatchTerm>>) builds the on-device name→ref index from `subjectsInSpaceProvider`, `membersInSpaceProvider`, `groupsProvider`, `activitiesProvider`, `locationsProvider`, `vehiclesProvider`, `curriculumWorldsProvider`, and `roleDecks`; bare first names indexed only when unambiguous in the visible roster; verbs excluded (too common in prose).
- *Peek* — `lib/features/entities/entity_peek.dart`. `showEntityPeek(context, entity)` — glass sheet (`showGlassSheet`) showing identity header, kind eyebrow, a few live facts, and an optional "open full" button that navigates into the entity's real screen. Resolves live from the same local providers as the index; never hits the network.
- *Structured link* — `lib/features/entities/entity_link.dart`. `EntityLink` (ConsumerWidget) — renders a tappable tinted chip (padded) or inline tinted text (padded: false) for places that already know the entity id. Degrades to plain `Text` when live entities are off. Verified: `test/widget/entity_link_test.dart`.
- *Autotag text* — `lib/features/entities/linkified_text.dart`. `LinkifiedText` + `EntityScope` enum. Drop-in replacement for `Text` in staff prose surfaces — auto-detects entity names via `entityIndexProvider` + `findEntityMatches` and renders them as tappable inline spans opening `showEntityPeek`. Degrades to plain `Text` when live entities are off, in `EntityScope.family`, or when nothing matches.
**Depends on**: Schedule (activitiesProvider, locationsProvider), Groups, Subjects, Vehicles, Action Words (curriculumWorldsProvider for world index), ActivityRuntime (roleDecks for role index).
**Consumed by**: Entries (observation feeds — `observations_index_screen.dart`, `observations_screen.dart` use `LinkifiedText` on entry body), Incidents (`incident_card.dart` uses `LinkifiedText` on narrative), Captures (`capture_inbox_screen.dart`), Story (`widgets/moment_tile.dart`), Reflections (`reflection_session_screen.dart`), Missions (`missions_list_screen.dart`), Schedule (`schedule_screen.dart`, `trip_detail_screen.dart`, `widgets/substitute_lead_sheet.dart`, `activities_list_screen.dart` use `EntityLink` on activity/location/vehicle/member references), Attendance (`widgets/attendance_row.dart`), Groups (`group_detail_screen.dart`), Subjects (`widgets/observation_item.dart`), Pickup (`pickup_board_screen.dart`), Today (`today_sections.dart`), Vehicles (`vehicles_list_screen.dart`), Heroes (`heroes_hub_screen.dart`), Settings/Team (`team_screen.dart`), Action Words (`program_hub_screen.dart`, `themed_world_screen.dart`), Cockpit (`conductor_screen.dart`).
**Last verified**: 2026-06-20

---

## Exports
**Path**: `lib/features/exports/`
**Purpose**: Compile a child's observations into a shareable PDF and send to family via email or copy-link.
**Personas served**: Maya (creates), Jordan / Coach Sam / Brianna (all have `can_observe`, can create for their own subjects), Lauren / Devon / Helen / Marcus (recipients).
**Discovery surfaces**:
- Routes: `/groups/:id/students/:sid/progress-report`, `/exports/:id/send`
- Omnibox: yes — "Progress report · {Name}" (per subject, action)
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: Generating: `can_observe`. Sending: same (recipient list comes from `subject_guardians`).
**Data**: [exports](SCHEMA.md#exports), [export_recipients](SCHEMA.md#export_recipients), [entries](SCHEMA.md#entries), [guardians](SCHEMA.md#guardians), [attachments](SCHEMA.md#attachments) (signed-URL preview of observation photos in the compiled report)
**Surfaces**:
- *Progress report screen* — `lib/features/exports/progress_report_screen.dart`. Preview the compiled PDF; Send → push to `/exports/:id/send`.
- *Send export screen* — `lib/features/exports/send_export_screen.dart`. Pick recipients (guardian checkboxes preloaded with their email + manual-entry email) and send via Edge Function, or copy a 7-day signed URL.
**Depends on**: Entries, Subjects, Guardians, Photos (signed-URL preview of attachments).
**Consumed by**: Family Today (Lauren / Devon / Helen / Marcus see received reports via the `_ReceivedReportsCard`, shipped 2026-05-23 in Wave 39). Direct-PostgREST read (`myReceivedExportsProvider` queries Supabase directly), NOT the local Drift mirror — guardians' `members.space_id = null` means `by_space` never delivers `exports` / `export_recipients` to them. RLS on `export_recipients` gates by recipient identity. Tap → mint a 10-min signed Storage URL → `url_launcher` → OS PDF viewer. Wave 42 added Devon-persona read tracking: opening a report stamps `export_recipients.read_at` via the `markReceivedExportRead` helper; the card then renders a "Seen" badge on already-opened rows so co-parents can tell which reports they've already worked through. Co-parent visibility ("Also seen by Lauren") still deferred — needs a sibling-recipient query shape.
**Last verified**: 2026-07-13

---

## Family
**Path**: `lib/features/family/`
**Purpose**: Guardian (parent) lens. Read-only view of linked children + the messaging surface.
**Personas served**: Lauren, Devon, Helen, Marcus.
**Discovery surfaces**:
- Routes: `/children/:sid` (FamilySubjectDetailScreen), `/messages` (FamilyMessagesScreen — index), `/messages/:subjectId/:guardianId`, `/share-home` (FamilyShareScreen — the TV-homework loop, docs/VISION.md 2026-06-19)
- Omnibox: yes — "Messages" (gated by guardian + has-linked-children)
- Slash: none
- Drawer: yes — `GuardianDrawer` (`guardian_drawer.dart`), the family-side hamburger: Today, each child, Messages, **Share from home**, Display & text size, sign out. Distinct from the staff `MainDrawer`.
- Settings: no
**Capabilities**: Guardian role (`member.role == 'guardian'` AND `guardians.user_id == auth.uid()`).
**Data**: [guardians](SCHEMA.md#guardians) (offline-first via `by_guardian` stream), [spaces](SCHEMA.md#spaces) (offline-first via `by_guardian` stream), [subject_guardians](SCHEMA.md#subject_guardians) (offline-first via `by_guardian` stream), [messages](SCHEMA.md#messages) (offline-first via `by_guardian` stream), [export_recipients](SCHEMA.md#export_recipients) (offline-first via `by_guardian` stream), [subjects](SCHEMA.md#subjects) (direct PostgREST — 2-level subquery deferred), [attendance_records](SCHEMA.md#attendance_records) (direct PostgREST — 2-level subquery deferred), [entries](SCHEMA.md#entries) (direct PostgREST — observations via `familyEntriesForSubjectProvider`; incidents via server-stripping RPC `app.family_incidents_for_subject` in `familyIncidentsForSubjectProvider` — 2-level subquery deferred), [attachments](SCHEMA.md#attachments) (direct PostgREST — 2-level subquery deferred), [exports](SCHEMA.md#exports) (direct PostgREST via `myReceivedExportsProvider`)
**Surfaces**:
- *Family today* — `lib/features/family/family_today_screen.dart`. Each linked child's card; recent observation count, today's activity. Header carries a Display action that opens the shared text-size sheet (Helen-persona; guardians never reach `/settings`). Photo-of-the-moment shipped 2026-05-22. Wave 39 added a `_ReceivedReportsCard` above the kid list that surfaces the most recent progress-report PDFs the staff have sent the guardian. Per-child reads (subjects, attendance, entries, attachments) route through `family_providers.dart` via direct PostgREST — the 2-level subquery needed for PowerSync's `by_guardian` stream is deferred. Row-keyed tables (guardians, spaces, subject_guardians, messages, export_recipients) are now offline-first via the `by_guardian` stream.
- *Family subject detail* — `lib/features/family/family_subject_detail_screen.dart`. Read-only child profile + photo gallery + today's observations + messages preview + surfaced incidents. Reads subjects + attachments via `familySubjectByIdProvider` / `familyAttachmentsForEntityProvider` (PostgREST, gated by `viewer.canSeeSubject`). The `_FamilyIncidents` embedded section (gated on `featureIncidentReports` + hides when empty) shows the child's surfaced incidents via `familyIncidentsForSubjectProvider`; each card is a `FamilyIncidentCard` (type / date / familyNote / notified — narrative never rendered here).
- *Family messages index* — `lib/features/family/family_messages_screen.dart`. Per-child thread list. Messages now offline-first via `by_guardian` stream.
- *Share from home* — `lib/features/family/family_share_screen.dart`. `/share-home`; the TV-homework loop (docs/VISION.md 2026-06-19). A homework prompt + a child picker (when >1) + a compose field → sends via `MessageActions.send` (body tagged "📺 From home: …") so the moment lands in the child's message thread and the staff inbox. Reuses the proven guardian message-write (no new table); ships ungated (a director-set homework assignment + a synced toggle is a later slice).
- *Message thread screen* — `lib/features/messages/message_thread_screen.dart` (cross-feature — see Messages).
- *Family providers* — `lib/features/family/family_providers.dart`. Six `FutureProvider.autoDispose` PostgREST-backed providers: `familyChildrenProvider`, `familySubjectByIdProvider`, `familyAttendanceForSubjectProvider`, `familyEntriesForSubjectProvider`, `familyAttachmentsForEntityProvider`, `familyIncidentsForSubjectProvider`. All gate on `viewer is GuardianViewer` + `viewer.canSeeSubject(subjectId)`. `familyIncidentsForSubjectProvider` calls the server-stripping RPC `app.family_incidents_for_subject` — the narrative and action_taken are nulled in Postgres before reaching the device. Replaces the prior Drift reads for per-subject data that the `by_space` stream never delivers to guardian devices.
- *First-day welcome PDF* — `lib/features/family/welcome_pdf.dart` + `welcome_actions.dart`. `buildWelcomePdf(programName:, childFirstName:, facts:, worldName:, dinnerQuestion:, inviteUrl:, inviteCode:)` builds an offline-safe Letter PDF (built-in Helvetica — NOT `PdfGoogleFonts`; see CLAUDE.md gotcha) — program name header, "big idea" intro, this week's world + dinner question, facts (room, pickup time), guardian-app invite QR (generated on the fly via `InviteActions.createGuardianInvite` with a 30-day expiry; if that fails, the page prints without the QR). `generateFirstDayWelcome(context, ref, subjectId)` is the staff-callable action — auto-fills all fields from app data and hands the bytes to the OS print sheet via `Printing.layoutPdf`. No route; surfaced as an `EdgeAction` labelled "First-day welcome" in `subject_detail_screen.dart` (gated `viewer is! GuardianViewer`).
**Depends on**: Subjects (PostgREST), Guardians, Messages (offline-first via `by_guardian`), Settings (shared text-size sheet), Exports (received-reports card reads `myReceivedExportsProvider`), Incidents (`Incident` model + `FamilyIncidentCard` imported for the surfaced-incidents section), Invites (guardian invite creation for QR in welcome PDF), Action Words (`currentWorldProvider` for welcome PDF facts).
**Consumed by**: Nothing — this is a leaf lens.
**Last verified**: 2026-07-13

---

## GameContent
**Path**: `lib/features/game_content/`
**Purpose**: The staff-authored picture library — upload, name, and remove your own photos, and "Reveal the Picture" plays them (single-device + cast).
**Personas served**: All staff (author the library); the whole room plays the game seeded from it.
**Discovery surfaces**:
- Routes: `/games/pictures`
- Omnibox: yes — "Game pictures" (page category; keywords: pictures, photos, reveal the picture, grid game, upload pictures, custom pictures, game content)
- Slash: none
- Drawer: no
- Settings: yes — "Game pictures" row in the Resources group
**Capabilities**: None — open to all signed-in members. Space-scoped: any staffer in the space can add / rename / remove its pictures.
**Data**: [content_items](SCHEMA.md#content_items) (`kind='picture'`, `payload={image,label}` — rides the content bank, no new table). Bytes live in the private `person-photos` bucket (binary-media rule): the row carries only the Storage path, or a `pending:<id>` token while an offline upload waits; renders via signed URLs.
**Surfaces**:
- *Picture library* — `lib/features/game_content/picture_library_screen.dart`. Camera-or-gallery upload → name → grid of the space's pictures; tap to rename or remove; pending shots show an "uploading…" state.
- *Model + providers* — `lib/features/game_content/custom_pictures.dart`. `CustomPicture`, `customPicturesProvider` (Drift watch on the bank, newest first), `gridMixEmojiProvider` (per-device toggle: mix the 28 built-in emoji in with the space's pictures; ON by default).
**Depends on**: Photos (`PhotoService` upload + offline queue, signed-URL render), the content bank (`ContentBankDao`).
**Consumed by**: the grid-reveal game (`lib/features/games/games/grid_reveal_screen.dart`) — "Reveal the Picture" seeds from the library, single-device + cast.
**Last verified**: 2026-07-04

---

## Groups
**Path**: `lib/features/groups/`
**Purpose**: Classrooms / cohorts. Roster, age band, capabilities, staffing.
**Personas served**: Maya (creates + assigns staff), All staff (read their assigned cohorts).
**Discovery surfaces**:
- Routes: `/groups/new`, `/groups/:id`, `/groups/:id/edit`
- Omnibox: yes — "{Group.name}" (per cohort, classroom category), "Add a {group label}" (action, gated by `can_manage_space`)
- Slash: none directly; group resolution underpins `/attendance {group}` and `/log {kid}`
- Drawer: no
- Settings: no — groups are top-level
**Capabilities**: Read: all members of the space. Write (create / edit): `can_manage_space`.
**Data**: [groups](SCHEMA.md#groups), [group_members](SCHEMA.md#group_members), [subjects](SCHEMA.md#subjects)
**Surfaces**:
- *Group detail* — `lib/features/groups/group_detail_screen.dart`. Roster, today's activity, attendance shortcut, observations shortcut.
- *Group edit* — `lib/features/groups/group_edit_screen.dart`. Create / update form (name, age band, capabilities).
**Depends on**: Members (staff assignment), Subjects (enrollment).
**Consumed by**: Attendance, Entries, Schedule, Subjects, Today (per-cohort cards).
**Last verified**: 2026-05-21

---

## Guardians
**Path**: `lib/features/guardians/`
**Purpose**: Parent / family contact records. Distinct from Members (who are staff).
**Personas served**: Maya (manages roster), Lauren / Devon / Helen / Marcus (are guardians, read their own).
**Discovery surfaces**:
- Routes: none — embedded in Subject detail
- Omnibox: no
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: Read: `can_observe` (sees the contact list). Write: `can_manage_space`.
**Data**: [guardians](SCHEMA.md#guardians), [subject_guardians](SCHEMA.md#subject_guardians)
**Surfaces**:
- *Guardian section in Subject detail* — embedded in `lib/features/subjects/subject_detail_screen.dart`. Per-subject list of linked parents; add / remove / set primary.
**Status**: data-layer feature folder; no top-level screen.
**Depends on**: Subjects.
**Consumed by**: Exports (recipients), Messages (thread participants), Pickup (authorized people).
**Last verified**: 2026-05-21

---

## Heroes
**Path**: `lib/features/heroes/`
**Purpose**: Kids build a make-believe alter-ego — an animal with a skin, super powers, a "[Name] of [From]" title, and a drawing they name — that becomes a keepsake Hero card; those cards collect into a program-wide deck with a battle game and a print-and-color PDF sheet (docs/VISION.md 2026-06-19; the creative twin of "Do It").
**Personas served**: Ava (the child who builds it), All staff (launch it with the room / scribe the name / host the battle).
**Discovery surfaces**:
- Routes: `/heroes` (hub — roster of every child's Hero card / "make one" prompt), `/subjects/:id/hero` (the per-child creator; `extra` = display name), `/deck` (role deck — every child's collectible card in one place; "Deck" action icon on the hub), `/deck/play` (role battle game — two cards face off, room judges; "Play a battle" action icon on the deck). All four routes always resolve; only the surfaces below are discovery-gated.
- Omnibox: `page.heroes` ("Heroes" — keywords: hero / alter ego / super power / pretend / draw). **Toggle-gated** — present only when `heroesEnabledProvider` is on, and guardian-gated off. `page.deck` ("The deck" — keywords: deck / cards / collectible / collection / role cards / trading cards / play). Same toggle + guardian gate.
- Slash: none (a static slash list can't honor the toggle).
- Drawer: no — reached via the Brain Breaks deck's "Heroes" card (slotted in after Do It when the toggle is on), the omnibox, or the "Deck" action on the hub.
- Settings: yes — "Heroes activity" switch in Preferences (`_HeroesTile`, off by default).
**Capabilities**: None — open to all signed-in staff once the director switches the activity on.
**Data**: [entries](SCHEMA.md#entries) (`kind='hero'` — one upserted row per child; `details` = denormalized `{animal, skin, powers[], name, from, drawing_name?}` snapshot via `EntryActions.recordHero`; read via `heroForSubjectProvider` + `heroesInSpaceProvider`), [attachments](SCHEMA.md#attachments) (the optional drawing photo, offline-safe pinned-id upload). Catalog (animals/skins/powers/origins) is bundled Dart in `hero_catalog.dart`, not a synced table. Role deck + battle game read the same hero entries — no new table.
**Surfaces**:
- *Heroes hub* — `lib/features/heroes/heroes_hub_screen.dart`. `/heroes` lists every visible child (`subjectsInSpaceProvider`); each shows their Hero card (tap to evolve) or a "make one" prompt. Top-right "Deck" icon (`Icons.style_outlined`) → `/deck`. Loading / empty / error states.
- *Hero creator* — `lib/features/heroes/hero_creator_screen.dart`. Teacher-paced build form with a live `HeroCard` preview: animal grid, skin + origin ChoiceChips, powers FilterChips (max 3), a name TextField, and an optional snap+name drawing (proven photo path, camera hidden on web). `DismissGuard`; saves via `recordHero`.
- *Hero card* — `lib/features/heroes/widgets/hero_card.dart`. The reusable keepsake render (animal+skin, title, power chips, drawing via `PersonPhotoNetwork` → `PhotoViewer`). Used by the hub + the creator preview.
- *Role deck* — `lib/features/heroes/role_deck_screen.dart`. `/deck`; every child's role as a `CollectibleRoleCard` in a 2-column wrap (`heroesInSpaceProvider`). Tap a card → `/subjects/:id/hero`. Top-right actions: "Print the deck" (triggers `_printDeck` → `buildRoleDeckPdf` → `Printing.layoutPdf`) and "Play a battle" (→ `/deck/play`). Empty state when no cards exist; error + loading states.
- *Role battle* — `lib/features/heroes/role_game_screen.dart`. `/deck/play`; host-present card game: draws a random pair from `heroesInSpaceProvider` (salt-seeded so a mid-game sync doesn't reshuffle), stacks two `CollectibleRoleCard` widgets in a scrollable column, "Next battle" refills with a new pair via `setState(() => _salt++)`. No scoring; the room talk IS the play. Empty state when fewer than 2 cards exist.
- *Role deck PDF* — `lib/features/heroes/role_deck_pdf.dart`. `buildRoleDeckPdf({cards})` — pure async function; offline Helvetica (no `PdfGoogleFonts`), 6 cards per Letter page. Called by the deck's "Print" action; not a screen.
- *Collectible role card* — `lib/features/heroes/widgets/collectible_role_card.dart`. `CollectibleRoleCard` — the printable/display card format (distinct from `HeroCard` which shows the drawing). Used by deck + battle.
- *Catalog + models* — `lib/features/heroes/hero_catalog.dart`. `HeroPick` + curated pick-lists + `HeroDraft` (→ details JSON) + `HeroCardData` (tolerant parse).
- *Read providers* — `lib/features/heroes/heroes_providers.dart`. `heroForSubjectProvider` (per-child, Drift-watched, offline-first), `heroesInSpaceProvider` (space-wide `List<DeckCard>`, used by deck + battle).
- *Toggle* — `lib/features/heroes/heroes_setting.dart`. `heroesEnabledProvider`, default off.
**Depends on**: Entries (`recordHero`), Subjects (roster), Photos (drawing via `uploadOnly` + `PersonPhotoNetwork`).
**Consumed by**: ActivityRuntime (Brain Breaks deck injects the Heroes card), Omnibox (`page.heroes` + `page.deck`), Settings (`_HeroesTile`).
**Last verified**: 2026-06-19

---

## Incidents
**Path**: `lib/features/incidents/`
**Purpose**: Structured, first-class incident logging — a bump, conflict, illness, or medical event captured as a typed, child-scoped, family-notification-tracked compliance record, distinct from a free-text observation (docs/WORKFLOWS.md gap #3).
**Personas served**: All daily-logging staff (log + read their cohorts), Maya / director (reads all; enables the feature), Jordan (the "noticed X / it happened" capture).
**Discovery surfaces**:
- Routes: `/incidents` (the log) + `/incidents/new` (the form; optional `?subjectId=` to pre-select a child)
- Omnibox: `page.incidents` — "Incident log" + `action.log-incident` — "Log an incident" (both gated on `feature_incident_reports` + staff who can log/manage; keywords: incident, injury, accident, report, safety, bump, conflict)
- Slash: none
- Drawer: no — reached via omnibox + subject-detail jump chip (`SubjectIncidentsSection` → "Log incident")
- Settings: yes — "Incident reports" (`CapSwitch`, auto-save) under the "What's tracked" section of `program_settings_screen.dart`; gated `canManageSpace`
**Capabilities**: Gated on space cap `feature_incident_reports` (default on). Log: `can_observe`. View: `can_observe` OR `can_manage_space` (director). Visibility scoped to the viewer's cohorts (directors see all), same shape as observations.
**Data**: Reuses [entries](SCHEMA.md#entries) `kind='incident'` — `text`=narrative, `details` JSON = `{incident_type, action_taken?, parent_notified, family_note?}`. [subjects](SCHEMA.md#subjects) — read by the log screen (`subjectsInSpaceProvider`) to resolve child identity on each card. NO new table / sync-rule change. New migration `20260606000002_family_incidents_rpc.sql` adds `app.family_incidents_for_subject(caller_uid, p_subject_id)` — a SECURITY DEFINER RPC that strips `text`/`photo_url`/`action_taken` server-side before returning rows to guardian devices.
**Surfaces**:
- *Incident log* — `incidents_screen.dart`. Every incident the viewer can see, newest first; stateful All / Needs-follow-up filter (incidents where `parent_notified` is false) with a live count chip; each row = child + type chip + relative time + narrative + action-taken + family-notified badge. All-notified celebratory note when the filter result is empty. Top-right `ios_share` icon builds and shares a compliance PDF of the filtered view.
- *Incident form* — `incident_form_screen.dart`. Child picker, type chips (injury / conflict / behavior / illness / medical / other), narrative, action-taken, optional family note (`family_note`), family-notified toggle, dirty-state discard guard.
- *Incident providers* — `incidents_providers.dart`. `IncidentType` catalog, `Incident` model (gains `familyNote` + `familyVisible` = `parentNotified || familyNote != null`), `Incident.fromEntry`, `incidentsInSpaceProvider` + `incidentsForSubjectProvider`, `incidentDetailsJson` builder (writes `family_note` key), `IncidentActions.setParentNotified` (carries `familyNote` through on amend).
- *Incident card* — `widgets/incident_card.dart`. `IncidentCard`, the shared staff-facing card (log + per-child section; `showSubjectName` toggles the identity header).
- *Per-child incident history* — `widgets/subject_incidents_section.dart`. `SubjectIncidentsSection`, the staff-side per-child history + scoped "Log incident" action embedded in Subject detail.
- *Family incident card* — `widgets/family_incident_card.dart`. `FamilyIncidentCard` — leak-proof by construction: renders type / date / `familyNote` / notified badge only; deliberately never reads `narrative` or `actionTaken`.
- *Compliance PDF* — `templates/incident_report.dart`. `buildIncidentReportPdf`, built-in Helvetica, offline-safe (no `PdfGoogleFonts` call). Shared via `Printing.sharePdf`.
- *Create path* — `EntryActions.createIncident` (`lib/features/entries/entries_providers.dart`). Carries `family_note` in the `details` JSON.
**Status**: shipped — v1 + family-facing wave (log + structured form + family-notified tracking + "Mark notified" amend + Needs-follow-up filter + per-child history on Subject detail + PDF export + family_note field + server-side stripping RPC + FamilyIncidentCard embedded in Family subject detail). Deferred: incident photos; a Unicode font for the PDF (shared with progress reports — Helvetica drops accented glyphs).
**Depends on**: Entries, Subjects, Groups, Viewer (capabilities).
**Consumed by**: Subject detail — per-child incident history (`SubjectIncidentsSection`, gated section + jump chip); Family — guardian-facing surfaced incidents via `familyIncidentsForSubjectProvider` (reads the stripping RPC).
**Last verified**: 2026-06-06

---

## Insights
**Path**: `lib/features/insights/`
**Purpose**: System-derived questions from patterns — expiring certs, late streaks, stale vehicles, unwritten observations, low-signal surveys.
**Personas served**: Maya (director-tier oversight). All staff with `can_observe` see the surface.
**Discovery surfaces**:
- Routes: `/insights`
- Omnibox: yes — "Insights"
- Slash: `/insights`
- Drawer: yes — "Insights" (canonical nav, position between Surveys and Vehicles)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Some insights are member-scoped (only the affected staff sees them); some are space-wide.
**Data**: derived — reads [attendance_records](SCHEMA.md#attendance_records), [member_certifications](SCHEMA.md#member_certifications), [vehicle_logs](SCHEMA.md#vehicle_logs), [entries](SCHEMA.md#entries), [captures](SCHEMA.md#captures), [survey_responses](SCHEMA.md#survey_responses). Snooze state in [dismissed_insights](SCHEMA.md#dismissed_insights).
**Surfaces**:
- *Insights screen* — `lib/features/insights/insights_screen.dart`. Card list; tap to drill into the underlying data; swipe to dismiss (per-member snooze).
**Depends on**: Attendance, Certifications, Vehicles, Entries, Captures, Surveys.
**Consumed by**: Today (top-N insight chip).
**Last verified**: 2026-06-01

---

## Invites
**Path**: `lib/features/invites/`
**Purpose**: Staff + guardian onboarding via 6-char invite codes (deep link + QR + share-text); cold-launch & warm-app deep links both supported.
**Personas served**: Maya (creates + revokes staff AND guardian invites), Brianna (redeems on her phone), Lauren / Devon / Helen / Marcus (redeem as guardians).
**Discovery surfaces**:
- Routes: `/settings/team/invite/new`, `/settings/team/invite/:id`
- Omnibox: yes — "Invite a teammate" (action, director-gated, routes directly to `/settings/team/invite/new`); "Invite a parent · {Child name}" (per-subject action, director-gated, routes to the subject edit screen's inline Guardians editor); "Revoke pending invite · {label}" (per-pending-invite action, director-gated, undo-safe: snapshot + `InviteActions.revoke` + 6 s Undo snackbar, restore re-inserts same row). Keyword aliases: parent, family, mom, dad, guardian, revoke, cancel, pending
- Slash: none
- Drawer: no
- Settings: no — embedded in Team / Subject detail
**Capabilities**: Create / revoke staff: `can_invite_staff`. Create guardian invites: `can_manage_space`. Redeem: pre-auth or post-auth without an active space; the RPC takes an explicit `caller_uid` to work around the ES256 auth.uid()-null gotcha (see migration 20260523000003).
**Data**: [invites](SCHEMA.md#invites)
**Surfaces**:
- *Invite create screen* — `lib/features/invites/invite_create_screen.dart`. Role + optional email + expiry chips.
- *Invite share screen* — `lib/features/invites/invite_share_screen.dart`. The created code; copy / QR / share-text.
- *Subject-edit inline Guardians editor* — embedded in `lib/features/subjects/subject_edit_screen.dart`. The Add Guardian flow mints a guardian invite for that specific kid via `createGuardianInvite`; this is the destination of the omnibox "Invite a parent" entry.
- *Deep-link listener* — `lib/features/invites/deep_link_listener.dart`. Captures `differentworld://invite/<code>` and the https fallback into `pendingInviteCodeProvider`; consumed by `home_redeem_invite_host.dart`.
**Depends on**: Members (assigning role), Spaces, Subjects (guardian invites need a subject_id), Guardians (guardian invites create + link rows).
**Consumed by**: Team screen (pending-invites list), Onboarding (redeem path), Subject detail (inline Guardians editor + invite-share navigation).
**Last verified**: 2026-07-13

---

## Kid mode
**Path**: `lib/features/kid_mode/`
**Purpose**: Locked tablet mode — hide the omnibox bar + drawer so a child user can't navigate out of a kid surface (survey-take, kid journal).
**Personas served**: Ava.
**Discovery surfaces**:
- Routes: none — feature is a flag on the shell, not a destination
- Omnibox: no — hidden when active
- Slash: none
- Drawer: no — hidden when active
- Settings: no
**Capabilities**: None — any signed-in staff can toggle when entering a kid surface.
**Data**: None — Notifier<bool> in memory.
**Surfaces**:
- *Provider* — `lib/features/kid_mode/kid_mode_provider.dart`. `kidModeProvider` (Notifier<bool>) drives AppShell visibility.
- *Exit dialog* — `lib/features/kid_mode/kid_mode_exit_dialog.dart`. `showKidModeExitDialog()` — staff-only exit affordance gated by `staff_pin` from the space's capabilities (or confirm-tap when no PIN is set).
- *Auto-enter from survey-take* — `lib/features/surveys/survey_take_screen.dart` enters in `initState`, exits in `dispose`; calls the exit dialog before allowing system-back to leave the screen.
**Status**: PARTIAL. Mechanism + staff-only exit dialog shipped. Kid-journal feature itself + drawer suppression hardening still deferred.
**Depends on**: AppShell.
**Consumed by**: Surveys (auto-enter + exit dialog), future Kid journal.
**Last verified**: 2026-05-22

---

## LiveSession
**Path**: `lib/features/live_session/`
**Purpose**: Phone-as-remote / screen-as-presentation mode for host-run brain-break games (This-or-That, Charades) and the anonymous Brainstorm Board — one device presents on a projector while others control or post over Supabase Realtime.
**Personas served**: All staff (any teacher running a game on a big screen with their phone as the remote; any meeting facilitator posting anonymously).
**Discovery surfaces**:
- Routes: `/live/<game>` for every framework game (`this-or-that`, `charades`, `poll`, `cues`, `rhyme-time`, `starts-with`, `as-if`, `story`, `math-game`, `picker`, `now-next`) → `LiveGameScreen(def:)`; `/board` (BoardScreen); `/join?code=<CODE>&game=<ID>` → `LiveGameScreen(autoJoin:)` — the "one place to join" path, resolves the game from the session id so the joiner never picks; `/present` (PresentHubScreen) and `/present/<game>` for single-device `GameRunner` variants (poll, cues, picker, now-next); `/cast` (CastScreen — the caster/receiver lobby: cast to your screens or make this device a room screen).
- Omnibox: yes — "Brainstorm Board" (`page.board`, keywords: board, brainstorm, meeting, agenda, ideas, anonymous) → `/board`; "Present to the room" (`page.present`, keywords: present, cast, big screen, projector, room, remote, classroom remote, tv) → `/present`; "Cast to a screen" (`page.cast`, gated `viewer is! GuardianViewer`, keywords: cast, remote, control, screen, projector, tv, present from phone, phone remote) → `/cast`. No direct catalog entries for `/live/this-or-that` or `/live/charades` — those are reached via the Quick Picks screen action and via slash commands respectively.
- Slash: `/live` (alias: `session`) → `/live/this-or-that`; `/present` (aliases: `cast`, `room`, `screen`, `projector`, `remote`) → `/present`; `/charades` (aliases: `act`, `acting`, `mime`, `guess`) → `/live/charades`; `/board` (aliases: `brainstorm`, `meeting`, `agenda`, `ideas`) → `/board`
- Drawer: yes — "Brainstorm Board" for `/board` (canonical nav, position between Missions and Insights); "Present" for `/present` (canonical nav, Activities group, position between Tools and Brain Breaks). `/live/this-or-that` and `/live/charades` have no drawer entry — those remain reached via the Brain Breaks deck and slash commands.
- Settings: no
**Capabilities**: None — open to all signed-in staff.
**Data**: None persisted. Uses Supabase Realtime broadcast + presence — a documented ephemeral-coordination exception (same class as auth and Storage). This-or-That + Charades use channel `dw-session-<CODE>`; Board uses `dw-board-<CODE>`. No Drift tables, no PowerSync sync, no migration.
**Surfaces**:
- *Program lobby* — `lib/features/live_session/live_lobby.dart`. `LobbyAnnouncer` (presenter side: tracks `{code, game, presenter}` on `dw-live-<spaceId>`) + `LobbyWatcher` (watcher side: streams `List<LiveSessionAd>` from presence; subscribe-only, never tracks). Entirely ephemeral Realtime — no durable rows, no PowerSync.
- *Lobby providers* — `lib/features/live_session/live_lobby_providers.dart`. `activeSessionsProvider` (StreamProvider.autoDispose): opens a `LobbyWatcher` for the current space and streams live session ads; tears down on dispose. Drives the Today banner.
- *Today live-session banner* — `lib/features/live_session/live_session_banner.dart`. `LiveSessionBanner` (ConsumerWidget): renders a `primaryContainer` tap-to-join card at the top of Today when `activeSessionsProvider` has at least one session; auto-hidden when empty. Single session → direct `/join?code=…&game=…` push; multiple sessions → `showGlassSheet` picker. Mounted in `lib/features/today/widgets/today_sections.dart`.
- *Generic live screen* — `lib/features/live_session/live_game_screen.dart`. **THE one live UI for every `GameDefinition`** (This-or-That, Charades, Poll, Cues, Rhyme Time, Letter Words, As-If, Story, Math Game, Spotlight, Now & Next): lobby (Present / Join, + "I'm acting" when `def.hasSecretRole`), presenter view (`buildStage`), secret view (`buildSecretStage` — the actor), controller view (sees `buildSecretStage ?? buildStage` + `buildControls`/the intent bar). `autoJoin` param: when set (`{code, role}`), skips the lobby and enters as a controller immediately — used by the `/join` route so the banner's one-tap join works. Presenter auto-announces to `LobbyAnnouncer` on `_open`; tears down on `_leave`/`dispose`. Charades is no longer a bespoke screen — it's `games/games/charades_game.dart` (a `GameDefinition` with `hasSecretRole`/`buildSecretStage`); `charades_live_screen.dart` + `charades.dart` were DELETED. `DataSeededGame` (`games/data_seeded_game.dart`) wraps the live-vs-runner branch for Drift-seeded games (Spotlight, Now & Next).
- *LiveSession / SessionRole / LiveReducer / LiveStatus* — `lib/features/live_session/live_session.dart`. Game-agnostic protocol layer: wraps a Supabase Realtime channel; supports `SessionRole.{present, control, secret}`. Each game injects its reducer via `LiveGameController`.
- *Generic live screen* — `lib/features/live_session/live_game_screen.dart`. **THE one live UI for every `GameDefinition`** (This-or-That, Charades, Poll, Cues, Rhyme Time, Letter Words, As-If, Story, Math Game, Spotlight, Now & Next): lobby (Present / Join, + "I'm acting" when `def.hasSecretRole`), presenter view (`buildStage`), secret view (`buildSecretStage` — the actor), controller view (sees `buildSecretStage ?? buildStage` + `buildControls`/the intent bar). Charades is no longer a bespoke screen — it's `games/games/charades_game.dart` (a `GameDefinition` with `hasSecretRole`/`buildSecretStage`); `charades_live_screen.dart` + `charades.dart` were DELETED. `DataSeededGame` (`games/data_seeded_game.dart`) wraps the live-vs-runner branch for Drift-seeded games (Spotlight, Now & Next).
- *Board session* — `lib/features/live_session/board_session.dart`. `BoardSession` over Realtime channel `dw-board-<CODE>`; broadcasts `idea` events with no sender identity (anonymous by design); append-only wall; presence for participant count.
- *Board screen* — `lib/features/live_session/board_screen.dart`. Theme-adaptive lobby (Brainstorm Board header + item-type legend chips + "Start the document" card + "Join to contribute" code-entry card) → dark presentation stage (presenter wall, all items tiled by kind) or contributor post-field (phone keyboard, kind-selector chips, tap to send). Routes to `/board`. Realizes VISION.md dream #5 (anonymous collective voice in a meeting).
- *Cast screen* — `lib/features/live_session/cast_screen.dart`. Theme-adaptive lobby with two paths: (1) "Cast to your screens" (`_BigCard` — broadcasts on the controller's own code so every following room screen shows what the caster picks); (2) "Be a screen" (`_BeAScreenCard` — merged card: one-tap "Follow my screens" button when a controller code is available, plus a manual 6-char code-entry field for following a different controller). `presentAsScreen: true` param (from `?role=screen`) skips the lobby and auto-enters receiver mode on the program channel. Routes to `/cast`. Uses `CastImmersive` to suppress AppShell chrome while casting or receiving.
- *Entry action on Quick Picks* — `lib/features/activity_runtime/this_or_that_screen.dart`. `SecondaryActionButton` (cast icon, tooltip "Present on a big screen") → `context.push('/live/this-or-that')`. Primary discovery path for the This-or-That live session.
- *Brain Breaks deck card* — `lib/features/activity_runtime/brain_breaks_screen.dart`. "Charades" card → `/live/charades`.
**Depends on**: ActivityRuntime (`content_bank.dart` — seeds This-or-That pairs and the 24 Charades prompts via `ContentKind.charades`); Games (`game_registry.dart` — `gameById` resolves game ids in the `/join` route and in `LiveSessionBanner._gameName`).
**Consumed by**: Today (`live_session_banner.dart` mounted in `today_sections.dart`; `activeSessionsProvider` drives the banner); LiveBoard (imports `CastSession` + `generateSessionCode` from this feature's cast spine).
**Last verified**: 2026-06-18

---

## LiveBoard
**Path**: `lib/features/live_board/`
**Purpose**: The phone as a live classroom instrument — the teacher types or picks, and every joined room screen updates in real time with a big auto-fit render (six instruments: Big Word, Spell-for-me, Count-together, Whose-turn, Reveal one-at-a-time, Sound-it-out).
**Personas served**: Maya, Jordan, Coach Sam, Brianna, Pat (all daily-logging staff roles; `roleToolsFor` includes Live Board in the lead-teacher, teacher, and specialist palettes).
**Discovery surfaces**:
- Routes: `/live-board` → `LiveBoardScreen`
- Omnibox: yes — `present.live-board` ("Live Board", gated `viewer is! GuardianViewer`; keywords: live board, board, big word, spell, spell for me, instrument, highlight word, show on screen, present word) → `/live-board`
- Slash: none
- Drawer: no — reached via Present hub (`/present`), which is a canonical nav destination
- Settings: no
**Capabilities**: Staff-only (`viewer is! GuardianViewer` gate in omnibox catalog; no explicit cap key beyond being a signed-in non-guardian).
**Data**: None — ephemeral Realtime broadcast only. No synced tables, no Drift writes, no PowerSync involvement (same class as the cast spine it rides).
**Surfaces**:
- *LiveBoardScreen* — `lib/features/live_board/live_board_screen.dart`. The caster: shows a join code, a live peer count, a 16:9 preview of what the room sees, and a segmented instrument switcher for all six instruments. Big Word (`BoardInstrument.word`): one `TextField`; every keystroke re-broadcasts. Spell-for-me (`BoardInstrument.spell`): horizontal avatar row from `subjectsInSpaceProvider` (tap to pick) or a name text field, plus a word field; broadcasts both. Count-together (`BoardInstrument.number`): tap +/− to drive a shared count + optional label; the room counts along. Whose-turn (`BoardInstrument.turn`): subject roster for fair-turn picking; big avatar + "{name}'s turn" on the room screen. Reveal one-at-a-time (`BoardInstrument.reveal`): multi-line text field; "Reveal next" taps expose one line at a time on the room screen. Sound-it-out (`BoardInstrument.sound`): a hyphen/middot-delimited word is split into phoneme chunks; each tap lights the next chunk. Owns one `CastSession.cast(code)` (created in `initState`, disposed in `dispose`); all stream listeners guard `mounted`. Enables wakelock on mount, disables on dispose.
- *BoardGame* — `lib/features/live_board/board_game.dart`. A cast-only `GameDefinition<BoardState>` with `gameId = 'board'`. Registered in `game_registry.dart` so the existing cast receiver (`cast_receiver.dart`) renders it for free with no receiver changes. `buildStage` switches on `BoardInstrument` (idle / word / spell / number / turn / reveal / sound). All six instrument stages auto-fit via `FittedBox` — the design law. The reducer is a no-op (the caster re-casts the full `BoardState` on every edit). `seedsFromContentBank = false` so it stays out of the standard game launcher.
- *Present hub card* — `_PresentCard('Live Board', route: '/live-board')` in `lib/features/games/present_hub_screen.dart`. One of seven cards on the `/present` hub grid; the primary visual entry point for the feature.
**Depends on**: LiveSession (cast spine — `CastSession` from `lib/features/live_session/cast_session.dart`; `generateSessionCode` from `lib/features/live_session/live_game_screen.dart`), Games (`game_registry.dart` — `BoardGame` is registered there so the receiver can resolve it by id), Subjects (`subjectsInSpaceProvider` — Spell-for-me + Whose-turn avatar pickers read the enrolled roster).
**Consumed by**: LiveSession (cast receiver resolves `BoardGame` via `gameById('board')` in `game_registry.dart` and calls `buildStage` on it); Drawer (`role_tools.dart` — `_liveBoard` `RoleTool` links `/live-board`; surfaced in the drawer's "Your tools" section via `tunedToolsFor()` for lead-teacher, teacher, specialist roles; previously in `YourToolsStrip` on Today, moved in the briefing reorg).
**Last verified**: 2026-06-15

---

## Messages
**Path**: `lib/features/messages/`
**Purpose**: Staff↔Guardian per-child thread. Async written communication.
**Personas served**: All staff (write to family), Lauren / Devon / Helen / Marcus (receive + reply).
**Discovery surfaces**:
- Routes: `/messages`, `/messages/:subjectId/:guardianId`
- Omnibox: yes — "Messages" (gated by guardian-with-children — guardian-side page entry). Staff side: per-subject "Messages · {Child name}" action (gated by `can_observe`, routes to subject detail where the per-thread navigation lives). Keyword aliases: message, chat, family, parent, mom, dad, guardian.
- Slash: none
- Drawer: no — guardians may eventually get a dedicated drawer entry
- Settings: no
**Capabilities**: Staff: `can_observe` (gates "can talk to a family"). Guardian: linked to subject via [subject_guardians](SCHEMA.md#subject_guardians).
**Data**: [messages](SCHEMA.md#messages)
**Surfaces**:
- *Message thread screen* — `lib/features/messages/message_thread_screen.dart`. One thread per (subject, guardian); newest-at-bottom, send composer at bottom.
- *Family messages index* — `lib/features/family/family_messages_screen.dart` (cross-feature). Guardian's view of all their threads.
**Depends on**: Subjects, Guardians.
**Consumed by**: Family lens (Lauren), Today (unread-messages chip — not yet wired).
**Last verified**: 2026-05-21

---

## Omnibox
**Path**: `lib/features/omnibox/`
**Purpose**: The persistent bottom composer — search / capture / slash command / voice. The spine of the app's interaction model. In capture mode a schedulable phrase is offered as a *drafted schedule block* (the "omnibox composes" middle-UI move — intent in, structure out, you confirm).
**Personas served**: All staff.
**Discovery surfaces**:
- Routes: `/search` (OmniboxSearchScreen)
- Omnibox: this IS the omnibox — its own catalog is the schema for every other feature's discovery
- Slash: this IS the slash dispatcher
- Drawer: yes — a "Search anything" tile at the top of the drawer mirrors the bar
- Settings: no
**Capabilities**: None — visible to all signed-in members, hidden in kid mode.
**Data**: None directly. Reads providers for catalog (groups, subjects, activities, locations, vehicles, members). Persists pinned + recent IDs in SharedPreferences.
**Surfaces**:
- *Bottom omnibox bar* — `lib/features/omnibox/bottom_omnibox_bar.dart`. The persistent composer in AppShell.
- *Omnibox search screen* — `lib/features/omnibox/omnibox_search_screen.dart`. The suggestion / results list at `/search`. Wave 24 (2026-05-22) hardening: dispatch context is captured via `Navigator.of(context, rootNavigator: true).context` BEFORE `context.pop()` so the post-pop `onSelect` / `runSlash` / "see all inbox" callbacks fire against a live BuildContext rather than the screen's own (which deactivates the instant pop runs). Fixes the "tap a suggestion, nothing happens" bug.
- *Omnibox catalog* — `lib/features/omnibox/omnibox_results.dart` + `omnibox_catalog.dart`. Source of all OmniboxEntry rows. Subjects whose `groupId` is null are filtered out at the catalog layer (the subject-detail route is nested under cohort — there's nowhere for a no-cohort subject to navigate to). "If the user can't do it, don't show it" invariant.
- *Slash commands* — `lib/features/omnibox/slash_commands.dart`. The `/today`, `/captures`, `/log {kid}`, etc. dispatch table.
- *Compose-to-draft* ("omnibox composes") — `lib/features/omnibox/compose_intent.dart` (pure, rules-based parser: kind + when + title, no LLM) + `compose_draft_seed.dart` (a `Notifier` courier for the edit path). When a capture-mode phrase reads as a schedule intent ("field trip to the pond Friday", "art tomorrow at 2", "closed Friday"), a `_ComposeDraftCard` appears ABOVE the note fallback showing the parsed structure as chips. **Primary "Add to schedule"** (or Return) creates a complete, named block (title + kind + parsed day/time, +60 min) straight onto the cohort's day and shows an **Undo** snackbar — no form in between (the card already showed the parse, so the tap IS the confirm; a `_adding` latch hard-guards double-create). **Secondary "Edit details first"** opens `BlockEditScreen` pre-filled (via the seed) for activity / lead / location. Multi-cohort shows a picker chip (no silent first-cohort binding); the whole card is **gated on `canManageSchedule`** (same as the schedule's "+ Block"). Additive: the note fallback (`_CaptureHeroCard`, demoted to a `muted` variant) never goes away. Parser covered by `test/unit/compose_intent_test.dart` (20 cases). Known edge: undo within the 5 s window after separately editing the block deletes the edited row (standard undo-snackbar limitation); an explicit "today {past time}" lands in the past by design (retroactive logging).
**Interaction invariants (Wave 24, 2026-05-22)**:
- *Push on focus, not on keystroke.* AppShell's bar focus listener pushes `/search` the moment the bar gains focus (tap → suggestion panel + keyboard + cursor land together). Typing does NOT trigger a push — by the time `_onQueryChanged` fires, `/search` is already on top from the focus event. Single source of truth for "is the search route open?" is `_focus.hasFocus` plus the in-flight push lock.
- *Lock held for /search lifetime.* `_pushingSearch` is set true on push, released when `context.push('/search').then(...)` resolves (i.e. when the route pops). Holding the lock across the route's full lifetime — not just one frame — means rapid re-focus events can never stack duplicate `/search` routes. At-most-one `/search` in the navigator stack, regardless of typing/tap cadence.
- *Re-grant focus + force IME show on rotation.* The push briefly rotates the FocusScope's active node off the bar, which on Android dismisses the soft keyboard. If focus loss lands within 500ms of the most recent push (`_lastPushAt`), AppShell calls `_focus.requestFocus()` + `SystemChannels.textInput.invokeMethod('TextInput.show')` to keep the IME up. Older intentional taps-outside (>500ms) are left alone.
- *Canonical widget test* — `test/widget/omnibox_interaction_test.dart` exercises tap-→-push-→-IME-up-→-type-→-suggestion-tap-→-dispatch end-to-end. The `interaction-guard` agent + `~/.claude/hooks/interaction-stop-gate.sh` stop-hook enforce that any change in `app_shell.dart` / `omnibox_search_screen.dart` / `bottom_omnibox_bar.dart` triggers a re-run of this test. CLAUDE.md "Interaction invariants" section is the durable contract.
**Depends on**: Every feature (catalog references their routes); Voice (mic), Captures (capture mode submits here), Schedule (substitute-lead sheet invoked from "Cover today · {Group}").
**Consumed by**: AppShell (mounts the bar + listens for focus).
**Last verified**: 2026-05-22

---

## Onboarding
**Path**: `lib/features/onboarding/`
**Purpose**: Post-auth, pre-space flow (join or create) PLUS the first-run starter spine on Today — day one proving the app instead of touring it (docs/BRAND.md "undeniable" onboarding). PLUS **starting simple** (docs/STARTING_SIMPLE.md) — the nav trimmed to three destinations for someone who joined a program they did not create, so 21 destinations are not the first thing a new teacher meets.
**Personas served**: Brianna (joining), Maya (creating + the day-one spine), Jordan (teacher welcome card).
**Discovery surfaces**:
- Routes: `/onboarding/join-or-create` (and any sub-routes); the spine renders on `/` (Today) — no route of its own
- Omnibox: no — pre-space / first-run surfaces
- Slash: none
- Drawer: no — drawer only mounts after space is selected
- Settings: yes — Preferences → "Start simple" (the trim's off switch; it is ADOPTED at invite redemption, never discovered here)
**Capabilities**: Spine full form requires `can_manage_space`; other staff get the one-card welcome. State keys: `SpaceCaps.onboarding*` (synced) + a per-device teacher-welcome flag.
**Data**: [spaces](SCHEMA.md#spaces) (capabilities JSON carries spine state), [members](SCHEMA.md#members), [invites](SCHEMA.md#invites), [subjects](SCHEMA.md#subjects) + [entries](SCHEMA.md#entries) (the seeded sample child)
**Surfaces**:
- *Starting simple* — `lib/features/settings/starting_simple_setting.dart` + `lib/features/settings/widgets/starting_simple_note.dart`. Trims `buildNavDestinations` to Today / Observations / Captures + Settings. Adopted by `InviteActions.redeem` (the one moment a newcomer is certain), never by inference; `adoptForNewcomer` writes only when the preference is unset so a second redemption cannot override a choice. Removes NOTHING — the omnibox catalogue is independent of the nav list, so all 116 entries stay searchable and every route stays deep-linkable. `StartingSimpleNote` on Today explains the short menu once, because otherwise it reads as a broken install.
- *Join-or-create screen* — `lib/features/onboarding/join_or_create_screen.dart`. Two paths: enter an invite code, or create a new program. Pushes Create when the user chooses to start fresh.
- *Create space screen* — `lib/features/onboarding/create_space_screen.dart`. Bare-minimum form (program name + vertical). Inserts the `spaces` row + flips the current member into it, then seeds Sam (the sample child).
- *Starter spine* — `lib/features/onboarding/widgets/starter_spine.dart`. Self-retiring day-one section on Today: cast a game / open the sample child's story / add the first room, then the team-invites closer. Cards collapse to check rows as they complete; "Hide setup" dismisses. Teachers get a one-card welcome instead.
- *Sample child ("Sam")* — `lib/features/onboarding/sample_child.dart`. Seeded six-week story (observations + missions) that makes the book payoff visible on day one; badged via `SubjectCaps.isSample`; removal is a cascading confirm that spares real kids (pinned by `test/unit/starter_spine_test.dart`).
**Depends on**: Invites (redeem), Auth, Today (hosts the spine), Story (the sample-story link), Games (the cast card → `/present`).
**Consumed by**: Router (post-login redirect when `viewer.spaceId == null`); Today (renders `StarterSpine` in both the empty-day-one body and `TodayBody`).
**Last verified**: 2026-07-13

---

## Photos
**Path**: `lib/features/photos/`
**Purpose**: Signed-URL minting + cached display for person photos (avatars, observation attachments), PLUS the per-child PROGRESS FOLDER — a browsable collection of one child's photos: the ones they SHOT and the ones OF them, favorites-first. Bytes live in Supabase Storage's private `person-photos` bucket; rows carry only the bucket-relative path.
**Personas served**: All staff (upload + view + curate the folder), All guardians (view their own children's folder, read-only).
**Discovery surfaces**:
- Routes: `/photos` (program-wide gallery); `/subjects/:id/photos` (`ChildPhotosFolderScreen`, RouteTitle "Photos"; nested as a sibling of `subjects/:id/day` etc.).
- Omnibox: yes — "Photos · {child}" per visible subject (keywords: photo, photos, folder, gallery, pictures, media, progress) → `/subjects/:id/photos`. Built in the per-subject loop of `omnibox_catalog.dart`; the catalog list is already viewer-scoped.
- Slash: none
- Drawer: no
- Settings: no
- Subject detail: a "Photos" `FeatureCard` (`_PhotosFolderTile`) under the identity row in BOTH the flat + bento bodies of `SubjectDetailScreen`, reactive count subtitle → `/subjects/:id/photos`.
**Capabilities**: Read via signed URL (RLS-scoped to space membership; first path segment must match caller's `members.space_id`). Write: any staff who can mutate the parent row. The folder's heart-to-favorite is a curation write gated on `viewer.canObserve` (staff only) — guardians get a read-only gallery.
**Data**: References [members](SCHEMA.md#members).`avatar_url`, [subjects](SCHEMA.md#subjects).`photo_url`, [attachments](SCHEMA.md#attachments) — none of those tables is owned by this feature. The folder reads `attachments` by `captured_by_subject_id` (Took) + `subject_id` (Of) and writes `sort_order` (the favorite flag) via `AttachmentActions.reorder`.
**Surfaces**:
- *PersonAvatar widget* — `lib/shared/widgets/person_avatar.dart`. Renders an avatar by minting a 1-hour signed URL.
- *PersonPhotoNetwork* — used by gallery + viewer sites.
- *Signed-URL provider* — `lib/features/photos/person_photo_url.dart`. `signedPersonPhotoUrlProvider` is the single mint point; handles legacy full-URL rows via `extractPersonPhotoPath`.
- *Child photos folder* — `lib/features/photos/child_photos_folder_screen.dart` (`ChildPhotosFolderScreen`). `/subjects/:id/photos`: `EdgeScaffold` + `ContentHeader` ("{Name}'s photos", subtitle "{n} photos · {m} favorites") + a "Took / Of {name}" `SegmentedButton`, a responsive `SliverGrid` (square tiles, ~168px max extent). Took = `attachmentsCapturedByCuratedProvider` (favorites-first); Of = `attachmentsForSubjectProvider` (newest-first). Tap → `PhotoViewer.open`. Per-tile heart (staff, Took lens) toggles favorite via `attachmentActions.reorder(sortOrder: 0 | 1e9)` with a `_pending` double-tap guard + favorited ring. Four states (LoadingSlot.cards / EmptyState / ErrorState+retry / data); guardian gate mirrors `SubjectDetailScreen` (`NoAccess` for a non-own child).
- *Attachments providers* — `lib/features/photos/attachments_providers.dart`. `attachmentsCapturedByProvider` (Took), `attachmentsCapturedByCuratedProvider` (Took, favorites-first), `attachmentsForSubjectProvider` (Of — added for the folder), `attachmentsForEntityProvider`, `attachmentsForBlockProvider`; `AttachmentActions` (add / updateCaption / reorder / remove).
**Depends on**: Supabase Storage client, Subjects (`subjectByIdProvider`, viewer gate), PhotoViewer.
**Consumed by**: Members, Subjects (folder link), Entries (attachment display), Family, World (DrawSelfScreen → `CharacterSheetActions.setDrawnAvatar` → `PhotoService.uploadOnly`; CharacterSheetScreen → `PersonAvatar` for signed-URL render of the drawn avatar), Action Words (GrowthArcScreen weaves `attachmentsCapturedByProvider` shots into the growth-arc reel).
- *Program photo wall* — `lib/features/photos/photos_gallery_screen.dart`. `/photos`: every room's photos, day-grouped grid, room/kid/source filter chips (vehicles hidden unless asked), name chip per tile, keeper hearts; tap → shared full-screen viewer with composite caption; long-press → metadata sheet (kid, room, time, source, shot-by, added-by). Staff-only; windowed to the latest 500 via `attachmentsDao.watchImagesInSpace` (backed by the `attachments_space` local index). Discovery: route `/photos`, omnibox `page.photos` (photos / gallery / pictures / photo wall / camera roll), drawer "Photos" after Captures. Pure filter/group core pinned by `test/unit/gallery_providers_test.dart`.
- *Photo consent* — `photo_consent.dart`. THREE states, because blank is not "no": unknown / allowed / declined. A recorded NO is never overridden by the program default. Enforced at capture (PhotoSourceSheet refuses and says why), at RENDER (the gallery filters at read time, because consent can be withdrawn AFTER a photo was taken — and that filter covers who TOOK the photo too), and recorded on the health profile where "not asked" CLEARS the key. `SubjectCaps.photoConsent` existed with ZERO call sites until 2026-08-24.
**Last verified**: 2026-08-24

---

## Picker
**Path**: `lib/features/picker/`
**Purpose**: The fair name picker — pick one kid, a pair, or split the room into teams; everyone gets picked before anyone repeats. A standalone tool, deliberately not a brain break.
**Personas served**: Jordan, Coach Sam, Brianna (daily "who goes next" moments).
**Discovery surfaces**:
- Routes: `/picker`
- Omnibox: yes — "Pick me — fair name picker" (page; keywords: picker, random, pick a name, name picker, teams, choose, randomizer, spinner)
- Slash: none
- Drawer: yes — "Pick me" after Photos
- Settings: no
**Capabilities**: Staff only (guardians blocked at the screen). No caps required.
**Data**: [groups](SCHEMA.md#groups), [subjects](SCHEMA.md#subjects), [attendance_records](SCHEMA.md#attendance_records) (the "Here today" filter). The fair bag persists per room per device (SharedPreferences), not synced.
**Surfaces**:
- *Name picker* — `lib/features/picker/picker_screen.dart`. Room chips + "Here today" (present/late once attendance is taken) + One/Two/Teams modes; big reveal with haptic, fresh-round banner, already-picked pile, teams 2-6 with even split and calm nature names.
- *Fair-draw core* — `lib/features/picker/picker_logic.dart`. `FairBag` (no repeats until exhaustion, refill mid-draw safe, roster sync, JSON persistence) + `splitTeams` (round-robin even split). Pinned by `test/unit/picker_logic_test.dart`.
**Depends on**: Groups, Subjects, Attendance (read-only).
**Consumed by**: Nothing yet — the games' Spotlight picker is separate (pure random, castable); folding the FairBag into it is a natural follow-up.
**Last verified**: 2026-08-02

---
## Poster
**Path**: `lib/features/poster/`
**Purpose**: Tile one image across several Letter/A4 pages — print all of them and tape them into one big poster (a kid's drawing blown up, a welcome banner, a giant map). The grid auto-fits the image's shape; you can reposition the crop, rotate, and add trim/assembly guides.
**Personas served**: All staff (a maker / room-decoration utility). Not guardians — staff-only; the router allow-list bounces guardians off `/poster`.
**Discovery surfaces**:
- Routes: `/poster`
- Omnibox: yes — "Poster — print big" (keywords: poster, print big, blow up, enlarge, banner, big print, large print, tile, engineer print, wall art, welcome sign, sign). Gated `viewer is! GuardianViewer`.
- Slash: none
- Drawer: no
- Settings: yes — "Poster" row in the Resources `_SettingsGroup`.
**Capabilities**: None — open to all signed-in staff. No child data touched.
**Data**: None — fully local. The picked image bytes never persist to the cloud (no DB row, no Storage upload); the PDF is generated on-device and handed to the OS print / share sheet. The chosen size/fit/paper/labels/guides options persist locally in SharedPreferences (`PosterPrefs`).
**Surfaces**:
- *PosterScreen* — `lib/features/poster/poster_screen.dart`. Pick image (gallery/camera, capped 6000 px; preview decodes downsized via `cacheWidth`); live WYSIWYG preview with cut-lines; Size (2–5) + "Fit to image shape" + Fit (edge-to-edge / whole image) + Paper (Letter/A4) + Page orientation (Auto / Portrait / Landscape — forces every page to that turn regardless of image shape) + Print quality (Standard/High/Lossless) + Corner labels + Assembly guides controls; Rotate (bakes 90° into the bytes) + Reset crop; in Fill mode the preview is interactive (drag to pan, pinch to zoom); three delivery actions — "Save PDF" (share sheet → Files/Drive/email → computer, with "print at 100%" guidance), "Save PNG" (single tiled image for programs that print images), "Print" (OS print dialog); determinate progress bar during tile render; working/error banners.
- *Poster engine* — `lib/features/poster/poster_engine.dart`. Pure geometry (`computePosterLayout` picks cols×rows + page orientation to match the image aspect; `posterCoverCrop`/`posterViewRect` = fill crop with zoom + focal point; `posterContainPlacement` = whole-image fit) + `rotateImageQuarterTurn` + `renderPosterTiles` (heavy decode/crop/resize in an isolate; web falls back to the main thread; per-quality DPI cap + JPEG-or-PNG tile encoding) + `buildPosterPdf` (Letter/A4, portrait/landscape, optional trim border + dashed cut line + crop marks + an "Assembly map" page; built-in Helvetica — no network). `renderPosterTilesForTest` is the `@visibleForTesting` sync seam.
- *Poster options* — `lib/features/poster/poster_models.dart`. `PosterFit {fill, whole}`, `PosterPaper {letter, a4}`, `PosterQuality {standard, high, lossless}`, `PosterOrientation {auto, portrait, landscape}`, `PosterOptions {size, fitShape, fit, paper, orientation, quality, labels, guides}`.
- *Poster prefs* — `lib/features/poster/poster_prefs.dart`. Load/save the durable options (defensive: corrupt/missing/out-of-range → defaults).
**Depends on**: `image` (decode/rotate/crop/resize), `pdf` + `printing` (PDF + OS print/share), `image_picker`, `shared_preferences`, EdgeScaffold + shared chrome primitives.
**Consumed by**: none.
- *Text signs* — `lib/features/poster/poster_text.dart`. "Make a sign" on the chooser: type the words, rendered in Fraunces on warm paper (raw canvas), fed into the same tile pipeline. Binary-search fit, up to 6 lines.
- *Print big from photos* — the shared photo viewer (print icon) and the photo wall's metadata sheet both fetch the photo's bytes (signed URL → cache) and open `/poster` seeded. Sizes ≥ 24″ also read in feet.
**Last verified**: 2026-08-09

---

## Pickup
**Path**: `lib/features/pickup/`
**Purpose**: The dismissal board + authorized-pickup records — who's still in the building, who's allowed to take a child home, and one-tap release at pickup time (docs/WORKFLOWS.md gap #2).
**Personas served**: Maya (configures authorized people), All staff (works the board + verifies at dismissal), Lauren / Devon (their entries).
**Discovery surfaces**:
- Routes: `/pickup` (the cross-program dismissal board)
- Omnibox: `page.pickup` — "Pickup board" (keywords: pickup, dismissal, release, checkout, go home, sign out)
- Slash: none
- Drawer: no — reached via Today's pickup-phase "Right now" card + omnibox (symmetric with Morning checklist)
- Settings: no
**Capabilities**: Configure authorized people: `can_authorize_pickup` (gated cap). Work the board / release: `can_take_attendance` (the daily-action gate). View: any staff.
**Data**: Authorized people in [subjects](SCHEMA.md#subjects).capabilities JSONB (`pickup_people`) + [guardians](SCHEMA.md#guardians).authorized_for_pickup. "Here" derived from [attendance_records](SCHEMA.md#attendance_records) (present/late today). Releases logged as [entries](SCHEMA.md#entries) `kind='departure'` (`text`=released-to, `details.guardian_id`) — a SEPARATE axis from attendance (releasing never mutates the attendance status). No new table.
**Surfaces**:
- `pickup_board_screen.dart` — the board: still-here list (one-tap Release per child → authorized-person sheet) + "Picked up today" section (with Undo). All-clear celebratory state when everyone's gone.
- `pickup_board_providers.dart` — `pickupBoardProvider` (composes groups × attendance × departures via the pure `computePickupBoard`) + `pickupBoardActionsProvider` (release / undo).
- `pickup_providers.dart` + `pickup_list.dart` — the authorized-people editor embedded in Subject detail (`pickup_people` caps).
**Status**: shipped — board v1 (still-here · authorized · one-tap release · undo). Deferred: late-pickup timers (needs a configurable pickup-window end), late-pickup push.
**Depends on**: Subjects, Guardians, Attendance, Entries, Groups.
**Consumed by**: Today (pickup-phase "Right now" card routes to `/pickup` when `dayPhaseProvider` is `DayPhase.pickup`).
**Last verified**: 2026-06-06

---

## Reflections
**Path**: `lib/features/reflections/`
**Purpose**: A count-up stopwatch ritual that turns real work time into a visible growth record — staff run the clock, stop it, rate how it went on a 4-face Scale, and the saved reflections stack into a personal growth strip.
**Personas served**: All staff (Jordan, Coach Sam, Brianna — the staffer's own growth practice). Kid-scoped entry (passing a `subjectId` so the reflection lands in the child's Book) is planned, not yet wired.
**Discovery surfaces**:
- Routes: `/reflect`
- Omnibox: yes — `page.reflect` "Reflect" (gated `viewer is! GuardianViewer`; keywords: reflect, reflection, stopwatch, timer, focus, session, how it went, growth, accountability)
- Slash: `/reflect` (aliases: reflection, stopwatch, timer, focus, session)
- Drawer: yes — "Reflect" in the **Activities** group (`nav_destinations.dart`, after `Present`)
- Settings: no
**Capabilities**: None — open to all signed-in staff. No cap key beyond non-guardian.
**Data**: Reuses [entries](SCHEMA.md#entries) `kind='reflection'` — one row per saved session; `details` JSON = `{seconds, face}` (face 1–4, 0 = not picked); `body` = optional note. `subject_id` nullable — null for a staffer's own session, set for a child's reflection (their Book). No new table or migration. `EntryKind.reflection` constant + `EntryActions.recordReflection(seconds:, face:, note:, subjectId:)` live in `lib/features/entries/entries_providers.dart`.
**Surfaces**:
- *Reflection session screen* — `lib/features/reflections/reflection_session_screen.dart`. The main `/reflect` screen: a count-up timer card ("Counting up" → "Stop & reflect" → 4-face picker + optional note + "Save reflection"); below that, the growth strip — all saved reflections newest-first (`_ReflectionTile`: face icon + elapsed time + note + relative timestamp). Past the 2-minute threshold the face rating is required; below it the face is optional. After save the timer resets and begins a fresh session immediately.
- *Reflection providers* — `lib/features/reflections/reflection_providers.dart`. `ReflectionView` (parses an `Entry` of `kind='reflection'` into typed `seconds` / `face` / `note`); `recentReflectionsProvider` (StreamProvider.autoDispose — watches `entries` in the space filtered by `kind='reflection'`, maps to `List<ReflectionView>` newest-first).
**Depends on**: Entries (`EntryActions.recordReflection`; `entriesDao.watchInSpace` via `recentReflectionsProvider`).
**Consumed by**: Nothing yet — leaf surface in slice 1. Slice 2 will surface the growth strip in Today or a dedicated "My growth" tile.
**Last verified**: 2026-06-14

---

## Recap
**Path**: `lib/features/recap/`
**Purpose**: Staff compose and send each family a daily recap — the room's shared day plus that child's own moments (hero name, question answer) — in one tap at the end of the session.
**Personas served**: All staff (Jordan, Coach Sam, Brianna — compose side; Maya — director oversight), Lauren, Devon (family receive side via Family Today).
**Discovery surfaces**:
- Routes: `/recap` (`RecapComposerScreen`; optional `?group=` query param selects the starting cohort). Gated at the discovery layer by `recapEnabledProvider`.
- Omnibox: yes — `page.recap` "Today's recap" (subtitle "Send each family their child's day"; keywords: recap, parent recap, daily recap, send home, send to families, what we did today, share with parents, digest, newsletter). **Toggle-gated** (`recapEnabledProvider`) + guardian-gated off (`viewer is! GuardianViewer`).
- Slash: none (mirrors the Daily pattern — a static slash list can't honor the toggle).
- Drawer: no — reached via the Brain Breaks deck's "Today's recap" card (slotted in when the toggle is on) or the omnibox.
- Settings: yes — "Daily parent recap" switch in Preferences (`_RecapTile`, off by default).
**Capabilities**: None beyond staff-only. `recapEnabledProvider` (SharedPreferences toggle) is the gate; all signed-in staff can compose once the director enables it.
**Data**: Writes [entries](SCHEMA.md#entries) `kind='recap'` — one row **per child** (`subject_id` set, `group_id` set); `details` JSON = `{date, activities[], question?, moment?, child:{name, hero?, answer?}}`. Each child's row is scrubbed of every other enrolled child's name at compose time (`recapDetailsForChild` + `scrubOtherNames`). `EntryActions.recordRecap` upserts by (subject, kind=recap, date) so re-sends overwrite rather than duplicate. Family-side read rides the existing `familyEntriesForSubjectProvider` (`kind=recap`) — no new family-lens plumbing.
**Surfaces**:
- *Recap composer screen* — `lib/features/recap/recap_composer_screen.dart`. `/recap`; staff see the room's shared day (activity chips + today's question pulled from `recapDraftProvider`) + an optional "a moment" free-text field + a per-child preview (hero name + their answer, or "Today's room day"). "Send to N families" FilledButton writes one scrubbed entry per child. Loading / empty / error states.
- *Recap model* — `lib/features/recap/recap_model.dart`. `RecapChildInput` (per-child compose payload), `recapDetailsForChild` (pure builder — scrubs other names, returns the stored `details` map), `RecapView` (parser for family-side render — tolerant of missing keys).
- *Recap providers* — `lib/features/recap/recap_providers.dart`. `RecapDraft` + `RecapKey` typedef; `recapDraftProvider` (FutureProvider.autoDispose.family keyed on `(groupId, date)` — assembles activities from the schedule, today's question from the Daily, and each child's hero + question answer).
- *Recap setting* — `lib/features/recap/recap_setting.dart`. `recapEnabledProvider` (`AsyncNotifierProvider<bool>`, default `false`, persisted in SharedPreferences key `settings.recap_enabled`).
- *Brain Breaks deck card* — `lib/features/activity_runtime/brain_breaks_screen.dart`. "Today's recap" card (tagline "Send each family the day"; icon `Icons.send_outlined`; color `ActivityPalette.cyan`; route `/recap`). Slotted in when `recapOn` is true.
- *Family Today peek* — `_TodaysRecapPeek` in `lib/features/family/family_today_screen.dart`. Reads `familyEntriesForSubjectProvider` filtered to `kind=recap`; renders the room's activity chips + the day's question + the child's own moments (hero, answer) on the guardian's Family Today screen. Renders nothing until staff send today's recap — no empty state shown to family.
**Depends on**: Entries (`EntryActions.recordRecap`, `EntryKind.recap`), Schedule (`scheduleDayForGroupProvider` — activities), Daily (`todaysDailyProvider` — today's question), Heroes (`heroForSubjectProvider` data pulled inline in `recapDraftProvider` via `entriesDao.watchForSubject(kind: hero)`), Subjects (`subjectsInGroupProvider` — per-child roster), Action Words (`scrubOtherNames` imported from `summer_book.dart`).
**Consumed by**: Family (`_TodaysRecapPeek` on Family Today reads entries of `kind='recap'`).
**Last verified**: 2026-06-19

---

## Review
**Path**: `lib/features/review/`
**Purpose**: Guided reflection — weekly (one-question-per-page walk) and yearly (annual re-grounding).
**Personas served**: Maya (director reflection). All signed-in staff can run the walk; guardians (Lauren, Devon, Helen, Marcus) don't reach `/review`.
**Discovery surfaces**:
- Routes: `/review`, `/review/year`
- Omnibox: yes — "Weekly review", "Yearly review"
- Slash: `/review`
- Drawer: no
- Settings: no
**Capabilities**: None — open to all signed-in staff.
**Data**: Reads [entries](SCHEMA.md#entries), [captures](SCHEMA.md#captures), [tasks](SCHEMA.md#tasks); writes a synthesis as a Capture (or future "Review" entry kind).
**Surfaces**:
- *Weekly review screen* — `lib/features/review/weekly_review_screen.dart`. One question per page; "walk me through it" cadence.
- *Yearly review screen* — `lib/features/review/yearly_review_screen.dart`. Annual reflection.
**Depends on**: Entries, Captures, Tasks.
**Consumed by**: Today (review prompt when due).
**Last verified**: 2026-07-13

---

## Routines
**Path**: `lib/features/routines/`
**Purpose**: The kid-legible read of the day — "what do we do now? / at 9?" — re-skinning the room's existing staff schedule with friendly icons and warm sublabels (PE → "the workout for your body", brain breaks → "the workout for your brain") and a "now" highlight, so the rhythm is something a child can predict and belong to (docs/VISION.md 2026-06-19).
**Personas served**: Ava (the child reading the day), All staff (present it to the room).
**Discovery surfaces**:
- Routes: `/routines` (`?group=` selects a cohort; defaults to the first, chip selector switches). Always resolves; surfaces below are gated.
- Omnibox: `page.routines` ("Routines" — keywords what do we do now / our day / rhythm / routine). **Toggle-gated** (`routinesEnabledProvider`) + guardian-gated off.
- Slash: none (a static slash list can't honor the toggle).
- Drawer: no — reached via the Brain Breaks deck's "Our day" card (slotted in when the toggle is on) or the omnibox.
- Settings: yes — "Routines (kid view)" switch in Preferences (`_RoutinesTile`, off by default).
**Capabilities**: None — open to all signed-in staff once the director switches it on.
**Data**: [schedule_blocks](SCHEMA.md#schedule_blocks) (READ-ONLY, live, via `scheduleDayForGroupProvider`), [activities](SCHEMA.md#activities) (read, to resolve a block's name). Writes nothing; adds no table or column — the kid voice is a render-time layer.
**Surfaces**:
- *Routines screen* — `lib/features/routines/routines_screen.dart`. `/routines`; reads today's blocks for the selected cohort and renders a glanceable timeline (time + icon + activity + sublabel) with the current block highlighted ("now" pill) and finished blocks dimmed. Cohort chip selector; loading / empty / error states.
- *Voice layer* — `lib/features/routines/routine_voice.dart`. `RoutineVoice.sublabelFor` / `.iconFor` — a pure first-match keyword map from a block's name to a warm kid sublabel + icon. Whole-word match for short tokens; unknown blocks degrade.
- *Toggle* — `lib/features/routines/routines_setting.dart`. `routinesEnabledProvider`, default off.
**Depends on**: Schedule (reads `scheduleDayForGroupProvider` + `activitiesProvider`), Groups (cohort list + selector).
**Consumed by**: ActivityRuntime (Brain Breaks deck injects the "Our day" card), Omnibox (`page.routines`), Settings (`_RoutinesTile`).
**Last verified**: 2026-06-19

---

## Schedule
**Path**: `lib/features/schedule/`
**Purpose**: Per-cohort, per-day block planning — activities, locations, leads, and one-tap "X is out, Y is covering" substitution.
**Personas served**: Maya (plans the week — tablet grid deferred), Coach Sam (sees blocks + pre-block brief), Pat (covers absent leads), All staff (see their day).
**Discovery surfaces**:
- Routes: `/schedule`, `/schedule/block`, `/schedule/day-templates`, `/schedule/day-templates/:id`, `/trips/:blockId`, `/propose-day`
- Omnibox: yes — "Schedule" (with keywords: day, block, rotation, agenda, plan, field trip, trip), "Schedule · {Group.name}" (per cohort), "Cover today · {Group.name}" (per cohort, action, gated by `can_manage_schedule`), "Day templates" (id `page.day-templates`, keywords: day template, day templates, shape of the day, time blocks, timeline, rhythm, routine, schedule template), "Draft a day" (id `page.propose-day`, gated `can_manage_schedule`, keywords: draft, draft a day, propose, propose a day, suggest a day, plan today, auto day, make me a day)
- Slash: `/schedule`
- Drawer: yes — "Schedule" (main destinations, position 2)
- Settings: no
**Capabilities**: Read: all members. Write: `can_manage_schedule` (director / lead-tier). Day-template authoring: `SpaceCaps.dayTemplates` (`day_templates` key on `spaces.capabilities`) — the templates JSON is stored under this cap key; no separate gate is enforced in the UI (any signed-in staff can open the builder, but only members who can write `spaces.capabilities` can mutate it).
**Data**: [schedule_blocks](SCHEMA.md#schedule_blocks) (read + written by day-template `applyToDate` via `scheduleDao.createDayBlocks`), [activities](SCHEMA.md#activities), [locations](SCHEMA.md#locations), [trip_logistics](SCHEMA.md#trip_logistics), [trip_vehicles](SCHEMA.md#trip_vehicles), [permission_slips](SCHEMA.md#permission_slips), [headcounts](SCHEMA.md#headcounts), [entries](SCHEMA.md#entries) (reads via `schedule_block_id` back-reference — live-block capture tagging, see migration `20260531000002`), [activity_supplies](SCHEMA.md#activity_supplies) (reads via `activitySupplyLinksProvider` in the activity editor), [supplies](SCHEMA.md#supplies) (reads via `suppliesProvider` to populate the pack-list picker in the activity editor), [spaces](SCHEMA.md#spaces) (day-template library stored as JSON in `spaces.capabilities['day_templates']`; read via `currentSpaceProvider`, written via `spaceCapActionsProvider`)
**Surfaces**:
- *Schedule screen* — `lib/features/schedule/schedule_screen.dart`. Cohort tabs × flush time-rail agenda (phone-friendly). On wide screens, all cohorts render as side-by-side columns (the schedule matrix). Top chrome carries an overflow menu with "New block", "Weekly template" → `/schedule/template`, and "Day templates" → `/schedule/day-templates`. `_BlockTile` renders a live "NOW" line — a primary-colour left accent + tint + NOW pill — when the wall clock falls within a block's `[start, end)` window on today's date (`isNow` flag computed per-block in `_CohortDay.build`). This is a pure UI signal; no new provider or table.
- *Block edit screen* — `lib/features/schedule/block_edit_screen.dart`. Create / edit one block (start, end, activity, lead, location, kind).
- *Substitute lead sheet* — `lib/features/schedule/widgets/substitute_lead_sheet.dart`. Modal bottom sheet: pick absent lead → pick cover. Bulk-writes `lead_substitute_member_id` for all matching blocks on the day. Surfaceable directly from the omnibox via "Cover today · {Group.name}" (Pat persona) without first entering the schedule editor.
- *Leading-today card* — `lib/features/schedule/widgets/leading_today_card.dart`. Embedded on home; signed-in lead's blocks + cabin notes for today.
- *Day templates screen* — `lib/features/schedule/day_templates_screen.dart`. `/schedule/day-templates`: the template library. Lists all saved `DayTemplate` objects; tap → editor. "New day template" action button creates a starter and pushes the editor. Empty state with primary CTA.
- *Day template editor screen* — `lib/features/schedule/day_template_editor_screen.dart`. `/schedule/day-templates/:id`: the builder. Header card with start/end time pickers (time re-packs automatically); `ReorderableListView` of duration blocks (drag to reorder; clock windows re-derive from packed durations). Add/edit-block glass sheet (`_BlockSheet`): kind chip palette, label field, duration chips. "Apply to a day" action opens `_ApplySheet`: date picker + room checkboxes → `DayTemplateActions.applyToDate` → `scheduleDao.createDayBlocks` writes real `schedule_blocks`. Rename + delete via popup menu.
- *Day template model* — `lib/features/schedule/day_template.dart`. `DayTemplate`, `DayBlock`, `DayBlockKind` palette (11 kinds), `DaySlot` (packed clock window), per-block `energy` override. Pure model + JSON encode/decode helpers (`encodeDayTemplates` / `decodeDayTemplates`). `clockLabel` / `durationLabel` pure formatting functions. `DayTemplate.starter()` (a sane blank) + `DayTemplate.proposed({startMinute, endMinute, worldName})` — the context-aware draft for "propose the day" (adaptive durations fill the window; the photo block is a "rotation" so the day-run auto-fills it; unit-tested in `test/unit/propose_day_test.dart`, 6 cases).
- *Propose a day screen* — `lib/features/schedule/propose_day_screen.dart`. `/propose-day`: the "propose the day" review (docs/VISION.md "the app walks in already holding a draft of your day"). `proposedDayProvider` builds a `DayTemplate.proposed` from `dayPhaseWindowsProvider` (program hours) + `currentWorldProvider` (this week's world); the screen shows the drafted blocks + `DayArcStrip` and offers **Use this day** (`DayTemplateActions.applyTemplateToDate` → today's `schedule_blocks` for the resolved cohort, with a `confirmDestructive` guard when the day already has blocks, then `→ /run-day`) or **Tweak first** (`restoreTemplate` saves it to the library + opens the editor). Gated `canManageSchedule`; reached from the run-day empty state ("Draft a day for today") + omnibox `page.propose-day`. `DayTemplateActions.applyTemplateToDate` applies a template OBJECT (not a saved id) so the unsaved draft can land directly.
- *Nudge the run* — `lib/features/schedule/nudge.dart` + `nudge_sheet.dart`. The middle-UI "nudge the run" move (docs/VISION.md "you nudge it… a structured change to confirm, never a chat reply"). Pure `recomposeNudge(remaining, availableMin, intent)` → `NudgePlan` (new order + durations + diff + summary) for three plain-language intents — **behind** (compress the flexible remaining blocks to still finish on time; pickup/closed stay fixed), **wired** (bring the next calm block forward), **ahead** (stretch the next block into the surplus); unit-tested (`nudge_test.dart`, 8 cases). `nudge_sheet.dart`: `NudgeBar` (three `ActionChip`s, rides above the run-day deck), `showNudgeDiffSheet` (the before→after confirm-diff — nothing applied until Apply), and `nudgeTheDay(...)` which builds the plan from the cohort's REMAINING blocks (`end > now`), shows the diff, and on apply re-packs from the anchor + writes each block's new times via `scheduleActionsProvider.update_`. Optimistic + offline-first (no schema change).
- *Day template providers* — `lib/features/schedule/day_template_providers.dart`. `dayTemplatesProvider` (Provider — reads `spaces.capabilities['day_templates']` JSON via `currentSpaceProvider.select`); `dayTemplateByIdProvider` (Provider.family); `DayTemplateActions` (Notifier — serialized read-modify-write of the cap JSON; `applyToDate` generates real `schedule_blocks` via `scheduleDao.createDayBlocks`); `dayTemplateActionsProvider`.
- *Trip detail screen* — `lib/features/schedule/trip_detail_screen.dart`. `/trips/:blockId`. Reached from `BlockEditScreen` when a block's kind is `field_trip`. Two moments, one screen: before setup (no `trip_logistics` row), shows a clean "Plan this trip" form — destination, address, notes — with a single Save. After setup (row exists), leads with `_TripIdentity` (a "Field trip" chip, the destination as the display headline, address and depart/return times), then a `_ReadinessBanner` showing slip readiness ("Ready to go" / "Almost ready · collect N more slips") when permission slips are required, then three `CollapsibleSection` cards — Headcount (open by default, safety-first, renders `TripHeadcountSection`), Permission slips (collapsed, with an "N / total signed" summary, unsigned kids sorted to the top), and Vehicles & drivers (collapsed, "N assigned" summary). The "Edit trip basics" form is tucked under a fourth `CollapsibleSection` (collapsed by default) so it stays accessible without dominating the run-day view. Reads `trip_logistics`, `permission_slips`, `trip_vehicles`, `subjects` (for the slip roster count).
**Depends on**: Groups, Members, Activities, Locations, Vehicles (trip assignment), Entries (reads `schedule_block_id` back-reference for live-block capture tagging), Supplies (pack-list picker in `activity_edit_screen.dart` reads `suppliesProvider` + `activitySupplyLinksProvider`), Spaces (`day_template_providers.dart` reads and writes `spaces.capabilities` via `currentSpaceProvider` + `spaceCapActionsProvider`).
**Consumed by**: Today (leading-today card; `contextLeadProvider` in `context_lead.dart` reads `liveBlockProvider` for the live-block path of the contextual lead), Attendance (block-context for headcounts), Captures (block-context tag), Omnibox (substitute-lead sheet invoked from the per-cohort "Cover today" entry).
**Last verified**: 2026-07-13

---

## Settings
**Path**: `lib/features/settings/`
**Purpose**: Library / admin surfaces — program config, team, fleet, locations, activities, member detail, plus device preferences.
**Personas served**: Maya (all of it), All staff (preferences + read-only team / vehicles), Helen (text-size override, also reachable from Family Today header), Jordan (outdoor-mode toggle + display-style toggle).
**Discovery surfaces**:
- Routes: `/settings`, `/settings/program`, `/settings/team`, `/settings/team/:id`, `/settings/roles`, `/settings/vehicles`, `/settings/locations`. (Activities lives at `/activities`, not under settings, because it's used more often than configured.)
- Omnibox: yes — "Settings", "Program settings", "Team", "Roles & permissions", "Vehicles", "Locations", "Activities"
- Slash: none directly; sub-features may add some later
- Drawer: yes — "Settings" (main destinations, position 5)
- Settings: this IS the settings screen
**Capabilities**: Read: all members. Program settings: `can_manage_space`. Team write / vehicles write: `can_manage_space`. Roles screen is read-only for everyone (the catalog itself is a code constant).
**Data**: [spaces](SCHEMA.md#spaces) (program settings screen reads + writes `capabilities['timer_presets']` via `HouseTimerActions.setPresetMinutes`; `capabilities['suggest_play_minutes']` via `HouseTimerActions.setPlayMinutes`; `capabilities['phase_windows']` via `DayPhaseActions.setWindows`; all other feature flags via `SpaceCapActions.setCap`/`setStringCap`/`setIntCap`), [members](SCHEMA.md#members), [locations](SCHEMA.md#locations) plus what each sub-screen owns. Roles screen reads no DB — the role catalog is `RoleBundles.rolesFor(vertical)` / `defaultsFor()` in `lib/core/capabilities/`.
**Surfaces**:
- *Settings screen* — `lib/features/settings/settings_screen.dart`. Grouped list (Account / Space / Preferences / About). The **Preferences** group carries: `TextSizeTile` (text scale floor), `_OutdoorModeTile` (high-contrast), `_DisplayStyleTile` (Display style picker — three options: `DisplayStyle.boxed` (filled cards, original look) / `DisplayStyle.calm` (flat one-edge cards — the default) / `DisplayStyle.clean` (Calm layout + tight sentence-case typographic restraint via `AppType.cleanTextTheme()`); reads/writes `displayStyleProvider` from `lib/features/settings/display_style_setting.dart`).
- *Program settings* — `lib/features/settings/program_settings_screen.dart`. Per-space capability flags + pickup window + "Defaults" section: "Timer presets" `_TimerPresetsTile` (reads `houseTimerPresetsProvider`; taps to a glass sheet that adds/removes whole-minute presets; writes via `HouseTimerActions.setPresetMinutes`) + "Big Thinking play length" `_PlayLengthTile` (inline ± stepper; writes via `HouseTimerActions.setPlayMinutes`) + "Day rhythm" `_PhaseWindowsSection` (four time-pickers for arrival/program/pickup/closed phase boundaries; writes via `DayPhaseActions.setWindows`). All three write `spaces.capabilities` via `SpaceCapActions`.
- *Team screen* — `lib/features/settings/team_screen.dart`. Members + pending invites.
- *Member detail* — `lib/features/settings/member_detail_screen.dart`. Per-staff profile + certifications.
- *Roles & permissions* — `lib/features/settings/roles_screen.dart`. Read-only directory of every role offered in the active vertical + the default capabilities each one ships with. Surfaces cert-gated caps in a separate group so directors don't think "the bundle says false; I'll flip it" without realizing the cert is the actual gate. Shipped 2026-05-22 (Wave 36).
- *Locations list* — `lib/features/settings/locations_list_screen.dart`. Place catalog for scheduling.
- *Shared text-size tile / picker* — `lib/features/settings/widgets/text_size_tile.dart`. Public `TextSizeTile` + `showTextSizePicker(context, ref)` helper, reused by Family Today so guardians can reach the override without a Settings screen.
**Depends on**: Members, Spaces (timer_presets + suggest_play_minutes + phase_windows cap writes; reads via Action Words providers), Vehicles, Locations, Activities, Invites, Certifications, Capabilities catalog, Action Words (`houseTimerActionsProvider` + `houseTimerPresetsProvider` + `houseSuggestPlayMinutesProvider` imported from `house_timer.dart`; `DayPhaseActions` + `dayPhaseActionsProvider` imported from `today_providers.dart`), `display_style_setting.dart` (SharedPreferences-backed `displayStyleProvider`).
**Consumed by**: Most features (config), Helen (text scale — staff AND family-side via shared picker), Jordan (outdoor mode + display style), Family Today (text-size picker).
**Last verified**: 2026-07-13

---

## Spellbook
**Path**: `lib/features/spellbook/`
**Purpose**: "A World of Magic" — a magic-framed home the room opens each day that GATHERS what already exists into one place: today's ritual (the Daily), this week's project (the live world arc), and the unfolding story (the journey). RPG-as-utility, the spellbook as container (docs/VISION.md 2026-06-19). Builds nothing new under the hood — it composes.
**Personas served**: Ava (opens the spellbook), All staff (host the day from one place).
**Discovery surfaces**:
- Routes: `/spellbook`. Always resolves; surfaces below are gated.
- Omnibox: `page.spellbook` ("Spellbook" — keywords spellbook / magic / world of magic / today / this week / story). **Toggle-gated** (`spellbookEnabledProvider`) + guardian-gated off.
- Slash: none (a static slash list can't honor the toggle).
- Drawer: no — reached via the Brain Breaks deck's "Spellbook" card (when on) or the omnibox.
- Settings: yes — "Spellbook home" switch in Preferences (`_SpellbookTile`, off by default).
**Capabilities**: None — open to all signed-in staff once the director switches it on.
**Data**: None directly — an aggregator. Reads `todaysDailyProvider` (the Daily), `currentWorldProvider` + `currentWorldArcProvider` (this week's world + project). Navigates to `/daily` + `/this-week`.
**Surfaces**:
- *Spellbook screen* — `lib/features/spellbook/spellbook_screen.dart`. `/spellbook`; a warm cover (the week's world name/emoji/tagline) over three gathered FeatureCards — Today's spell → `/daily`, This week's quest → `/this-week`, Your story so far → `/this-week` (currently routes to the same hub; a dedicated journey view is deferred).
- *Toggle* — `lib/features/spellbook/spellbook_setting.dart`. `spellbookEnabledProvider`, default off.
**Depends on**: Daily (`todaysDailyProvider`), Action Words (`currentWorldProvider` + `currentWorldArcProvider` — the live world/project engine), and the `/daily` + `/this-week` routes.
**Consumed by**: ActivityRuntime (Brain Breaks deck injects the "Spellbook" card), Omnibox (`page.spellbook`), Settings (`_SpellbookTile`).
**Last verified**: 2026-06-19

---

## Spells
**Path**: `lib/features/spells/`
**Purpose**: Five fullscreen timer commands — each a word in another language (the word rotates by day so the class meets it in Spanish, then French, then Swahili across the term); a countdown ticks down while a breathing animation plays, then haptic-rings "Time!". The brief's one loud moment — hold up the phone or put it on a projector.
**Personas served**: All staff (Jordan, Coach Sam, Brianna — any teacher needing a dramatic transition signal).
**Discovery surfaces**:
- Routes: `/spells`
- Omnibox: yes — `page.spells` "Spells" (keywords: spell, timer, freeze, move, countdown, language, transition)
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: None — open to all signed-in staff.
**Data**: None — pure catalog (`kSpells` Dart const). No synced table, no migration.
**Surfaces**:
- *Spells screen* — `lib/features/spells/spells_screen.dart`. `/spells`: five tile buttons in a 2–3 col grid (responsive); each tile previews today's foreign word + the timer duration; tap casts the spell.
- *Spell overlay* — `lib/features/spells/spell_overlay.dart`. Fullscreen dark countdown pushed on the root navigator (bypasses app chrome). Breathing `ScaleTransition` on the emoji; gold foreign word + pronunciation + language + English gloss; live countdown; haptic on expiry; tap anywhere to end early. Enters `SystemUiMode.immersiveSticky`; restores `edgeToEdge` on dispose.
- *Spell catalog* — `lib/features/spells/spells.dart`. `Spell`, `SpellWord`, `kSpells` (5 spells × 3 languages), `spellWordForDay(spell, dayKey)` (deterministic day-keyed rotation), `spellTimeLabel(seconds)`.
**Depends on**: Nothing — pure catalog feature.
**Consumed by**: Nothing currently. Future: Action Words spell-timer integration (docs/ACTION_WORDS.md — "spell timers" listed as next step).
**Last verified**: 2026-06-07

---

## Staff
**Path**: `lib/features/staff/`
**Purpose**: Three bundled-JSON reference surfaces that orient any staff member — especially new helpers and substitutes — to the day's moment-by-moment flow, the 12-verb classroom jobs + challenge ideas, and their own growth arc on the Shadow → Conductor ladder.
**Personas served**: All staff — especially Pat (substitute orientation), Brianna (onboarding), Jordan (on-the-floor helper script reference).
**Discovery surfaces**:
- Routes: `/runbook` (RunbookScreen), `/staff` (StaffLadderScreen), `/verb-jobs` (VerbJobsScreen — in `lib/features/action_words/`)
- Omnibox: yes — `page.runbook` "Runbook" (keywords: runbook, run book, staff guide, helper guide, moment by moment, what do i do, lead helper, if it breaks, substitute, sub, new helper); `page.staff-ladder` "The staff ladder" (keywords: staff, staff ladder, my role, shadow, extra hands, co-pilot, conductor, training, onboarding, new staff, grow); `page.verb-jobs` "Jobs & missions" (keywords: jobs, classroom jobs, job chart, missions, verb missions, helper script, what to say, staff skills, the mover, the ear, roles)
- Slash: none
- Drawer: no — contextual reference surfaces, not top-level nav destinations
- Settings: no
**Capabilities**: None — open to all signed-in staff.
**Data**: None — all three surfaces read bundled JSON assets (`assets/curriculum/staff_runbook.json`, `assets/curriculum/staff_roles.json`, `assets/curriculum/verb_roles.json`). No synced tables. The self-mark on the staff ladder is stored locally via `staffLevelProvider` (SharedPreferences, key `staff.ladder_level`) — NOT synced, NOT a permission gate.
**Surfaces**:
- *Runbook screen* — `lib/features/staff/runbook_screen.dart`. `/runbook`: the day moment-by-moment in three lanes (LEAD / HELPER / IF IT BREAKS); read from `staffRunbookProvider`. Pure reference — no per-room state.
- *Runbook provider + model* — `lib/features/staff/runbook.dart`. `RunbookMoment` (time / name / emoji / lead / helper / ifItBreaks); `staffRunbookProvider` (FutureProvider loading `assets/curriculum/staff_runbook.json`).
- *Staff ladder screen* — `lib/features/staff/staff_ladder_screen.dart`. `/staff`: four rungs (Shadow → Extra Hands → Co-Pilot → Conductor) each with can-do / can't-do lists; tap to self-mark the current rung via `staffLevelProvider`. Growth reflection, not an authority gate.
- *Staff ladder provider + model* — `lib/features/staff/staff_ladder.dart`. `StaffRole` (id / name / emoji / duration / desc / canDo / cantDo); `staffRolesProvider` (FutureProvider loading `assets/curriculum/staff_roles.json`); `staffLevelProvider` (AsyncNotifierProvider<StaffLevelNotifier, String> — local SharedPreferences, default `'shadow'`).
- *Verb jobs screen* — `lib/features/action_words/verb_jobs_screen.dart`. `/verb-jobs`: each of the 12 verbs as a kid JOB for the day (job title + helper script) + 3-level challenge-idea mission + 3-level staff skill. Pure reference content from `verbRolesProvider`. NOTE: the verb-missions here are reference CHALLENGE IDEAS, deliberately distinct from the evidence-backed, catalog-managed Missions feature (`lib/features/missions/`) — they are complementary, not a fork. The Missions feature is the director-configured "real jobs" catalog; these are lightweight challenge prompts keyed to each verb.
- *Verb roles provider + model* — `lib/features/action_words/verb_roles.dart`. `VerbJob` / `StaffSkill` / `VerbMission` / `VerbRole`; `verbRolesProvider` (FutureProvider loading `assets/curriculum/verb_roles.json`); `verbRoleProvider` (family Provider by verb id).
**Depends on**: Action Words (shares `verb_roles.dart` + `verbs.dart`; `VerbJobsScreen` lives in `lib/features/action_words/`).
**Consumed by**: Nothing — these are reference leaf surfaces.
**Last verified**: 2026-06-07

---

## Story
**Path**: `lib/features/story/`
**Purpose**: TODO — please describe.
**Personas served**: TODO
**Discovery surfaces**:
- Routes: `/story` (RoomStoryScreen — the whole class's moments), `/story/:subjectId` (KidStoryScreen — a child's memory timeline; carries a "Book" IconButton that pushes `/book/:subjectId`)
- Omnibox: yes — `page.room-story` "Room story" (keywords: story, moments, memory, history); no per-subject omnibox entry
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: TODO
**Data**: TODO
**Surfaces**:
- *Room story screen* — `lib/features/story/room_story_screen.dart`. TODO — please describe.
- *Kid story screen* — `lib/features/story/kid_story_screen.dart`. A child's captured moments as a timeline; "Book" icon pushes `/book/:subjectId`.
- *Moment model + helpers* — `lib/features/story/moment.dart`. `Moment`, `momentsFrom(entries)`, `curriculumWeekFor(start, dt)`.
- *Story providers* — `lib/features/story/story_providers.dart`. TODO — please describe.
**Depends on**: Entries, Subjects, Action Words (Book button + `curriculumWeekFor` from `moment.dart`).
**Consumed by**: Action Words (`book_screen.dart` imports `moment.dart` + `MomentTile`).
**Last verified**: 2026-06-07

---

## Missions
**Path**: `lib/features/missions/`
**Purpose**: The program's catalog of real jobs kids do — each with a manual (rules), a practiceable checklist (actions), and an evidence kind — so responsibility is concrete, doable, and verifiable.
**Personas served**: Maya, Coach Sam, Brianna (directors/leads maintain catalog via `canManageSpace`); Ava and all kids (will claim + do missions in slice 2); All staff (view).
**Discovery surfaces**:
- Routes: `/settings/missions`, `/settings/missions/board`
- Omnibox: yes — "Missions" (id `page.missions`) → `/settings/missions`; "Today's board" (id `page.mission-board`), keywords: board, do board, tasks, tasks zero, jobs, missions board, big buttons → `/settings/missions/board`
- Slash: none
- Drawer: yes — "Missions" (canonical nav, position between Brain Breaks and Brainstorm Board)
- Settings: no
**Capabilities**: View: all signed-in staff. Create / edit / delete: `canManageSpace` (director / lead). Slice 2 will add kid-side claim with no cap gate.
**Data**: [missions](SCHEMA.md#missions), [entries](SCHEMA.md#entries) (`kind='mission'` — one row per completion; `details.missionId` identifies which mission was done)
**Surfaces**:
- *Missions list screen* — `lib/features/missions/missions_list_screen.dart`. EdgeScaffold; four states (loading / empty / error / data); empty state offers "Add the starter set (11)" + "Add your own"; mission tiles; tap → read-only detail sheet (icon, builds, age, rules, numbered steps, evidence kind); edit sheet. Top chrome carries a board IconButton → `/settings/missions/board`. Edit actions gated by `viewer.canManageSpace`.
- *Mission board screen* — `lib/features/missions/mission_board_screen.dart`. `/settings/missions/board`: the Do board — active missions as big tap-to-complete buttons (grid, 2–4 cols responsive); tap shrinks the tile away with `AnimatedScale` and writes a `kind='mission'` entry via `MissionActions.complete`; all cleared → "Tasks zero" celebratory state. Drives the "doing clears to zero" UX concept from docs/ACTION_WORDS.md.
- *Missions providers* — `lib/features/missions/missions_providers.dart`. `missionsProvider` (StreamProvider → `db.missionsDao.watchInSpace`); `missionCompletionsProvider` (StreamProvider → `db.entriesDao.watchInSpace(kind: EntryKind.mission)`); `MissionActions` Notifier with create / update_ / delete_ / addStarterSet / complete.
- *Mission templates* — `lib/features/missions/mission_templates.dart`. `MissionTemplate` + `missionTemplates` (11 starter jobs: Equipment Manager, Snack Helper, Cleanup Crew, Supply Keeper, Line Leader, Greeter, Library Keeper, Lights & Doors, Recycle Captain, Plant & Pet Caretaker, Peace Buddy); `MissionEvidenceKind` enum (photo/count/note/check); actions JSON codec (encode/decodeMissionActions).
**Depends on**: Entries (`kind='mission'` completions read + written via `entriesDao`).
**Consumed by**: Nothing in slice 1 other than Entries (completion writes). Slice 2 will add mission_assignments.
**Last verified**: 2026-07-13

---

## Supplies
**Path**: `lib/features/supplies/`
**Purpose**: The program's real-world inventory catalog — track items (markers, paper, balls) once, flag low stock, and reference by id from activities.
**Personas served**: Maya, Coach Sam, Brianna (directors/leads maintain via `canManageSpace`); All staff (view).
**Discovery surfaces**:
- Routes: `/settings/supplies`
- Omnibox: yes — "Supplies" (id `page.supplies`), keywords: supplies, inventory, materials, stock, markers, paper → `/settings/supplies`
- Slash: none
- Drawer: no — library surface (same convention as Locations, Activities)
- Settings: no — omnibox is the canonical discovery entry; Settings screen is preferences-only per the library convention
**Capabilities**: View: all signed-in staff. Create / edit / delete: `canManageSpace` (director / lead).
**Data**: [supplies](SCHEMA.md#supplies), [activity_supplies](SCHEMA.md#activity_supplies) (read via `activitySupplyLinksProvider` + written via `ActivitySuppliesActions`), [locations](SCHEMA.md#locations) (read for the Location lens — `location_id` FK added in migration `20260601000003`)
**Surfaces**:
- *Supplies list screen* — `lib/features/supplies/supplies_list_screen.dart`. EdgeScaffold; three-view toggle (Category / Location / Running low) backed by `_SuppliesView` enum; `groupSuppliesByLocation` groups by the `location_id` FK when in Location mode; all four states (loading / empty / error / data); add/edit via `openSupplyEditSheet`. Edit actions gated by `viewer.canManageSpace`. Low-stock highlighting via `isLowStock` helper.
- *Supply edit sheet* — inline glass sheet opened from `SuppliesListScreen`. Create / update a supply row (name, category, quantity, unit, location_id → Locations FK, free-text sub-spot, low_stock_threshold, notes, photo_url).
- *Activity supplies providers* — `lib/features/supplies/activity_supplies_providers.dart`. `activitySupplyLinksProvider` (StreamProvider.family by activityId → `db.activitySuppliesDao.watchForActivity`); `ActivitySuppliesActions` Notifier with `setForActivity` (replace-all write via `replaceForActivity`).
- *Supplies providers* — `lib/features/supplies/supplies_providers.dart`. `suppliesProvider` (StreamProvider → `db.suppliesDao.watchInSpace`); `supplyActionsProvider` (`SupplyActions` Notifier with create / update_ / delete_).
- *Supplies grouping helpers* — `lib/features/supplies/supplies_grouping.dart`. Pure functions: `supplyCategoryLabel`, `isLowStock`, `groupSuppliesByCategory`, `groupSuppliesByLocation`, `supplyLocationLabel`, `formatSupplyNumber`. No UI — consumed by the list screen.
**Depends on**: Locations (Location lens reads `locationsProvider` for `location_id → name` resolution).
**Consumed by**: Activities / Schedule (`activity_edit_screen.dart` imports `activity_supplies_providers.dart` and `supplies_providers.dart`; the structured "Supplies needed" picker writes `activity_supplies` rows on save).
**Last verified**: 2026-07-13

---

## World
**Path**: `lib/features/world/`
**Purpose**: A child draws their self-portrait, names it, and that drawing becomes their persistent in-world avatar — the day-one ritual that starts the summer-long Different World identity (docs/WORLD.md, docs/WORLD_DESIGN.md).
**Personas served**: Ava (draws + names her world self); Jordan, Coach Sam (set up the ritual from the subject card as floor staff).
**Discovery surfaces**:
- Routes: `/subjects/:id/me` (CharacterSheetScreen — the "Me" screen), `/subjects/:id/draw` (DrawSelfScreen — finger-drawing canvas), `/skills/:subjectId/:skillId` (SkillDetailScreen — one skill's progression: the number, the rising curve, the delta from day one)
- Omnibox: no — intentionally absent in slice 1; reached only from the subject's card
- Slash: none
- Drawer: no — intentionally absent in slice 1
- Settings: no — intentionally absent in slice 1
**Note (slice 1)**: The only discovery surface is a `_WorldSelfTile` FeatureCard on `lib/features/subjects/subject_detail_screen.dart`. No omnibox, drawer, or settings entry exists yet — this is intentional; slice 2 will add direct kid-mode discovery.
**Capabilities**: None — open to all signed-in staff. `/subjects/:id/draw` auto-enters kid mode so the child can use it without staff navigating away.
**Data**: [character_sheets](SCHEMA.md#character_sheets). [entries](SCHEMA.md#entries) — reads `kind='skill_measure'` rows via `entriesForSubjectProvider` to power the Skills section (`latestSkillValues`); also reads `kind='week_log'` entries for Spells (from `weekLog.spell`) and Allies (from `weekLog.ally`). Avatar bytes route through the shared `person-photos` Storage bucket + signed-URL pipeline (same as `subjects.photo_url` and `members.avatar_url`) but are written to `character_sheets.avatar_url`, not `subjects.photo_url`.
**Surfaces**:
- *DrawSelfScreen* — `lib/features/world/draw_self_screen.dart`. Full-bleed kid-mode finger-drawing canvas; 10-color palette + 3 brush sizes; undo + clear; "That's me!" saves the rasterised PNG via `CharacterSheetActions.setDrawnAvatar`. Auto-enters kid mode in `initState` (microtask-deferred); exits on `dispose`. Pins the locked route so system-back can't escape to staff screens.
- *CharacterSheetScreen* — `lib/features/world/character_sheet_screen.dart`. The "Me" screen — drawn avatar + chosen name + emerging title + age/week/world chips + RPG sections. Now aggregates four new sections from existing entry data: **Skills** (the canonical 60-skill catalog via `latestSkillValues(entries)`, rendering only skills that have data with the ▲/▼ delta; a `_SkillRow` taps through to its progression at `/skills/:subjectId/:skillId`; "Log a measurement" opens `showSkillMeasureSheet`); **Spells** (unique words earned from `weekLog.spell` across all week-log entries); **Allies** (unique named collaborators from `weekLog.ally` across all week-log entries); **Quests** (curriculum world progress + verb practice — the long game made visible). Each section carries a `_SystemGameLink` chip that resolves the game under that RPG system via `systemThinkingGameProvider` and opens `showThinkingGameSheet`. Staff-facing for now; per-age surfaces (soft for 4–6, full for 7–12) come in later slices.
- *The 60-skill catalog* — `lib/features/action_words/verb_skills.dart`. `VerbSkill` (verbId, name, `SkillMeasureKind` {seconds/count/frequency/rating}, higherIsBetter, how, week1, week10, derived id `<verb>.<name>`) + `kVerbSkills` (5 per verb × 12 = 60, from docs/VISION.md 2026-06-30 "every verb has skills underneath it") + `skillsForVerb` / `verbSkillById`. The canonical source of truth; unit-tested (`verb_skills_test.dart`, 8 cases).
- *Skill measure model + capture sheet* — `lib/features/world/skill_measure.dart`. `MeasurableSkill` is now the DISPLAY shape DERIVED from the 60 `kVerbSkills` (emoji from the verb, unit from the measure, hint = the "how"); `measurableSkillById`; `SkillMeasure.fromEntry`; `latestSkillValues(entries)` (per-skill latest + previous for the delta arrow); `SkillArc` + `skillArcFor(entries, skillId)` (the FULL series → first/latest/min/max/reps + direction-aware `best`/`improvement`, for the progression curve); `showSkillMeasureSheet(...)` — a glass sheet that picks VERB → skill (grouped, not a 60-chip wall) + shows the how + anchors, records via `EntryActions.recordSkillMeasure` → `kind='skill_measure'` entry. Unit-tested (`skill_measure_test.dart`, 7 cases incl. the SkillArc group).
- *SkillDetailScreen* — `lib/features/world/skill_detail_screen.dart`. `/skills/:subjectId/:skillId`: one skill's progression (docs/VISION.md "the number IS the story") — the current number, a `_SkillSparkline` (flipped for speed skills so improving always reads as UP), the delta from day one + the affirmation ("they practiced it N times — now it belongs to them"), an `_EmptyArc` first-rep state, "Practice again" reopens the recorder. Reached by tapping a skill row on the character sheet.
- *Character sheet providers* — `lib/features/world/character_sheet_providers.dart`. `characterSheetForSubjectProvider` (StreamProvider.autoDispose.family by subjectId → `db.characterSheetsDao.watchForSubject`); `CharacterSheetActions` Notifier with `setDrawnAvatar` (routes through `PhotoService.uploadOnly` with `entityKind: 'character_sheet', entityId: subjectId`) and `setChosenName`.
**Depends on**: Subjects (subject card is the entry point; `subjectByIdProvider` read on the Me screen), Kid mode (DrawSelfScreen auto-enters), Photos (avatar bytes through `PhotoService.uploadOnly` + signed-URL render via `PersonAvatar`), Entries (reads `skill_measure` + `week_log` entries for character sheet synthesis), Action Words (`systemThinkingGameProvider` + `showThinkingGameSheet` from `lib/features/action_words/thinking_games.dart` + `widgets/thinking_game_sheet.dart`).
**Consumed by**: Subjects (`subject_detail_screen.dart` imports `character_sheet_providers.dart` and renders `_WorldSelfTile`).
**Last verified**: 2026-06-07

---

## Subjects
**Path**: `lib/features/subjects/`
**Purpose**: The child / student / patient record. Profile, health intake, photo, drop-off / pickup, guardian links.
**Personas served**: Maya (manages roster), All staff (read), Lauren / Devon (read their own via Family lens).
**Discovery surfaces**:
- Routes: `/groups/:id/students/new`, `/groups/:id/students/:sid`, `/groups/:id/students/:sid/edit`, `/subjects/:id/health`
- Omnibox: yes — "{FirstName} {LastName}" (per subject), "Add a {subject label} · {Group.name}" (action)
- Slash: subject resolution underpins `/log {kid}`
- Drawer: no
- Settings: no — subjects are top-level
**Capabilities**: Read: all members of the space. Write: `can_manage_space` (create) and `can_observe` (some inline edits).
**Data**: [subjects](SCHEMA.md#subjects), [guardians](SCHEMA.md#guardians), [subject_guardians](SCHEMA.md#subject_guardians)
**Surfaces**:
- *Subject detail* — `lib/features/subjects/subject_detail_screen.dart`. Profile + guardians + recent observations. Carries a "Snap work" chrome `IconButton` (calls `snapWork` from `work_sample_capture.dart`; camera on mobile, gallery picker off-mobile; offline-safe attachment-id contract). Below the inline sections renders a "Their work" `CollapsibleSection` containing `WorkGallery`.
- *Subject edit* — `lib/features/subjects/subject_edit_screen.dart`. Create / update form.
- *Health profile screen* — `lib/features/subjects/health_profile_screen.dart`. Medical intake (allergies, dietary, IEP, etc.).
- *Work gallery* — `lib/features/subjects/widgets/work_gallery.dart`. `WorkGallery(subjectId:)` — horizontal thumbnail strip of all `kind='work_sample'` entries for the child; tap to view full photo; star button toggles `in_book` flag via `EntryActions.setWorkSampleInBook` (curate for the Summer Book).
- *Work sample capture* — `lib/features/entries/work_sample_capture.dart`. `snapWork(context, ref, {subjectId, groupId, subjectName})` — standalone async helper called from the subject-detail "Snap work" action; handles pick → offline-safe upload → `EntryActions.createWorkSample`; no new route.
**Depends on**: Groups, Guardians, Photos, Entries (work_sample kind — `createWorkSample` + `setWorkSampleInBook` in `EntryActions`; `entriesForSubjectProvider` filtered by `EntryKind.workSample` in `WorkGallery`).
**Consumed by**: Attendance, Entries, Exports, Family, Messages, Surveys, Incidents (`subject_detail_screen.dart` imports `subject_incidents_section.dart`; `SubjectIncidentsSection` + jump chip render in the gated Incidents section), World (subject_detail_screen imports `character_sheet_providers.dart`; `_WorldSelfTile` is the entry point for the World feature).
**Last verified**: 2026-07-13

---

## Surveys
**Path**: `lib/features/surveys/`
**Purpose**: Anonymous questionnaires kids fill out themselves — director taps "Start a new survey" on a template, hands the device to a kid, who picks a reader voice + tells us their age band / grade / school on the About-you page, then answers one-question-per-page. No kid name is ever attached to the response.
**Personas served**: Maya (reviews cross-cohort trends via the table view), Ava (kid-mode take). Guardians (Lauren, Devon, Helen, Marcus) don't reach the survey surface.
**Discovery surfaces**:
- Routes: `/surveys`, `/surveys/:templateId`, `/surveys/:templateId/take`, `/surveys/:templateId/table`
- Omnibox: yes — "Surveys"
- Slash: none
- Drawer: yes — "Surveys" (canonical nav, position between Insights and Vehicles)
- Settings: no — surveys are top-level
**Capabilities**: None for taking. Authoring templates is gated by `can_manage_space`.
**Data**: [survey_responses](SCHEMA.md#survey_responses), [survey_picker_options](SCHEMA.md#survey_picker_options). Templates live in code today (no `survey_templates` table yet).
**Surfaces**:
- *Survey index* — `lib/features/surveys/survey_list_screen.dart`. List of templates with a per-template completed-response counter.
- *Survey template detail* — same file. Big "Start a new survey" button + history strip linking to the table view. No kid roster (responses are anonymous).
- *Survey take screen* — `lib/features/surveys/survey_take_screen.dart`. Generates a fresh response id per landing (no resume). Page 0 is the combined About-you surface (voice picker + age band / grade / school chips + Start). Auto-enters kid mode; 5-tap top-right corner is the staff-exit gesture.
- *Survey table* — `lib/features/surveys/survey_table_screen.dart`. One row per response, anonymized (recorded-at timestamp + identity columns + answer slots). Status filter (all / completed / drafts). CSV export.
**Depends on**: Kid mode, Voice (Deepgram Aura 2 TTS).
**Consumed by**: Insights (low-signal survey detection).
**Last verified**: 2026-06-01

---

## Tasks
**Path**: `lib/features/tasks/`
**Purpose**: To-do list with optional subject linkage. Promotion destination from Captures.
**Personas served**: All staff (Maya delegates, Jordan + Coach Sam do).
**Discovery surfaces**:
- Routes: `/tasks`, `/tasks/new`
- Omnibox: yes — "Tasks"
- Slash: `/tasks`
- Drawer: yes — "Tasks" (main destinations, position 4)
- Settings: no
**Capabilities**: None — open to all signed-in staff.
**Data**: [tasks](SCHEMA.md#tasks)
**Surfaces**:
- *Tasks screen* — `lib/features/tasks/tasks_screen.dart`. Pending list + completed-today.
- *Task screen* — `lib/features/tasks/task_screen.dart`. Create / edit one task.
**Depends on**: Subjects (optional link), Captures (promotion source).
**Consumed by**: Today (open-tasks count), Captures (promotion destination).
**Last verified**: 2026-05-21

---

## Curricula (Through My Eyes)
**Path**: `lib/features/curricula/`
**Purpose**: Editorial reference content — a 3-week / 6-session photography curriculum ("Through My Eyes") for ages 5-7. Each session has setup instructions, a game (rules + duration), a "looking together" guided discussion, 3 expandable AI label examples, an end ritual, a takeaway highlight, and a materials list. A second view, "Vocabulary Journey," surfaces which photography terms attach to which session (~30 terms across 6 sessions). On top of the at-a-glance summary, a **runnable beat-by-beat presenter** lets a host drive a scripted session live — each beat is one calm bento slide (the say-this lines, the stage cue, the call-and-response, tap-to-expand the full verbatim script, a per-beat opt-in countdown), with a "Start shooting" handoff on game beats and a "Cast to the room" option. Shipped as a Dart const today; a per-space overrides table can layer on later if directors ask to author their own sessions.
**Personas served**: All staff — particularly Coach Sam / specialists running a structured program; Maya as a curriculum reviewer. The session presenter additionally serves the host actually running the hour in the room.
**Discovery surfaces**:
- Routes: `/settings/curricula/photo` · `/session/run?slug=<slug>&block=<blockId?>` (the beat-by-beat presenter)
- Omnibox: yes — "Through My Eyes" (keywords: through my eyes, photo curriculum, photography, camera, photo program, gallery, six games) · "Run session · {title}" — one per session with a written script (keywords: run session, run the session, present session, beat by beat, script, s{n}, photo session)
- Slash: no
- Drawer: no
- Settings: yes — "Through My Eyes" row under Resources group (alongside Teacher Toolkit)
- Run sheet: yes — a "Run the session" hero tile appears on a photo block's run sheet (`block_run_sheet_screen.dart` `_PhotoRunBento`) when the block's stamped curriculum slug has a written script, alongside "Run photo turns".
**Capabilities**: None — open to every signed-in staff member. Read-only in Wave 164. Guardian-gated at the omnibox layer (router redirect would bounce them anyway); the session-presenter omnibox entry is also guardian-gated.
**Data**: None (Wave 164, Dart const catalog). Stable per-session slugs (`photo.s1.click-game`, etc.) are the contract a future overrides table would join on. The session SCRIPTS join on the same slug via `scriptForSession(slug)`.
**Surfaces**:
- *Photo curriculum catalog* — `lib/features/curricula/photo_curriculum.dart`. Dart const `photoCurriculum`: 6 sessions × 9 fields (slug, number, week, day, title, color, glyph, bigIdea, setup, gameName, gameRules, gameDuration, lookingTogether, aiExamples, endRitual, takeaway, materials). Also `vocabJourney`: 6 stops × terms + natural note.
- *Photo curriculum screen* — `lib/features/curricula/photo_curriculum_screen.dart`. Session selector dots (6, color-progressed), SegmentedButton view toggle (Sessions / Vocabulary), session body with SectionCards for setup/game/looking/end-ritual/takeaway/materials + tappable-expand AI example cards, vocab journey with one card per session + total + sample certificate.
- *Session script model* — `lib/features/curricula/session_script.dart`. `SessionScript{slug, sessionNumber, title, beats}` + `SessionBeat{time, kind (BeatKind), title, startMinute?, durationMinutes?, keyLines, script (List<ScriptLine>), callResponse?, game (BeatGame?), vocabCards}`. Editorial, const; say-lines verbatim.
- *Session 1 script* — `lib/features/curricula/photo_s1_script.dart`. `photoSession1Script` (slug `photo.s1.click-game`, 17 beats) + `scriptForSession(slug)` resolver (null when no script written yet).
- *Session run presenter* — `lib/features/curricula/session_run_screen.dart`. `SessionRunScreen` (route `/session/run`): `EdgeScaffold` with a Cast pill, the current beat as a swipe-able bento slide (eyebrow time·kind → Fraunces title → tinted "Say this" keyLines → italic stage cue → call-and-response chip → tap-to-expand full script styled by ScriptLineKind → game block + "Start shooting" → vocab word-cards), a pausable per-beat countdown (Timer), an advance bar (Next · {next beat}), and the full sequence as a tappable vertical timeline. Slug-not-found → EmptyState. Kind→accent via ActivityPalette + AppColors.onAccent.
**Depends on**: Nothing — pure content. The presenter hands off to `/activity/photo-turns` (photo turns) on game beats and `showCastToRoom` for casting.
**Consumed by**: The block run sheet (`block_run_sheet_screen.dart`) surfaces "Run the session" when a block's curriculum slug has a script. Future: a curriculum could attach to schedule blocks as the activity series for an afternoon, with each session auto-becoming a scheduled block.
**Last verified**: 2026-06-22

---

## Toolkit
**Path**: `lib/features/toolkit/`
**Purpose**: Two sibling surfaces in one folder — the in-app Teacher Toolkit (30 reference teaching moves, searchable) and the Printable Toolkit (offline PDF generation for physical binder pages: verb cards, spell-timer cards, verb→job reference, gesture guide, reference card).
**Personas served**: All staff. Especially Jordan (in-the-moment scripts when it falls apart), Coach Sam (door-greeting + cohort culture), Brianna (specific-notice + 5:1 ratio while learning the room), Lauren (parent-text language). Print surface primarily benefits Pat (substitute can walk in with the binder).
**Discovery surfaces**:
- Routes: `/settings/toolkit` (Teacher Toolkit — in-app reference), `/print` (Printable Toolkit — PDF generation)
- Omnibox: yes — "Teacher Toolkit" (id `page.toolkit`, keywords cover toolkit, scripts, phrases, celebrate, praise, tough, angry, meltdown, parent text, morning, door greeting, cool down, repair, boundary, self care, burnout) → `/settings/toolkit`; "Printable toolkit" (id `page.print`, keywords: print, printable, toolkit, binder, verb cards, laminate, pdf, spell cards, reference card, paper, offline) → `/print`
- Slash: no
- Drawer: no
- Settings: yes — "Teacher Toolkit" row under Resources group (reaches `/settings/toolkit`). `/print` is not in Settings — omnibox is its discovery path.
**Capabilities**: None — open to every signed-in staff member. Read-only / PDF-generation only.
**Data**: None. Both surfaces are fully local — Dart const catalogs + PDF generated on-device and handed to the OS print/share sheet. No DB rows, no Storage uploads, no migration.
**Surfaces**:
- *Toolkit catalog* — `lib/features/toolkit/toolkit_catalog.dart`. Dart const `toolkitCatalog`: 5 categories × 6 tools, each with stable slug + name/when/instead/tryThis/why/quick fields.
- *Toolkit screen* — `lib/features/toolkit/toolkit_screen.dart`. Search across all tools, category strip, expandable tool detail card with Instead/Try pair + Why-this-works rail + optional Quick-script chip. Route `/settings/toolkit`.
- *Print toolkit screen* — `lib/features/toolkit/print_toolkit_screen.dart`. `/print`: a menu of PDF generators — "Verb cards" (12 full-page cards), "Timer spell cards" (FREEZE/MOVE/CREATE/SHARE/WONDER), "Verb→job reference" (which job each verb pick becomes), "Gesture guide", "Reference card", "Wall reveal cards", "World summary posters", "Wall question deck" (50 day-by-day wall-question posters from the 50-day journey, one per day; reads `worldBlocksProvider`). Each tile triggers the corresponding function from `toolkit_pdf.dart` via the OS print sheet. Word-forward (Helvetica; emoji sticker on after laminating). NOTE: the per-child Summer Book is NOT here — it lives on each kid's Book screen.
- *Toolkit PDF* — `lib/features/toolkit/toolkit_pdf.dart`. PDF generation functions: `printVerbCards`, `printTimerSpellCards`, `printVerbJobReference`, `printWallQuestionDeck` (takes `List<WorldBlock>`; 50 full-page wall-question posters — day number + block name + the question, built-in Helvetica), and others. Built-in Helvetica throughout — offline-safe, no `PdfGoogleFonts` call.
**Depends on**: Action Words (`verb_roles.dart` + `world_blocks.dart` + `curriculum.dart` imported by `toolkit_pdf.dart` / `print_toolkit_screen.dart` for the verb→job reference, wall-question-deck PDF, and world-summary/reveal-card PDFs).
**Consumed by**: Nothing.
**Last verified**: 2026-06-08

---

## Speak
**Path**: `lib/features/speak/`
**Purpose**: Paste any prompt / quote / block, pick a voice, and hear it read aloud while it takes the stage as big, elegant, editorial type — one line at a time, the spoken word swelling in weight as the voice lands on it. A read-aloud showpiece for the room and a follow-along aid for emerging readers.
**Personas served**: All staff. Especially Jordan + Coach Sam (run a prompt with the room), Lauren-side read-aloud for emerging readers. Staff-facing (gated `viewer is! GuardianViewer`).
**Discovery surfaces**:
- Routes: `/speak`
- Omnibox: yes — "Speak" (keywords cover speak, read aloud, read it, karaoke, subtitles, captions, lyrics, text to speech, voice, narrate, prompt, quote)
- Slash: `/speak` (aliases: `read`, `karaoke`, `subtitles`, `narrate`, `voice`)
- Drawer: no
- Settings: no
- Also on the Tools shelf — registered as a runnable `ThinkingTool` (`id: speak` → `/speak`) in `runnableThinkingTools`.
**Capabilities**: None — open to every signed-in staff member. Read-only / ephemeral.
**Data**: None synced. Audio (`.mp3`) + char-level alignment (`.json`) are cached server-side in the public `tts-cache` Storage bucket, keyed by a content hash — no PowerSync tables, nothing persisted on-device. Only the (staff-authored) prompt text is sent; no child PII. Two variable display fonts (Fraunces + Space Grotesk) are bundled under `assets/fonts/` (OFL-licensed; NOT runtime-fetched, so the stage works offline).
**Surfaces**:
- *SpokenScript model* — `lib/features/speak/spoken_script.dart`. Pure timing + typography helpers (unit-tested in `test/unit/spoken_script_test.dart`): `SpokenWord` (text + start/end), `SpokenScript` (audio url + words), `SpokenLine` (a phrase + its window), `wordsFromAlignment` (ElevenLabs char-alignment → words), `linesFromWords` (words → short editorial lines on punctuation/length), `currentWordIndex` / `lineIndexAt` (which word/line at a position), `wordEmphasis` (ALL-CAPS / long / "!" → an emphasis score the modes scale by — auto-hierarchy with no markup), `endsSentence` (drives the "hold a beat on the period" rhythm).
- *TypeTheme* — `lib/features/speak/type_theme.dart`. The two type voices: `SpeakType.serif` (Fraunces) + `.grotesque` (Space Grotesk), with per-voice variable-font axes (`fontVariations`), rest/active weights, tracking, and swell timing. The live toggle flips between them.
- *SpeakVoices* — `lib/features/speak/speak_voices.dart`. The `SpeakVoice` catalog (voice_id + label + colour palette) the picker offers — six voices; first is the default. IDs are NOT secret (the API key is); add/swap by editing the list, no server change. The chosen id rides to the Edge Function, which caches audio per (voice, text).
- *SpeakPalette + LivingBackground* — `lib/features/speak/speak_palette.dart`, `living_background.dart`. Voice = colour: each voice carries a `SpeakPalette` (gradient poles + accent). The stage's background is a slow drifting gradient in that palette + a vignette + faint static grain; the active word glows faintly in the accent. Colour lives in the ambience — the ink stays near-white for legibility.
- *Presentation modes* — `lib/features/speak/speak_presentation.dart` (the `SpeakPresentation` enum + the `implementedSpeakModes` list the pickers read) and the per-mode views. All read the same timeline (lines / words / position), so the user flips between them live (a "Show" picker on input + a cycle button in the perform chrome). Eleven modes, Editorial leads (it is the calm, designed pull-quote — default): **Editorial** (`editorial_view.dart` — oversized hanging quote mark, justified serif column, accent underline on the spoken word — restraint over glow; the new default), **Stage** (`speak_stage.dart` — one line at a time, the spoken word swelling in weight, past→present→future brightness gradient), **One Big Word** (`one_big_word_view.dart` — one giant word filling the frame, punching in on the beat), **Stack** (`stack_view.dart` — lines accumulate teleprompter-style, newest brightest at the bottom), **Collage** (`collage_view.dart` — each phrase a seeded editorial poster: varied sizes/weights/angles, stable per line, the spoken word illuminating within it), **Spotlight** (`spotlight_view.dart` — the whole passage dim, the spoken word igniting in place; doubles as a reading aid), **Mural** (`mural_view.dart` — the WHOLE text as one fixed wall of type at varied sizes, scaled to fill the screen; the spoken word lights up in place with zero reflow — size + weight are fixed per word so the wall never moves), **Grid** (`grid_view.dart` — one word per fixed cell, cols ≈ √n, the spoken cell lighting up), **Justified** (`justified_view.dart` — the whole text as one flush justified block via `Text.rich` spans, the spoken word brightening in place), **Index** (`index_view.dart` — a numbered contents page of the lines, the spoken row lit), **Shape** (`shape_view.dart` — the words arranged around a ring, the spoken one lit). The "Show" picker (input) lists all; the perform chrome opens a mode menu (`showGlassSheet`). The "fixed-layout" modes (Mural/Grid/Justified/Index/Shape) keep size + weight constant per word so only the highlight moves — no reflow.
- *SpeakService* — `lib/features/speak/speak_service.dart`. Calls the `tts-subtitles` Edge Function (ElevenLabs `with-timestamps`, key brokered server-side per docs/SECRETS.md), builds a `SpokenScript`, plays via `just_audio`; exposes `currentPosition` (read per-frame by the stage's ticker for voice-accurate flips). Idempotent dispose; playback degrades silently.
- *Speak screen* — `lib/features/speak/speak_screen.dart`. Orchestration root: state for the current prompt, voice, type, mode, script, and history. Renders the input composer (via `SpeakInputControls`) or hands off to `SpeakPerformer` once a script is ready. Manages immersive-mode entry/exit (`speakImmersiveProvider`). Loading shows an inline "Voicing…" spinner; failure shows a "not set up / offline" live-region note.
- *Speak input controls* — `lib/features/speak/speak_input_controls.dart`. The pre-performance pickers: `VoiceSelector` (the six-voice tile row), the type toggle (serif / grotesque), the "Show" mode picker, and the recents strip (`SpeakHistoryEntry` list — tap to replay instantly).
- *Speak performer* — `lib/features/speak/speak_performer.dart`. The performance host. Drives the active mode view from a per-frame ticker that reads `currentPosition` directly (60fps-accurate word/line flips; ticker idles when paused so no 60fps spin after the voice ends). Tap-to-pause/resume. Finished read dims + shows replay glyph. Mounts the `_TransportBar` (play/pause button, drag-to-seek scrubber, elapsed/total time display). Perform chrome (mode menu / type toggle / New text / Replay) lives here. Full-bleed with `LivingBackground` + the active mode view on top.
- *Speak history* — `lib/features/speak/speak_history.dart`. `SpeakHistoryEntry` + `SpeakHistory` (SharedPreferences-backed). Stores text + voice + the full `SpokenScript` (timings + audio URL). Replaying an entry calls nothing: the audio URL points at the server cache and the timings come from storage. Newest-first, deduped by (text, voice), capped at 20; "Clear" wipes all entries.
- *Speak immersive provider* — `lib/features/speak/speak_immersive.dart`. `speakImmersiveProvider` (Notifier<bool>): true while the performance is on screen; AppShell watches it to hide the omnibox bar. The input composer is NOT immersive — it keeps the omnibox so the user can navigate away while typing.
- *tts-subtitles Edge Function* — `supabase/functions/tts-subtitles/index.ts`. Brokers `ELEVENLABS_API_KEY`; caches audio + alignment by content hash in the `tts-cache` bucket; authenticated-only; CORS-allowed for web. Deployed; `ELEVENLABS_API_KEY` set as a Supabase secret. The feature is live.
**Depends on**: Voice (shares the `tts-cache` bucket + the brokered-key Edge Function pattern from `tts-generate`); Tools (registered there as a runnable tool); bundled Fraunces + Space Grotesk fonts (`assets/fonts/`).
**Consumed by**: Tools (lists Speak as a runnable `ThinkingTool`).
**Last verified**: 2026-06-05

---

## Tools (Thinking Tools)
**Path**: `lib/features/tools/`
**Purpose**: One searchable shelf that unifies the two halves of the "thinking tools" vision (docs/THINKING_TOOLS.md) — the runnable activities (run with the room) and the editorial reference cards — so a staffer browses, then either launches a tool or reads the move. Phase 1 is a view-model adapter over both existing sources; Phases 2–3 broaden the content past the classroom and open it to contributors.
**Personas served**: All staff. Especially Coach Sam + Brianna (grab a discussion / warm-up to run), Jordan (read the reference move in the moment).
**Discovery surfaces**:
- Routes: `/tools`
- Omnibox: yes — "Tools" (keywords cover tools, thinking tools, thinking, toolkit, activities, run with the room, discussion, frameworks, mental models)
- Slash: `/tools` (aliases: `toolkit`, `thinking`, `frameworks`, `activities`)
- Drawer: yes — "Tools" (Activities group, position before Present)
- Settings: no
**Capabilities**: None — open to every signed-in staff member (staff-facing; gated `viewer is! GuardianViewer` in the omnibox). Read-only.
**Data**: None — pure content (a Dart adapter over the toolkit const catalog + a curated runnable list).
**Surfaces**:
- *ThinkingTool model* — `lib/features/tools/thinking_tool.dart`. The unified view-model + `ThinkingTool.fromToolkit` (reference adapter), `runnableThinkingTools` (curated runnable list), `buildToolLibrary()` (merged shelf, runnable-first).
- *Tools screen* — `lib/features/tools/tools_screen.dart`. Searchable list of `FeatureCard` tiles; runnable tiles launch `tool.route`, reference tiles open a glass reading sheet (when / why / script).
**Depends on**: Toolkit (reads `toolkitCatalog`); the activity routes (`/activity/*`, `/live/*`) and Speak (`/speak`) it launches into.
**Consumed by**: Nothing yet.
**Last verified**: 2026-06-03

---

## Today
**Path**: `lib/features/today/`
**Purpose**: The daily launchpad. Root destination. Context-driven cards: a contextual lead that surfaces the one move that matters right now, then the cohort rooms, then state-driven actions (pending captures / tasks / vehicle out), curriculum plan, and director pulse.
**Personas served**: All staff (Jordan + Coach Sam's home base), Maya / Pat (oversight cards), Coach Sam / Brianna (identity strip surfaces "Specialist · Coach" / "Substitute today" so Sam and Brianna orient at a glance).
**Discovery surfaces**:
- Routes: `/` (TodayScreen)
- Omnibox: yes — "Today"
- Slash: `/today` (alias `/home`)
- Drawer: yes — "Today" (main destinations, position 1)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Cards self-gate by capability (DirectorPulseCard renders only when `viewer.isDirector` AND there's a signal to flag).
**Data**: Reads [spaces](SCHEMA.md#spaces) (`capabilities['phase_windows']` via `dayPhaseWindowsProvider`; drives `dayPhaseProvider`), [schedule_blocks](SCHEMA.md#schedule_blocks) (via `liveBlockProvider` / `liveBlockForGroupProvider` in `context_lead.dart` — the live-block path of the contextual lead; room override via `contextRoomOverrideProvider` can narrow to one group's block), [attendance_records](SCHEMA.md#attendance_records) (via `arrivalProgressProvider` — cross-cohort in-building count for the arrival lead), [captures](SCHEMA.md#captures) (open count for `QuickActions`), [tasks](SCHEMA.md#tasks) (open count for `QuickActions`), [groups](SCHEMA.md#groups) (per-group day state for cohort rooms; also loaded by `ContextPill` to populate the room picker), [entries](SCHEMA.md#entries) (curriculum plan cards), [members](SCHEMA.md#members) (member_certifications consumer for director pulse), [dismissed_insights](SCHEMA.md#dismissed_insights) (via Insights). Does not write to any table.
**Surfaces**:
- *Today screen* — `lib/features/today/today_screen.dart`. Card list, refresh on pull.
- *Contextual lead* — `lib/features/today/context_lead.dart`. `computeContextLead()` (pure function, unit-testable) + `contextLeadProvider` (thin Riverpod adapter) + `ContextRoomOverride` / `contextRoomOverrideProvider` (session-scoped, non-persisted "which room am I in" pin). Computes the single "what matters right now" move from (role × day phase × live schedule block × curriculum world × outdoor flag × room override). Returns a `ContextLead` with an eyebrow, title, one-line context, tint tone (`go`/`trip`/`pickup`/`calm`), primary `ContextMove` (route + label + icon), and ≤2 secondary chips. Returns null for non-loggers and after hours (closed phase). Reads `liveBlockProvider` / `liveBlockForGroupProvider(override)` + `arrivalProgressProvider` + `currentWorldProvider` + `dayPhaseProvider` + `contextRoomOverrideProvider`. No writes, no new table. **Program-time downtime lead** (no live block during the `program` phase): primary move is "Pick an activity" → `/breaks`; secondary moves are "Capture a moment" → `/captures/new` and "Schedule" → `/schedule` (+ "Insights" for directors).
- *Context pill* — `lib/features/today/widgets/context_pill.dart`. `ContextPill` renders only for multi-room staff; shows the room + block the lead is currently reading from ("Kiwi · Arts & Crafts"). Tapping opens a glass sheet room picker (`_showRoomPicker`) — "Across your rooms" (auto) or any individual room — that writes to `contextRoomOverrideProvider`. Amber-tinted when no block is live in the pinned room (the "nothing to act on" state). Self-hides for single-room staff and non-loggers. Override is session-scoped; resets on app restart by design.
- *Right-now card* — `_RightNowCard` in `lib/features/today/widgets/today_sections.dart`. Renders `contextLeadProvider`. Full-bleed `Card` tinted by `ContextTone`; primary move is a filled chip, secondary moves are outlined chips. Embeds `ContextPill` above the copy for multi-room staff. Sits immediately after the live-session banner, before the cohort rooms (briefing reorg: the rooms are now position 2, right under the lead).
- *Live-session banner* — `lib/features/live_session/live_session_banner.dart` (cross-feature, mounted in `today_sections.dart`). Auto-shows at the top of Today when `activeSessionsProvider` has active sessions; hidden when none. One-tap join pushes `/join?code=…&game=…`. Multiple live sessions → picker sheet.
- *Cohort rooms* — `_GroupTodayCard` list in `lib/features/today/widgets/today_sections.dart`. Per-group card with status-dot + room glyph + NowNextStrip + attendance state pills. Promoted to position 2 (directly under the lead) in the briefing reorg. Desktop: 2-column wrap. Phone/tablet: vertical stack.
- *Quick actions* — `lib/features/today/widgets/quick_actions.dart`. State-driven launchpad: vehicle-out return / check-out (`_VehicleQuickTile`), open-capture inbox count, open-task count. Renders nothing when all tiles would be empty. Static nav tiles (New observation, Observations, Surveys, Insights, Team) were removed in the briefing reorg — those are reachable via the omnibox catalog and the drawer.
- *Director pulse card* — `_DirectorPulseCard` in `today_sections.dart`. Director-only proactive pulse: absent kids, cohorts on substitute coverage, certs expiring within 30 days, incidents needing a family call. Renders nothing on "all clear." Tappable pulse rows route to the relevant surface (checklist / schedule / team / incidents). Shipped Wave 36; rows gained navigation targets in a subsequent wave.
- *Identity strip* — `_IdentityStrip` in `today_sections.dart`. Renders only for specialists ("You are: Specialist · Coach") and substitutes ("You are: Substitute today"); silent for director / lead_teacher / teacher / guardian / kitchen. Tap → `/settings/roles`. Specialist without a specialty gets a tertiary-tinted hint. Shipped Wave 40.
- *Leading-today card* — `lib/features/schedule/widgets/leading_today_card.dart` (cross-feature). Staff member's blocks + cabin notes for today.
- *Covering-today card* — `_CoveringTodayCard` in `today_sections.dart`. Fallback for a specialist or substitute with no assigned block; points them to the runbook. Self-hides when they have blocks (leading-today takes over).
- *Unread messages card* — `_UnreadMessagesCard` in `today_sections.dart`. Surfaces every (subject, guardian) thread with at least one unread family-sent message. Hidden when inbox is empty.
- *Today's plan section* — `_TodaysPlanSection` in `today_sections.dart`. Gated to prep and program phases only (hidden during arrival, pickup, closed — those are noise-free moments). Before the journey starts: shows `_ThisWeekWorldCard` (director setup prompt or nothing). Once a world is active: wraps the curriculum quartet in a `CollapsibleSection` ("Today's plan · {world} · Day N", collapsed by default) to lead with the action and tuck the plan one tap away. Contains `_ThisWeekWorldCard` + `_TodaysFocusCard` + `_TodaySkillCard` + `_TodayThinkingCard`.
**Note on removed surfaces** (briefing reorg): `YourToolsStrip` (`lib/features/today/widgets/your_tools_strip.dart`) was removed from Today and rehomed into the drawer's "Your tools" section (see Drawer). `_ChecklistCallToAction` was removed (the arrival lead covers it). The static nav tiles from `QuickActions` (New observation, Observations, Surveys, Insights, Team) were stripped — those go through omnibox + drawer.
**Depends on**: nearly everything, including Schedule (`liveBlockProvider` + `leading_today_card.dart` + `schedule_block_id` reads via `contextLeadProvider`), LiveSession (`live_session_banner.dart` cross-imports via `today_sections.dart`), Pickup (pickup-phase lead routes to `/pickup`), Spaces (`dayPhaseWindowsProvider` reads `spaces.capabilities['phase_windows']`), LiveBoard (`role_tools.dart` links `/live-board` — now surfaced in the drawer, not Today directly), Action Words (`context_lead.dart` reads `currentWorldProvider`; `today_sections.dart` renders `_ThisWeekWorldCard`, `_TodaysFocusCard`, `_ActionWordsCard`), Attendance (`arrivalProgressProvider` in `contextLeadProvider`).
**Consumed by**: Nothing — Today is a leaf.
**Last verified**: 2026-06-19


---

## Vehicles
**Path**: `lib/features/vehicles/`
**Purpose**: Fleet management — create / edit vehicles, pre-trip checkout, post-trip checkin (inspection trail).
**Personas served**: Maya (manages fleet), All staff with `can_drive` (checkout / checkin), Coach Sam (trip days).
**Discovery surfaces**:
- Routes: `/vehicles`, `/vehicles/new`, `/vehicles/scan`, `/vehicles/:id`, `/vehicles/:id/edit`, `/vehicles/:id/checkout`, `/vehicles/:id/checkin` (old `/settings/vehicles*` paths redirect here — preserved for printed QR codes from before Wave 95)
- Omnibox: yes — "Vehicles", "{Vehicle.name}" (per vehicle), "Check out · {Vehicle.name}" (action, gated by `can_drive`), "Check in · {Vehicle.name}" (action, gated by `can_drive`), "Add a vehicle" (action, gated by `can_manage_space`)
- Slash: `/checkout {vehicle}` (alias `/co`), `/checkin {vehicle}` (aliases `/ci`, `/return`) — gated by `can_drive || can_manage_space`
- Drawer: yes — "Vehicles" (canonical nav, gated `canDrive || canManageSpace`; position between Surveys and Settings)
- Settings: yes — "Vehicles" row under {Space name} group
**Capabilities**: Read: all members. Create / edit: `can_manage_space`. Checkout / checkin: `can_drive` (which itself requires an active Driver cert).
**Data**: [vehicles](SCHEMA.md#vehicles), [vehicle_logs](SCHEMA.md#vehicle_logs), [member_certifications](SCHEMA.md#member_certifications) (Driver cert gates `can_drive`)
**Surfaces**:
- *Vehicles list* — `lib/features/vehicles/vehicles_list_screen.dart`. Fleet roster.
- *Vehicle detail* — `lib/features/vehicles/vehicle_detail_screen.dart`. One vehicle's record + recent log.
- *Vehicle edit* — `lib/features/vehicles/vehicle_edit_screen.dart`. Create / update form.
- *Vehicle scan* — `lib/features/vehicles/vehicle_scan_screen.dart`. Camera QR scanner that resolves a scanned vehicle deep link and routes to checkout / checkin.
- *Vehicle inspection* — `lib/features/vehicles/vehicle_inspection_screen.dart`. Pre-trip + post-trip checklist (same screen, different mode). QR PDFs now encode the custom-scheme deep link (`differentworld://v/<id>/<kind>`) — staff always have the app, so the scheme opens the app directly with no browser hop (Wave 171). Invite QRs intentionally keep the HTTPS path for the no-app-installed case.
**Depends on**: Members, Certifications.
**Consumed by**: Schedule (trip assignment), Insights (stale-vehicle signal).
**Last verified**: 2026-06-01

---

## Voice
**Path**: `lib/features/voice/`
**Purpose**: Voice dictation service — Deepgram WebSocket integration, used by the omnibox mic button.
**Personas served**: Jordan (primary — on-the-floor dictation), All staff (any voice composer).
**Discovery surfaces**:
- Routes: none — utility service
- Omnibox: yes — mic button in the composer bar
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: None — open to all signed-in staff. Requires mic permission at first use.
**Data**: None — audio is streamed, not stored.
**Surfaces**:
- *Deepgram voice service* — `lib/features/voice/deepgram_voice_service.dart`. WebSocket client; emits interim + final transcripts.
**Status**: voice dictation wired in THREE places — the omnibox composer mic, the observation-form body field, AND the capture-form body field. Capture mic shipped 2026-05-23 (Wave 38), closing the Jordan / Brianna floor-use gap. Free-text future fields can adopt the same pattern: form-local `DeepgramVoiceController`, snapshot `_voicePrefix`, append `transcript` on each update, tear down in dispose before the text controller.
**Depends on**: `DEEPGRAM_API_KEY` in `.env`, `record` plugin, mic permission.
**Consumed by**: Omnibox (composer mic — uses the shared `deepgramVoiceProvider` singleton), Entries (observation form body field — form-local `DeepgramVoiceController`), Captures (capture form body field — form-local `DeepgramVoiceController`).
**Last verified**: 2026-05-23

---

_Run 2026-06-07 (Play Today / Skills / System Games / Print Toolkit)_ — see discovery drift section for detail. Updates applied this run:
- **Action Words** — Routes extended: `/play-today` (DayRunScreen) added; confirmed in `router.dart`. Omnibox extended: `page.play-today` ("Play today") confirmed in `omnibox_catalog.dart`. Surfaces extended: `thinking_games.dart` (system field + `systemThinkingGameProvider`), `thinking_screen.dart` (Big Thinking deck + "Under each system" section), `widgets/thinking_game_sheet.dart`, `day_run.dart`, `day_run_screen.dart`. Status + Depends on + Consumed by updated.
- **World** — Data extended: `entries` (`kind='skill_measure'` + `kind='week_log'` reads). CharacterSheetScreen Surfaces entry rewritten to document Skills / Spells / Allies / Quests sections + `_SystemGameLink` chips + `showSkillMeasureSheet`. New surface: `skill_measure.dart`. Depends on extended: Entries + Action Words.
- **Toolkit** — Purpose rewritten to distinguish in-app Tools from Printable Toolkit. Routes extended: `/print` (PrintToolkitScreen) added; confirmed in `router.dart`. Omnibox extended: `page.print` ("Printable toolkit") confirmed in `omnibox_catalog.dart`. Surfaces extended: `print_toolkit_screen.dart` + `toolkit_pdf.dart`. Depends on updated to add Action Words.
- **SCHEMA.md** — `entries` table `kind` column updated to list `skill_measure`; World added to Consumers.
- Cross-link reconcile: World now claims `entries` in Data; `entries` Consumers now includes World — bidirectional. Toolkit claims no synced tables; no (feature → table) changes.

_Run 2026-06-07 (Staff feature cluster)_ — no discovery drift. Updates applied this run:
- **Staff** — new feature section added. Three routes confirmed in `router.dart`: `/runbook` (RunbookScreen), `/staff` (StaffLadderScreen), `/verb-jobs` (VerbJobsScreen). All three omnibox entries confirmed in `omnibox_catalog.dart`: `page.runbook` → `/runbook`, `page.staff-ladder` → `/staff`, `page.verb-jobs` → `/verb-jobs`. No drawer entries, no nav-destination entries, no settings rows — correct; these are contextual reference surfaces, not top-level destinations. `VerbJobsScreen` lives in `lib/features/action_words/` (not `lib/features/staff/`) because it shares `verb_roles.dart` + `verbs.dart` from that folder; noted in Surfaces + Depends on. Cross-link note: verb-missions in `verb_roles.dart` are reference challenge ideas — explicitly distinct from the catalog-managed Missions feature; distinction documented in both the Staff and Missions sections.
- **SCHEMA.md** — no changes. All three surfaces read bundled JSON assets; no synced tables, no migrations.
- Cross-link reconcile: Staff claims no synced tables; no (feature → table) or (table → feature) additions needed.

---

## Coverage gaps to track (auto-populated by persona-audit)

This section is intentionally left for the `persona-audit` agent to fill
in. Run `Agent persona-audit` to refresh.

---

## Drift / discovery warnings (auto-populated by feature-mapper)

_Run 2026-07-04 (chore/dedup-wave — shared widget extraction)_ — no unresolved discovery drift. No routes, omnibox entries, slash commands, drawer entries, settings rows, or schema changes were introduced by this refactor. Updates applied this run:
- `lib/features/entries/entry_photos.dart` deleted — confirmed no reference in FEATURES.md or SCHEMA.md. Clean.
- New shared widgets (`lib/shared/widgets/accent_edge_card.dart`, `sticky_save_bar.dart`, `cap_picker_sheet.dart`, `form_save_button.dart`; `lib/shared/prefs_bool_notifier.dart`) are internal layout/form helpers. No feature's discovery surface (route / omnibox / drawer / settings) changed. No FEATURES.md surface descriptions referenced the old private locations of these helpers.
- New feature-scoped widget extractions (`lib/features/action_words/widgets/kid_lock_shell.dart`, `kid_progress_dots.dart`, `thinking_game_blocks.dart`, `composer_sheet_body.dart`, `mini_accent_label.dart`, `world_sections.dart`, `present_stage.dart`; `lib/features/photos/widgets/attachment_photo_thumb.dart`; `lib/features/groups/widgets/group_chip_row.dart`, `group_picker_sheet.dart`) are internal decompositions of existing screens into sub-widgets. No FEATURES.md path references pointed to the old inlined code.
- `lib/features/voice/dictation_mixin.dart`, `lib/features/live_session/cast_stage_chrome.dart`, `lib/features/curricula/beat_kind_style.dart` — extracted mixins/helpers. Functional behavior unchanged; FEATURES.md surface descriptions (Voice, LiveSession, Curricula) remain accurate.
- `lib/shared/widgets/camera_chrome.dart` — modified (was already in `lib/shared/widgets/`; the dedup extracted common camera UI there). Already a shared widget; no path reference updated.
- **Pre-existing gaps (not introduced by this refactor)**: `lib/features/games/`, `lib/features/activity_forge/`, `lib/features/dev_flags/`, `lib/features/identity/`, `lib/features/launch/`, `lib/features/runtime/` have no FEATURES.md sections — these appear to be internal framework/infrastructure folders with no user-facing discovery surfaces of their own. `lib/features/game_content/` was the one gap WITH live discovery surfaces; **resolved 2026-07-04** — see the [GameContent](#gamecontent) section.
- SCHEMA.md: no changes — no migrations, no new tables, no sync-rule changes.
- Cross-link reconcile: none — no (feature → table) or (table → feature) links affected.

_Run 2026-06-01 (nav refactor)_ — no unresolved discovery drift after this run. Updates applied:
- Drawer field updated for 6 features now in `buildNavDestinations`: **Entries** (Observations), **Insights**, **Missions**, **LiveSession** (Board `/board`), **Surveys**, **Vehicles**. Missions and Board are the genuinely new additions; the others were already in the rail but not in the old hardcoded drawer.
- "Top-level orientation" blurb rewritten to reflect the full canonical list.
- Settings drop-in note for Missions removed (was `no — omnibox canonical discovery`; now `no` with drawer as the primary surface).
- SCHEMA.md: no changes — this refactor touched no synced tables and no migrations.
- Cross-link reconcile: none — only Drawer fields changed, no (feature → table) or (table → feature) links were affected.

_Run 2026-06-01 (content bank)_ — no unresolved discovery drift. Updates applied this run:
- **ActivityRuntime** — `**Data**` field rewritten: now lists `content_items` read via `bankedContentProvider` + `ContentBankDao`. Confirmed consumers: `this_or_that_screen.dart`, `letter_words_screen.dart`, `as_if_screen.dart`, `riddles_screen.dart`, `fact_or_fib_screen.dart`, `story_starters_screen.dart`, `rhyme_time_screen.dart` (7 screens read `bankedContentProvider`). Charades + live This-or-That confirmed NOT in the consumer list (curated floor only — deterministic order required). Growing the bank = adding seed migrations through Claude Code (docs/CONTENT_BANK.md §1.3) — noted inline.
- **ActivityRuntime** — Routes extended to include the five new DB-backed activity routes confirmed in `router.dart`: `/activity/riddles`, `/activity/breathe`, `/activity/fact-or-fib`, `/activity/story`, `/activity/rhyme-time`. Slash commands extended accordingly: `/riddles`, `/breathe`, `/factorfib`, `/story`, `/rhyme` — all confirmed in `slash_commands.dart`. Brain Breaks deck card count updated from nine to fourteen (all confirmed in `brain_breaks_screen.dart`). Surfaces sublist expanded with five new surface entries.
- **SCHEMA.md** — `content_items` table entry added (dual sync rule: `by_space` for per-space crowd rows + `global_content` auto-subscribe for `space_id IS NULL` global rows; both confirmed in `supabase/sync_rules.yaml`). Consumers: ActivityRuntime.
- Cross-link reconcile: ActivityRuntime `**Data**` claims `content_items`; `content_items` `**Consumers**` lists ActivityRuntime. Bidirectional. No other (feature → table) or (table → feature) drift.

_Run 2026-06-01 (Charades + Board)_ — no unresolved discovery drift. Updates applied this run:
- **LiveSession** — entry rewritten. Routes extended to include `/live/charades` (CharadesLiveScreen) and `/board` (BoardScreen). Omnibox updated: `page.board` entry confirmed in `omnibox_catalog.dart` (`label: 'Brainstorm Board'`, keywords: board, brainstorm, meeting, agenda, ideas, anonymous, `onSelect` pushes `/board`). Slash commands updated: `/charades` (aliases: act, acting, mime, guess) and `/board` (aliases: brainstorm, meeting, agenda, ideas) both confirmed in `slash_commands.dart`. No drawer entry, no Settings ListTile — correct for both surfaces. Brain Breaks deck card "Charades" → `/live/charades` confirmed in `brain_breaks_screen.dart`. No Board card in the Brain Breaks deck — Board is reached via omnibox `page.board` and `/board` slash (correct; it is not an activity card). `live_session.dart` generalized-seam note added: `LiveReducer` typedef, `SessionRole.secret`, game-agnostic `Map<String,dynamic>` state. `charades.dart` and `board_session.dart` new surfaces added. `content_bank.dart` `ContentKind.charades` + 24 prompts confirmed. All claimed surfaces verified.
- **SCHEMA.md** — no changes. Both Charades and Board are ephemeral Realtime surfaces with no synced tables and no migrations.
- Cross-link reconcile: LiveSession claims no synced tables; no (feature → table) or (table → feature) additions or removals. ActivityRuntime `**Consumed by**` already includes LiveSession; `**Depends on**` in LiveSession already includes ActivityRuntime. Content bank now also seeds Charades prompts — noted in LiveSession `**Depends on**` and `charades.dart` surface line; no new cross-link needed (ActivityRuntime ↔ LiveSession link was already bidirectional).

_Run 2026-06-01 (Live Sessions)_ — no unresolved discovery drift. Updates applied this run:
- **LiveSession** — new feature entry added. Route `/live/this-or-that` confirmed in `router.dart` (top-level GoRoute nested under the shell). Slash `/live` with aliases `present`, `projector`, `remote`, `session` confirmed in `slash_commands.dart`. "Present on a big screen" `SecondaryActionButton` (cast icon → `context.push('/live/this-or-that')`) confirmed in `this_or_that_screen.dart`. No drawer entry, no Settings ListTile — correct: this is a mode of a brain break, not a standalone destination. All claimed surfaces verified.
- **ActivityRuntime** — `**Consumed by**` updated from "Nothing — ActivityRuntime is a leaf" to include LiveSession (`live_session_screen.dart` imports `content_bank.dart`).
- **SCHEMA.md** — no new table entry. Feature uses Supabase Realtime broadcast + presence (ephemeral coordination, not durable data — same documented-exception class as auth and Storage). A note confirming the absence is in the LiveSession `**Data**` field.
- Cross-link reconcile: LiveSession claims no synced tables; no (feature → table) or (table → feature) additions. ActivityRuntime ↔ LiveSession dependency link is now bidirectional (LiveSession `**Depends on**` includes ActivityRuntime; ActivityRuntime `**Consumed by**` includes LiveSession).

_Run 2026-06-01 (pack-list + Location lens)_ — no unresolved discovery drift. Updates applied this run:
- **Supplies** — `**Data**` extended: `activity_supplies` (read + written via `activitySupplyLinksProvider` / `ActivitySuppliesActions`) and `locations` (read for the Location lens — `location_id` FK, migration `20260601000003`). `**Surfaces**` updated: list screen now documents the three-view toggle (Category / Location / Running low), the `groupSuppliesByLocation` helper, and the new Activity supplies providers surface. `**Depends on**` updated from "nothing" to Locations. `**Consumed by**` updated: Activities / Schedule now a real consumer via `activity_edit_screen.dart` importing `activity_supplies_providers.dart` + `supplies_providers.dart`.
- **Schedule** — `**Data**` extended: `activity_supplies` and `supplies` (both read in `activity_edit_screen.dart`). `**Depends on**` extended to include Supplies.
- **SCHEMA.md** — `activity_supplies` new table entry added. `supplies` key-columns updated with `location_id`. `activities` Consumers updated to include Schedule (was already listed; Activity edit screen is in the schedule folder). `locations` Consumers updated to include Supplies. `supplies` Consumers updated to include Schedule.
- Cross-link reconcile: see below.

_Run 2026-06-01 (Missions slice 1)_ — no unresolved discovery drift. Updates applied this run:
- **Missions** — new feature entry added. Route `/settings/missions` confirmed in `router.dart` (nested under `/settings`, same pattern as `supplies`, `locations`). Omnibox entry `page.missions` confirmed in `omnibox_catalog.dart` with keywords: missions, jobs, helpers, chores, responsibilities, equipment manager, snack helper; `onSelect` pushes `/settings/missions`. No drawer entry, no Settings ListTile, no slash command — correct per the library-surface convention (same as Supplies, Locations). Claimed surfaces verified: all match code.
- **SCHEMA.md** — `missions` table entry added.
- Cross-link reconcile: Missions claims `missions` table; `missions` Consumers lists Missions. Bidirectional. No other (feature → table) or (table → feature) drift.

_Run 2026-06-01 (Supplies slice 1)_ — no unresolved discovery drift. Updates applied this run:
- **Supplies** — new feature entry added. Route `/settings/supplies` confirmed in `router.dart` (nested under `/settings` alongside `locations`, same pattern). Omnibox entry `page.supplies` confirmed in `omnibox_catalog.dart` with keywords: supplies, inventory, materials, stock, markers, paper; `onSelect` pushes `/settings/supplies`. No drawer entry, no Settings ListTile, no slash command — correct per the library-surface convention (same as Locations, Toolkit, Curricula). Claimed surfaces verified: all match code.
- **SCHEMA.md** — `supplies` table entry added.
- Cross-link reconcile: Supplies claims `supplies` table; `supplies` Consumers lists Supplies. Bidirectional. No other (feature → table) or (table → feature) drift.

_Run 2026-06-01 (Group Discussions + Role Cards deck-switcher)_ — no unresolved discovery drift. Updates applied this run:
- **ActivityRuntime** — Group Discussions added: route `/activity/discussions` → `GroupDiscussionScreen`; Brain Breaks deck card "Group Talk / Discuss — by topic & age" confirmed in `brain_breaks_screen.dart`; slash `/discuss` (aliases: discussion, talk, circle, grouptalk, conversation) confirmed in `slash_commands.dart`. Not in drawer (surface is a deck card, same pattern as all other individual activities) or settings. No new synced tables — `discussions.dart` is a pure-Dart catalog.
- **ActivityRuntime** — Role Cards deck-switcher: `roles.dart` now defines `RoleDeck {id, name, emoji, tagline, cards}` and `roleDecks` (animals 23 cards, people 12 cards). `roleCatalog` kept as back-compat alias. Surfaces sublist updated; `/roles` slash hint updated to "animals, people & jobs"; aliases updated to include `people` and `jobs`.
- **ActivityRuntime** — Brain Breaks deck card count updated from eight to nine.
- No new synced tables. All new content is pure-Dart. SCHEMA.md unchanged.
- Cross-link reconcile: ActivityRuntime has no Data tables. No (feature → table) or (table → feature) drift found.

_Run 2026-06-01 (Wave A — Role Cards + Make a Pattern)_ — no unresolved discovery drift for the new surfaces (they follow the established activity-runtime pattern: drawer via Brain Breaks deck, slash commands for direct access, no separate omnibox or settings entries). Updates applied this run:
- **ActivityRuntime** — new feature entry added. Covers all eight break surfaces, including the two new ones (Role Cards at `/activity/roles`, Make a Pattern at `/activity/pattern`). Kid-lock status corrected: Photography remains the only kid-locked break; Math Game, Many Paths, Beat the Letter, and Act It Out were de-locked this session (teacher-paced exit via back arrow).
- **ActivityRuntime** — discovery surfaces verified: `/breaks` drawer entry confirmed in `main_drawer.dart` at line 263; `/activity/roles` and `/activity/pattern` routes confirmed in `router.dart`; `/roles` and `/pattern` slash commands confirmed in `slash_commands.dart`. Omnibox catalog has NO direct entries for individual activities or for the Brain Breaks deck — this is the established precedent (same as Toolkit), not a drift. The deck is the discovery surface; slash is the power-user shortcut.
- No new synced tables. `roles.dart` and `pattern_maker.dart` are pure-Dart catalogs. `pattern_maker_screen.dart` uses `image_picker` but writes no row. SCHEMA.md unchanged.
- Cross-link reconcile: ActivityRuntime has no Data tables. Kid mode **Consumed by** does not need ActivityRuntime added — only Photography uses the lock (not the whole feature folder), and the kid-mode entry already lists Surveys as the canonical consumer; the per-screen note in ActivityRuntime's Surfaces is sufficient.

_Run 2026-05-29 (Wave 171 vehicle QR scheme change)_ — one discovery drift corrected (see below). No new migrations; SCHEMA.md unchanged. No omnibox, slash, drawer, or settings claims changed. Updates applied this run:
- **Vehicles** — Routes corrected from `/settings/vehicles*` to `/vehicles*` (Wave 95 moved the top-level path; `/settings/vehicles` still exists as a redirect, not a live route). `/vehicles/scan` surface added — `VehicleScanScreen` was in the router but absent from the doc.
- **Vehicles** — Vehicle inspection surface note updated: QR PDFs now encode `differentworld://v/<id>/<kind>` (Wave 171), replacing the prior HTTPS github.io path. Invite QRs keep HTTPS — the distinction is documented inline.
- Cross-link reconcile: no (feature → table) or (table → feature) drift found. SCHEMA.md Consumers lists for vehicles, vehicle_logs, and member_certifications already include Vehicles.

_Run 2026-05-23 (family-lens sync fix)_ — no unresolved discovery drift; no route, omnibox, slash, drawer, or settings claims changed. Updates applied this run:
- **Family** — `**Data**` field rewritten to distinguish offline-first tables (guardians, spaces, subject_guardians, messages, export_recipients — served by the new `by_guardian` PowerSync stream) from direct-PostgREST reads (subjects, attendance_records, entries, attachments — 2-level subquery deferred — and exports via `myReceivedExportsProvider`). The prior "latent bug" note removed; the `by_guardian` stream resolves it for the row-keyed tables. Per-subject tables remain PostgREST-only pending 2-level subquery verification.
- **Family** — Surfaces sublist expanded: `family_providers.dart` entry added; subject-detail and messages-index surface descriptions updated to name the backing providers and their offline-first status.
- **Family** — Depends-on updated: Messages now noted as offline-first via `by_guardian`.
- SCHEMA.md — `by_guardian` stream added to sync-rule fields for guardians, spaces, subject_guardians, messages, and export_recipients. Family added to Consumers of all five tables where not already present.
- Cross-link reconcile: all (Family → table) claims in FEATURES.md verified bidirectional in SCHEMA.md. No drift found.

_Run 2026-05-22 (Wave 24 omnibox interaction hardening)_ — no
unresolved discovery drift; routes, omnibox catalog, slash
commands, drawer, and settings claims all verified against
`router.dart`, `omnibox_catalog.dart`, `slash_commands.dart`,
`main_drawer.dart`, and `settings_screen.dart`. No new
migrations since the previous run; SCHEMA.md unchanged. Updates
applied this run:
- **Omnibox** — Surfaces sublist tightened: search-screen entry
  now documents the rootNavigator dispatch-context fix (post-pop
  callbacks were short-circuiting on the deactivated screen
  context); catalog entry calls out the new "drop subjects whose
  groupId is null" filter so we stop showing tap-no-ops.
- **Omnibox** — new **Interaction invariants** sub-block (4
  bullets) capturing the Wave 24 contract: push-on-focus
  (not keystroke), lock held for `/search` lifetime,
  500ms-window focus + IME re-grant after the FocusScope
  rotation, canonical test + Interaction Guard wiring. This
  doesn't add a NEW FEATURES.md field — it's free-form text
  inside the existing Surfaces sublist style — but call it out
  here so the next feature-mapper run knows it's intentional.
  If the user wants this promoted to a first-class field on
  every feature, propose in a follow-up.
- **Omnibox** — Depends-on extended to include Schedule
  (omnibox catalog now constructs `SubstituteLeadSheet` directly
  from the "Cover today · {Group}" entry, importing from
  `lib/features/schedule/widgets/substitute_lead_sheet.dart`).
  Carries forward the Phase 1 Pat affordance — Schedule's
  Consumed-by line already names Omnibox so the cross-link is
  bidirectional.
- **Captures** — Surfaces sublist now lists `CaptureActions`
  with the transaction wrapper note (`promoteToObservation` +
  `promoteToTask` both run their two writes inside
  `db.transaction(...)`). Blast-radius flagged the prior path
  2026-05-22; this is the durable fix.
- **Entries** — no doc change; the form-local
  `DeepgramVoiceController` was already documented in the prior
  run. Confirmed still accurate.
- Cross-link reconciled — Omnibox→Schedule link verified
  bidirectional. No other (feature → table) or (table →
  feature) drift found.

_Run 2026-05-22 (voice-race hotfix follow-up)_ — no unresolved discovery
drift; no route, omnibox, slash, drawer, or settings claims changed.
Updates applied this run:
- **Entries** — observation-form surfaces line clarified: the form
  now owns its OWN `DeepgramVoiceController` instance (constructed in
  `initState`, disposed in `dispose`) and no longer reads
  `deepgramVoiceProvider`. The doc previously said "reuses
  `DeepgramVoiceController`" which was ambiguous between the class
  and the singleton; tightened to call out that it does NOT consume
  the singleton, to dodge the dual-listener race against AppShell's
  composer mic.
- **Voice** — Consumed-by line split: Omnibox uses the shared
  `deepgramVoiceProvider` singleton; Entries instantiates its own
  `DeepgramVoiceController` and does not consume the singleton. The
  Voice feature is still consumed by Entries because the form uses
  the controller CLASS — just not the provider.
- No new migrations, router changes, omnibox catalog changes, slash
  commands, drawer items, or settings rows since the prior run.
  SCHEMA.md unchanged.

_Run 2026-05-22 (Phase 1 follow-up)_ — no unresolved discovery drift.
Updates applied this run for the persona-audit Phase 1 ship:
- **Schedule** — added the new dynamic omnibox action "Cover today ·
  {Group.name}" (per cohort, gated by `can_manage_schedule`) to the
  discovery surfaces. Opens `SubstituteLeadSheet` directly. Surfaces
  sublist + Consumed-by line updated to call out the omnibox
  invocation path. Pat persona affordance.
- **Entries** — observation-form voice line flipped from "deferred
  for Jordan" to "voice dictation via Deepgram mic (suffix-icon on
  the body TextField; reuses `DeepgramVoiceController`)". Depends-on
  added Voice.
- **Voice** — Status note updated: omnibox mic + observation-form
  body field both ship; capture-form mic still pending. Consumed-by
  added Entries.
- Cross-link reconciled: Voice ↔ Entries link is now bidirectional
  (Entries.Depends-on includes Voice; Voice.Consumed-by includes
  Entries).
- SCHEMA.md verified — no table-level drift this run; no migration
  was added in Phase 1, so SCHEMA.md sections are unchanged.

Previous run (initial 2026-05-22 verification): Schedule keyword
example, Onboarding surfaces, Kid-mode exit dialog — all applied in
the prior pass; carrying forward.

All other discovery claims verified against `router.dart`,
`omnibox_catalog.dart`, `slash_commands.dart`, `main_drawer.dart`, and
`settings_screen.dart`.

_Run 2026-06-06 (World slice 1 — character_sheets)_ — no discovery drift. Updates applied this run:
- **World** — new feature entry added. Routes `/subjects/:id/me` + `/subjects/:id/draw` confirmed in `router.dart` (lines 543–558, top-level shell children). No omnibox entry, no drawer item, no settings row, no slash command — all intentionally absent in slice 1; the only discovery surface is `_WorldSelfTile` FeatureCard on `subject_detail_screen.dart`. The claimed absence is verified against `omnibox_catalog.dart`, `slash_commands.dart`, `main_drawer.dart`, and `settings_screen.dart` — none contain world/character_sheet references.
- **Subjects** — `**Consumed by**` updated to include World.
- **Photos** — `**Consumed by**` updated to include World.
- **SCHEMA.md** — `character_sheets` table entry added.
- Cross-link reconcile: World `**Data**` claims `character_sheets`; `character_sheets` `**Consumers**` lists World. Bidirectional. No other (feature → table) or (table → feature) drift.

_Run 2026-06-05 (Speak — screen split + 11 modes + history + transport)_ — no discovery drift found. Updates applied this run:
- **Speak** — Presentation modes rewritten: was "Five modes" / "Ten modes" (stale from earlier waves); corrected to 11 modes. **Editorial** added as the new default (first in `implementedSpeakModes`). Stage, Collage, Spotlight, Mural, Grid, Justified, Index, Shape entries preserved. Mode count in the surfaces line now correct.
- **Speak** — Three new surfaces added from the `speak_screen.dart` refactor (1 223 → 378 lines): *Speak input controls* (`speak_input_controls.dart`), *Speak performer* (`speak_performer.dart` — performance host + ticker + transport bar), *Speak immersive provider* (`speak_immersive.dart`). The old monolithic Speak screen entry retargeted to its post-refactor role (orchestration only).
- **Speak** — `tts-subtitles` Edge Function marked deployed + `ELEVENLABS_API_KEY` set; the feature is live.
- **Discovery surfaces** — verified against code: `/speak` route in `router.dart` line 871. Omnibox `page.speak` entry in `omnibox_catalog.dart` (labels + keywords match). Slash `/speak` with aliases `read, karaoke, subtitles, narrate, voice` in `slash_commands.dart`. `ThinkingTool id: speak → /speak` in `thinking_tool.dart`. No drawer entry, no Settings row — correct (it is a Tools shelf entry, not a nav destination). No drift found.
- **SCHEMA.md** — no changes. No new synced tables: audio is in the public `tts-cache` Storage bucket; history is SharedPreferences-local. Nothing rides PowerSync.
- Cross-link reconcile: Speak claims no synced tables; no (feature → table) or (table → feature) changes required.

_Run 2026-06-03 (Tools + LiveSession lobby + Poster orientation)_ — discovery drift corrected (see output report). Updates applied this run:
- **Top-level orientation** — added "Tools" and "Present" to the canonical nav list (both were in `buildNavDestinations` but missing from the blurb).
- **Tools** — all claimed discovery surfaces verified: `/tools` route in `router.dart`; `page.tools` omnibox entry in `omnibox_catalog.dart`; `/tools` slash with aliases `toolkit, thinking, frameworks, activities` in `slash_commands.dart`; "Tools" nav destination in `nav_destinations.dart`. No drift found.
- **LiveSession** — Routes extended: `/join` (one-place-to-join, `autoJoin`), `/present` and `/present/<game>` routes added. Slash `/live` aliases corrected: code has `['session']` only (not `present, projector, remote, session` as previously claimed — `present` and `projector` and `remote` aliases moved to the separate `/present` slash command). Slash `/present` entry added (aliases: `cast, room, screen, projector, remote`). Omnibox `page.present` entry added. Drawer: "Present" nav destination added. New surfaces: `live_lobby.dart` (LobbyAnnouncer + LobbyWatcher), `live_lobby_providers.dart` (`activeSessionsProvider`), `live_session_banner.dart` (`LiveSessionBanner` on Today). `LiveGameScreen.autoJoin` param documented. `Depends on` and `Consumed by` updated bidirectionally with Today.
- **Today** — `LiveSessionBanner` surface added to the surfaces list. `Depends on` updated to include LiveSession. `Last verified` updated.
- **Poster** — `PosterScreen` surface description updated: orientation control (Auto/Portrait/Landscape), three delivery actions (Save PDF / Save PNG / Print), determinate render progress. `PosterOptions` model updated to include `orientation`. `Last verified` updated.
- **SCHEMA.md** — no changes. No new synced tables in any of these features.
- Cross-link reconcile: LiveSession ↔ Today bidirectional dependency added. No (feature → table) or (table → feature) drift.

---

_Last full registry verification: 2026-06-06 (World slice 1 — character_sheets)._
_Incremental verification: 2026-07-04 (chore/dedup-wave — shared widget extraction). No discovery drift. No schema changes. See run report below._
_Incremental reconcile: 2026-06-08 (timer caps + phase windows caps + attendance natural-key index) — Action Words Capabilities + Status + Depends on + Consumed by updated for `timer_presets` / `suggest_play_minutes` caps. Today Data + Depends on updated for `phase_windows` cap. Settings Data + Program settings surface description + Depends on updated for all three caps + new `_TimerPresetsTile` / `_PlayLengthTile` / `_PhaseWindowsSection` tiles. Cross-links reconciled: Today→spaces and Action Words→spaces and Settings→spaces all bidirectional with SCHEMA.md. No new discovery drift._
_Incremental reconcile: 2026-06-14 (Reflections + Settings Calm layout) — **Reflections** new feature section added; all four discovery surfaces verified (route `/reflect` in `router.dart`, omnibox `page.reflect` in `omnibox_catalog.dart`, slash `/reflect` in `slash_commands.dart`, drawer "Reflect" in `nav_destinations.dart` Activities group). **Settings** — `_DisplayStyleTile` (`displayStyleProvider`, `DisplayStyle.boxed/calm`) documented in the Preferences group surface description; Personas served + Depends on + Consumed by updated. Top-level orientation blurb updated to include Reflect in the canonical nav list. SCHEMA.md: `entries` `kind` column updated to add `reflection`; Reflections added to `entries` Consumers. No new tables. Cross-link reconcile: Reflections→entries and entries→Reflections now bidirectional. Feature folders `identity`, `games`, `activity_forge`, `launch`, `runtime` exist in code with no FEATURES.md entry — pre-existing gap, flagged below but not in scope for this run._
_If a feature is missing from this file, the feature-mapper agent will
add a stub the next time it runs. Don't hand-write entries unless
you're also updating the agent's view of truth._

## Rotation
**Path**: `lib/features/rotation/`
**Purpose**: The relationship rotator. Not a randomiser with history — its object is the PAIR, so "shuffle" means *give these children a configuration they have not recently had*. Plus Coverage: who in this room has still never worked with whom.
**Personas served**: Maya, Coach Sam, Brianna (the "split them up" moment, ten times a week).
**Discovery surfaces**:
- Routes: `/groups/:id/arrange`, `/groups/:id/coverage`
- Omnibox: yes — per-cohort "Make groups · {Room}" (keywords: arrange, make groups, split, partners, pairs, teams, shuffle, mix them up)
- Slash: none
- Drawer: no (per-room, reached from the room)
- Settings: no
**Capabilities**: staff; no caps required.
**Data**: [rotation_rounds](SCHEMA.md#rotation_rounds), [groups](SCHEMA.md#groups), [subjects](SCHEMA.md#subjects), [attendance_records](SCHEMA.md#attendance_records) (via `presentSubjectsProvider`).
**Surfaces**:
- *Make groups* — `arrange_screen.dart`. Groups-of-N vs N-groups as separate controls (one number field silently picks one); named leftover policy; reveal reports the MIX ("10 new · 2 unavoidable repeats") and says WHEN a repeated pair last met; ~700ms deliberate reveal; "Keep it" stores the round.
- *Coverage* — `coverage_screen.dart`. Never-met pairs plus the arithmetic that decides whether the promise is reachable at all (21 children ≈ 20 sessions in pairs, ≈ 7 in fours).
- *Engine* — `rotation_engine.dart`. Recency-weighted history (weights HALVE each round back), repeat load squared PER CHILD, keep-together merged transitively into atomic units, keep-apart as infinite cost, balance-by-tag, seeded. Graded against brute force over all 105 perfect matchings of eight children (`test/unit/rotation_engine_test.dart`).
**Depends on**: Groups, Subjects, Attendance.
**Consumed by**: [Readiness](FEATURES.md#readiness) (offers a first round to a cohort that has never been arranged).
**Last verified**: 2026-08-24

## Rollover
**Path**: `lib/features/rollover/`
**Purpose**: Start a new year without deleting anyone. A child either carries forward into a room or becomes an alumnus who keeps every record they ever had — there is no third option and no code path that removes anything.
**Personas served**: Maya, Pat (the September cleanup that used to destroy a year).
**Discovery surfaces**:
- Routes: `/settings/rollover`, `/settings/alumni`
- Omnibox: yes — "Start a new year" (new year, school year, rollover, move up, promote, graduate) and "Past children" (alumni, former, graduated, last year, archive)
- Slash: none
- Drawer: no
- Settings: yes — "Start a new year" and "Past children", beside Program
**Capabilities**: director (`canManageSpace`).
**Data**: [terms](SCHEMA.md#terms), [placements](SCHEMA.md#placements), [subjects](SCHEMA.md#subjects) (`status`), [groups](SCHEMA.md#groups).
**Surfaces**:
- *Start a new year* — `rollover_screen.dart`. Children grouped by current room with a destination chip; defaults to everyone carrying forward unchanged; period name suggested from the current one; footer states the receipt BEFORE committing ("N carry forward · N become alumni · 0 records deleted"); Undo offered in the result snackbar.
- *Past children* — `alumni_screen.dart`. The proof the promise held; every row opens that child's book.
- *Plan logic* — `rollover_plan.dart`. Silence means carry forward, never removal.
**Depends on**: Subjects, Groups.
**Consumed by**: Nothing yet. Rotation history is per-cohort and survives a rollover.
**Last verified**: 2026-08-24

## Rooms
**Path**: `lib/features/rooms/`
**Purpose**: The room as a PLACE, not a roster — how full it is against its own legal limits, what it is doing today, who is on it, and the two attention instruments (Pick someone, Talk time).
**Personas served**: Maya (ratio/capacity — the number an inspector asks for), Coach Sam and Brianna (the instruments).
**Discovery surfaces**:
- Routes: `/groups/:id/turns`, `/groups/:id/talk`, `/settings/closed-rooms`
- Omnibox: yes — per-cohort "Pick someone · {Room}" (pick, cold call, whose turn, volunteer) and "Talk time · {Room}" (talk, who has spoken, quiet, airtime); plus "Closed rooms" (retired, archived, reopen)
- Slash: none
- Drawer: no
- Settings: yes — "Closed rooms"
**Capabilities**: staff; closing a room is director-only.
**Data**: [room_events](SCHEMA.md#room_events), [groups](SCHEMA.md#groups) (`status` + the capacity/ratio caps), [group_members](SCHEMA.md#group_members), [schedule_blocks](SCHEMA.md#schedule_blocks), [attendance_records](SCHEMA.md#attendance_records).
**Surfaces**:
- *RoomLoadBar* — `widgets/room_load_bar.dart`. Ratio + capacity, on the room. Renders nothing until the numbers are set. Honest that it counts staff ASSIGNED, not present (there is no clock-in).
- *RoomTodayStrip* — `widgets/room_today_strip.dart`. The blocks still ahead + how many adults are on the room.
- *Pick someone* / *Talk time* — `turns_screen.dart`. Favours whoever has gone longest without (a child with NO entry outranks one with a single turn) and names who is still waiting; talk time is one tap to start-and-stop.
- *Closed rooms* — `closed_rooms_screen.dart`. The way back; closing is only safe as the primary action because reopening is one tap.
- *Logic* — `room_load.dart` (ceiling division, unset ≠ unlimited), `fair_turns.dart`.
**Depends on**: Groups, Subjects, Attendance, Schedule.
**Consumed by**: [Readiness](FEATURES.md#readiness) (a ratio breach leads the briefing).
**Last verified**: 2026-08-24

## Readiness
**Path**: `lib/features/readiness/`
**Purpose**: What today needs, without being asked. The app already knows what a complete child record looks like and what a running day needs, so it shows the DIFFERENCE — and shows nothing once there isn't one.
**Personas served**: Maya, Jordan, Pat (the first morning of a year, and any day with gaps).
**Discovery surfaces**:
- Routes: none — it renders inside [Today](FEATURES.md#today)
- Omnibox / Slash / Drawer / Settings: no
**Capabilities**: staff.
**Data**: [subjects](SCHEMA.md#subjects), [subject_guardians](SCHEMA.md#subject_guardians), [groups](SCHEMA.md#groups), [rotation_rounds](SCHEMA.md#rotation_rounds).
**Surfaces**:
- *ReadinessCard* — `widgets/readiness_card.dart`. Rows NAME people rather than counting them; ordered by what it costs to miss (a ratio breach first — the only regulatory item — then unreachable child, medical unknown, then the two things only collectable while the family is present); renders `SizedBox.shrink()` when there is nothing to do.
- *Logic* — `readiness.dart`. A child nobody may photograph is not "missing a photo"; blank allergies is a question, not an answer; alumni are excluded.
**Depends on**: Subjects, Guardians, Groups, Rooms, Rotation, Photos (consent).
**Consumed by**: [Today](FEATURES.md#today).
**Last verified**: 2026-08-24

## ActivityForge
**Path**: `lib/features/activity_forge/`
**Purpose**: An activity is not a whole pre-written experience pulled from a finite list — it is FOUR atomic parts recombined: a VERB (the action), a NOUN (the thing), a CONSTRAINT (the twist that turns noise into play), and a TIME (the box). "A library runs out, a formula doesn't" (docs/VISION.md #3).
**Personas served**: Coach Sam, Brianna, Jordan (the "I need something in ten minutes" moment).
**Discovery surfaces**:
- Routes: `/activity/forge` (`activity_forge_screen.dart`), `/activity/lens` (`activity_lens_screen.dart`)
- Omnibox: yes (activity entries)
- Slash / Drawer / Settings: no
**Capabilities**: staff.
**Data**: none of its own — composes from [content_items](SCHEMA.md#content_items) and the verb/noun catalogues.
**Surfaces**: *Forge* (recombine the four parts), *Lens* (view an activity through a different frame).
**Depends on**: ActionWords (verbs), GameContent.
**Consumed by**: ActivityRuntime.
**Last verified**: 2026-08-24

## Games
**Path**: `lib/features/games/`
**Purpose**: The host-run game engine — one registry (`game_registry.dart`) resolves a game id to its `GameDefinition`, so a cast session, a join-by-code and the launcher all render the same game without navigating to its route first. ~20 games, plus the deck-seeded picture-card games (docs/CARD_GAMES.md).
**Personas served**: Coach Sam, Brianna, Ava (the room-facing moments).
**Discovery surfaces**:
- Routes: `/activity/<id>` (solo) and `/live/<id>` (cast) per game; `/present` (hub)
- Omnibox: yes — per game
- Drawer: yes — "Present" and "Brain Breaks"
- Settings: no
**Capabilities**: staff; kid-facing surfaces run in kid mode.
**Data**: [content_items](SCHEMA.md#content_items) (the content bank), plus per-game local state.
**Surfaces**: *Present hub* (`present_hub_screen.dart`), the per-game screens under `games/`, `game_scaffold.dart` / `game_stage.dart` (the shared shell + raw stage), `game_registry.dart` (add a game in ONE place).
**Depends on**: GameContent, LiveSession (casting), ActivityRuntime.
**Consumed by**: [LiveSession](FEATURES.md#livesession) (the cast receiver resolves games through the registry).
**Last verified**: 2026-08-24

## Identity
**Path**: `lib/features/identity/`
**Purpose**: The self-authored archetype — "how you show up" on a staff profile. Decorates, never gates: it has no effect on capabilities and is editable only on your OWN profile.
**Personas served**: all staff.
**Discovery surfaces**:
- Routes: none of its own — renders inside [Settings](FEATURES.md#settings)' member detail
- Omnibox / Slash / Drawer / Settings: no
**Capabilities**: editable only by the member themselves (`me?.id == member.id`).
**Data**: [members](SCHEMA.md#members) `capabilities` (`MemberCaps.archetype`, a string cap).
**Surfaces**: *ArchetypeCard* — `widgets/archetype_card.dart`, plus `showArchetypePicker`.
**Depends on**: Settings, Members.
**Consumed by**: Settings (member detail).
**Last verified**: 2026-08-24

## Launch
**Path**: `lib/features/launch/`
**Purpose**: The boot surface, and the readiness signals that decide what a signed-in member lands on.
**Personas served**: everyone, once per launch.
**Discovery surfaces**:
- Routes: `/launch`
- Omnibox / Slash / Drawer / Settings: no
**Capabilities**: none — it runs before the viewer is resolved.
**Data**: reads [subjects](SCHEMA.md#subjects), [schedule_blocks](SCHEMA.md#schedule_blocks) and the day templates to decide readiness.
**Surfaces**: *LaunchScreen* (`launch_screen.dart`), *launch readiness* (`launch_readiness.dart`).
**Depends on**: Auth, Schedule, Subjects.
**Consumed by**: the router's redirect.
**Last verified**: 2026-08-24

## Runtime
**Path**: `lib/features/runtime/`
**Purpose**: The reactive, indexed rule evaluator behind the semantic graph (docs/SEMANTIC_GRAPH.md). Rules are indexed by `(nounType, event)` at construction so a fired event consults only the matching handful — a ruleset that grows must never slow a single write.
**Personas served**: none directly — infrastructure the content surfaces sit on.
**Discovery surfaces**: none (no routes, by design).
**Capabilities**: n/a.
**Data**: none of its own.
**Surfaces**: `rule_engine.dart` (the evaluator), `noun_rule.dart` (the rule shape), `rules/` (the ruleset).
**Depends on**: nothing.
**Consumed by**: ActivityForge, GameContent.
**Last verified**: 2026-08-24

## DevFlags
**Path**: `lib/features/dev_flags/`
**Purpose**: The in-app "flag this screen" button — DEBUG BUILDS ONLY. Each tap appends `{route, label, note, timestamp}` to a JSON file in the app's sandbox, so on-device testing produces a list of exactly which screens to revisit instead of "that one screen I meant".
**Personas served**: the developer.
**Discovery surfaces**:
- Routes: none — a floating flag rendered by AppShell, gated on `kDebugMode`
- Omnibox / Slash / Drawer / Settings: no
**Capabilities**: n/a (debug only).
**Data**: none synced — a local JSON file, pulled with `scripts/read_dev_flags.sh`.
**Surfaces**: `dev_flags.dart`.
**Depends on**: AppShell.
**Consumed by**: nothing at runtime.
**Last verified**: 2026-08-24
