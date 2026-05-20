# Screen QA Matrix

Source of truth for what every screen MUST show in each state. Walk
this list when verifying a build before sending to test users; every
PR that touches the AppShell, EdgeScaffold, omnibox, or router should
reconfirm the rows it touches.

## Universal expectations (apply to EVERY screen)

| Surface | Expectation |
|---|---|
| Bottom omnibox bar | Always visible at the bottom (above the keyboard when one is open). NOT visible in kid mode. |
| Bottom safe-area / nav gesture indicator | Bar's `SafeArea(top: false)` accounts for it; no content sits under the indicator. |
| Top chrome — back arrow | Visible on every drill-in. Tappable. Fallback route honored when stack is empty. NOT visible in kid mode. |
| Top chrome — action pill | Per-screen actions render top-right. Multiple actions wrap into a single pill row. NOT visible in kid mode. |
| Top chrome — transitions | When navigating A→B, the back arrow + actions morph in place; they do NOT slide with the page. |
| System back button | Pops route normally. If omnibox panel is open, FIRST press collapses the panel; second press pops the route. |
| Text size override | Screen reflows correctly at System / Large (1.3x) / Extra large (1.5x). No fixed-height containers cropping text. |
| Loading state | Shows skeleton or labeled spinner ("Syncing …"), never a blank white screen. |
| Empty state | Shows icon + sentence + (where relevant) primary CTA. Never just blank. |
| Error state | Inline retry banner, not a full-screen wipe. Localized message. |
| Photos | Avatars + gallery photos load via signed URLs from the private `person-photos` bucket. Legacy public URLs still resolve. |

## Per-screen rows

### `/` — Today (home, staff)

| State | Expectation |
|---|---|
| Loading (first sync) | Skeleton tiles for today's launchpad. No "offline" error. |
| Data | Date header, top insight (if any), checklist progress, captures count, quick actions (attendance, observation). |
| Empty (nothing to do) | Friendly "all clear" copy. |
| Top chrome | NO back arrow. Hamburger / drawer affordance is gone — drawer destinations live in the omnibox. Actions: sync indicator. |
| Omnibox | Idle = "Recent captures" strip + Pinned / Recent / For-you-now / categories. |

### `/checklist` — Morning checklist

| State | Expectation |
|---|---|
| Loading | Spinner labeled "Loading today's checklist". |
| Data | Per-cohort attendance + meals + naps rows. Tap-to-jump links. |
| Top chrome | Back arrow. No actions. |

### `/groups/new` — Create cohort

| State | Expectation |
|---|---|
| Initial | Empty form: name, age-band, capacity. |
| Submitting | "Create" button shows spinner; disabled. |
| Success | Pops back to caller. |
| Error | Inline message under the failing field. |
| Top chrome | Back arrow. No actions. |

### `/groups/:id` — Cohort detail

| State | Expectation |
|---|---|
| Loading | Skeleton list of students. |
| Data | Roster, today's attendance status chip, schedule peek, observation feed peek. |
| Empty roster | "Add the first student" CTA. |
| Top chrome | Back arrow + primary "Edit cohort" + secondary "Take attendance" actions. |

### `/groups/:id/edit` — Edit cohort

| Initial | Pre-populated form. |
| Submitting | Save button shows spinner. |
| Top chrome | Back arrow. Save button lives in the body (not the chrome). |

### `/groups/:id/attendance` — Attendance

| Loading | Skeleton rows. |
| Data | Sticky filter chips (Status / Cohort / Age). Each student row has avatar + name + status pill. Tap toggles status. |
| Empty | "No students in this cohort yet" + CTA to add. |
| Top chrome | Back arrow + "Done" or "Capture group photo" primary. |
| Verify | Status change persists locally even with airplane mode on. |

### `/groups/:id/observations` — Cohort observation feed

| Loading | Skeleton observations. |
| Data | Reverse-chronological entries. Each has kid avatar, body preview, photos, tags, kebab menu. |
| Empty | "No observations yet" + "Log one now". |
| Top chrome | Back arrow + "New observation" primary. |

### `/groups/:id/students/new` — Add student

| Initial | Empty form: first + last, DOB, photo. |
| Submitting | Save button spinner. |
| Top chrome | Back arrow. |

### `/groups/:id/students/:sid` — Student detail

| Loading | Skeleton card. |
| Data | Avatar, name, age, guardians, recent observations, attendance heatmap, survey responses. |
| Top chrome | Back arrow + primary "Log observation" + secondary "Edit". |

### `/groups/:id/students/:sid/edit` — Edit student

| Initial | Pre-populated form. |
| Top chrome | Back arrow. |

### `/groups/:id/students/:sid/progress-report` — Progress report

| Loading | Spinner — "Building report". |
| Data | Summary + monthly observations + attendance + survey results. |
| Top chrome | Back arrow + "Share PDF" primary. |
| Verify | PDF preview opens in `printing`; share opens native share sheet. |

### `/observations` — All observations

| Loading | Skeleton. |
| Data | Reverse-chronological list across all cohorts. Tap to open. |
| Empty | "No observations yet" + CTA. |
| Top chrome | Back arrow + "New observation" primary. |

### `/insights` — Insights

| Loading | Spinner. |
| Data | Grouped by severity (Urgent / Suggestions / FYI). Each card shows prompt + actions + snooze. |
| Empty | "All clear — system has nothing to ask." |
| Top chrome | Back arrow + "Walk me through" primary (only when 2+ insights). |

### `/captures` — Capture inbox

| Loading | Skeleton. |
| Data | Open captures; each tile has body, age, kebab. Promote → observation / task. |
| Empty | "Inbox is empty" with link to omnibox capture mode. |
| Top chrome | Back arrow + "Triage all" or similar. |
| Verify | Tapping a capture opens its detail / promote sheet. |

### `/tasks` — Task list

| Loading | Skeleton. |
| Data | Active tasks grouped by due (today / this week / later). Done section collapsible. |
| Empty | "No open tasks." |
| Top chrome | Back arrow + "New task" primary. |

### `/messages` — Conversation list

| Loading | Skeleton. |
| Data | One row per (subject × guardian) thread. Unread badge. |
| Empty | "No messages yet." |
| Top chrome | Back arrow. No primary action (start from a student profile). |

### `/messages/:subjectId/:guardianId` — Thread

| Loading | Spinner. |
| Data | Bubbles bottom-aligned, autoscroll on new. Compose input at the bottom — REPLACES the omnibox bar for this route. |
| Empty | "Start a conversation." |
| Top chrome | Back arrow + guardian/subject name in header. |
| Verify | Composer bar at bottom replaces omnibox cleanly — no doubled bars. |

### `/review` — Walk-me-through

| Loading | Spinner. |
| Data | Step-by-step insight walkthrough. Progress dots. |
| Top chrome | Back arrow + "Finish later" secondary. |

### `/year` — Year review (under review)

| Loading | Spinner. |
| Data | Macro stats for the program year. |
| Top chrome | Back arrow. |

### `/surveys` — Survey templates

| Data | List of survey templates. |
| Top chrome | Back arrow. |

### `/surveys/:templateId` — Template detail

| Data | Template questions + "Take with …" launcher. |
| Top chrome | Back arrow + "Send to all kids" primary. |

### `/surveys/:templateId/take/:subjectId` — Survey take (kid surface)

| KID MODE | Omnibox bar is HIDDEN. Top chrome is HIDDEN. Drawer ungettable. |
| Initial | Big chibi-smiley question 1 of N. |
| Mid-flow | Tap chibi → 400ms feedback → auto-advance. Multiselect / text use explicit Next. |
| Back gesture | System back is intercepted — DOES NOT exit kid mode (TODO: staff-only exit). |
| Complete | Confirmation + auto-pop after a beat. |
| Exit | Currently auto-exits kid mode in dispose; future: PIN gesture. |

### `/surveys/:templateId/table` — Survey results table

| Loading | Spinner. |
| Data | Rows × subjects matrix with answers. Sticky header. |
| Empty | "No responses yet." |
| Top chrome | Back arrow + "Export CSV" primary. |

### `/children/:sid` — Family-side child detail

| ROLE | Only renders for guardian viewers. Staff users see a "not allowed" empty state. |
| Loading | Spinner. |
| Data | Today snapshot, recent observations, messages thread launcher. |
| Top chrome | Back arrow. |

### `/schedule` — Week schedule (camp)

| Loading | Skeleton grid. |
| Data | Per-cohort columns × time rows. Tap a block → edit sheet. |
| Empty | "No blocks scheduled. Add one." |
| Top chrome | Back arrow + "Add block" primary. |

### `/activities` — Activities library

| Loading | Skeleton. |
| Data | List of activities (swim, archery…). Tap → detail. |
| Empty | "No activities yet" + "Add". |
| Top chrome | Back arrow + "Add activity" primary. |

### `/activities/new` and `/activities/:id` — Activity edit

| Initial | Form. |
| Submitting | Save spinner. |
| Top chrome | Back arrow. |

### `/settings` — Settings

| Always | Profile group, Team, Vehicles, Preferences (Text size + Appearance), About. NO "Schedule library" group (moved to omnibox). |
| Top chrome | Back arrow. No actions. |

### `/settings/program` — Program edit

| Initial | Form. |
| Top chrome | Back arrow. |

### `/settings/locations` — Locations library

| Loading | Skeleton. |
| Data | List of locations. |
| Empty | "No locations yet" + add CTA. |
| Top chrome | Back arrow + "Add" primary. |

### `/settings/team` — Team list

| Loading | Skeleton. |
| Data | Members with role chips + pending invites. |
| Empty | "No teammates yet — invite one." |
| Top chrome | Back arrow + "Invite" primary. |

### `/settings/team/:id` — Member detail

| Loading | Skeleton. |
| Data | Avatar, role picker, capability toggles, leave-program. |
| Top chrome | Back arrow. |

### `/settings/vehicles` — Vehicles list

| Loading | Skeleton. |
| Data | Fleet vehicles with status chip (available / checked-out). |
| Top chrome | Back arrow + "Add vehicle" primary. |

### `/settings/vehicles/new` and `/settings/vehicles/:id` and `/settings/vehicles/:id/edit` — Vehicle edit

| Initial | Form. |
| Top chrome | Back arrow. |

### `/settings/vehicles/:id/checkout` and `/checkin` — Vehicle check-in/out

| Initial | Pre-trip / post-trip checklist. |
| Top chrome | Back arrow. |

### `/login` — Sign in

| Always | "Continue with Google" button. NO email / password / OTP. |
| Loading | Button shows spinner during OAuth round-trip. |
| Top chrome | NONE. No back arrow. No actions. |
| Omnibox | NONE — bar should not render until viewer is signed in. |

## Omnibox modes (cross-cutting)

| Mode | Trigger | Bar visual | Panel content | Enter behavior |
|---|---|---|---|---|
| **Search** (default) | Default | Surface tint, magnifier glyph, "Search anything…" | Idle: Recent captures + Pinned + Recent + For-you-now + categories. Typed: scored matches. | Open top result. |
| **Capture** | Free-text >= 5 chars (with space) or >= 10 chars, no strong catalog match | Primary tint, bolt glyph, "Save a quick note…" | Hero "Save as a capture" card with echoed text + Save button. Catalog results below. | Fire capture, snackbar. |
| **Slash** | Query starts with `/` | Tertiary tint, chevron glyph, "Slash command — type /today, /log…" | Prefix-matched command list. | Exec unambiguous match. |

| Sub-surface | Expectation |
|---|---|
| Focused (panel open) | Leading icon morphs to back-arrow. Tap = collapse. |
| System back | Collapses panel FIRST; second press pops route. |
| Kid mode | Bar hidden entirely. |
| Active voice session | Mic icon flips to red `stop_circle`. Bar shows running transcript. |
| Recent captures strip | Renders ONLY in idle + search mode. Top 5 open captures, horizontally scrolling chips. Tap → `/captures`. |

## Voice dictation (Deepgram)

| Pre-state | Expectation |
|---|---|
| No `DEEPGRAM_API_KEY` | Tap mic → snackbar "Voice dictation is not configured". |
| Permission denied | Tap mic → snackbar "Microphone permission was declined". |
| First launch | OS permission prompt on tap. |
| Connecting | (~500ms) Brief no-icon-change moment; transcript empty. |
| Listening | Mic icon red `stop_circle`. Interim transcript updates the composer in real time. Existing typed text preserved as a prefix. |
| Stopping | Tap mic again → finalizing state for ~400 ms → idle. Final transcript stays in composer. |
| WS dropped | Snackbar "Voice connection dropped." Mic returns to idle. |

## Kid mode

| Pre-state | Expectation |
|---|---|
| `kidModeProvider == true` | Omnibox bar HIDDEN. Top chrome HIDDEN. Body padding zeroed so the kid surface fills the screen. |
| Enter | Surfaces call `ref.read(kidModeProvider.notifier).enter()` in `initState`. |
| Exit | Surfaces call `.exit()` in `dispose`. Future: staff-only PIN. |
| Currently using | `/surveys/:templateId/take/:subjectId` only. |

## Sync + offline

| Pre-state | Expectation |
|---|---|
| Offline at boot | App opens to last local state. Sync indicator shows offline. No error banners or modals. |
| Offline write | UI commits immediately. PowerSync queues. Sync indicator shows "queued N". |
| Reconnect | Queue drains automatically. Sync indicator returns to idle. |
| Token expiring | Connector auto-refreshes 60 s before expiry. No user-visible hiccup. |

## When to update this doc

Any time a new screen, a new omnibox mode, a new voice / kid-mode
surface, or a new sync invariant lands, add the row here BEFORE
declaring the work done. Treat the matrix like the test pyramid —
if a regression slips through, the matrix didn't cover the case;
add the missing row in the same PR that fixes the regression.
