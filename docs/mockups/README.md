# Mockups — the proposals, and what became of them

Every in-chat mockup shown during design, archived as source **and** as a
rendered PNG, in date order.

The point is not the pictures. It is the **Outcome** column: a proposal that
was rejected, and why, is worth more six months from now than one that
shipped — the shipped one is visible in the app, and the rejected one is the
thing somebody will otherwise propose again.

## How to add one

1. Save the widget's HTML to `src/<NNN>-<slug>.html` — the same markup shown
   in chat, nothing else.
2. `scripts/render_mockups.sh` renders every `src/*.html` to
   `<NNN>-<slug>.png` at phone width.
3. Add a row below, with the outcome once it is known.

Re-render is idempotent, so running it after editing a mockup just updates
that PNG. **The outcome column is the part that goes stale** — update it in
the same wave the decision is made, not later.

## The log

| # | Date | Proposal | Outcome |
|---|---|---|---|
| 001 | 2026-08-25 | [Pick Me with faces](001-pick-me-faces.png) — reveal + "still waiting" as faces instead of a comma list | **Shipped.** `turns_screen.dart`; the waiting row is `PersonFaceWrap`. |
| 002 | 2026-08-26 | [Five outcomes](002-five-outcomes.png) — reorganise 64 features under Safe / Noticed / Heard / Made / Shared | **Rejected**, by me and then by the user's framing. Five bins to sort features into answers "how is this organised", not "where do I start". Superseded by Guide → Engage → Capture → Keep → Return, which is a LOOP and therefore explains impact. Kept because the instinct to re-file features under nicer nouns will recur. |
| 003 | 2026-08-26 | [The day arc](003-day-arc.png) — what Today leads with at each phase | **Not a proposal — a reading of the existing clock.** Documented what `DayPhaseWindows` already does (prep → arrival 2:30 → program 3:45 → pickup 4:45 → closed 6:30). Its finding: the day never needs the drawer, which is why "Start simple" mattered less than pitched. |
| 004 | 2026-08-26 | [One room, one page](004-one-room-one-page.png) — the four setup jobs on one surface | **Shipped, then went further.** `RoomSetupScreen`. The mockup still had "Add a block" handing off to the schedule; the built version does it inline, and the page became `/groups/:id` itself rather than an eighth place. |
| 005 | 2026-08-26 | [Class memory](005-class-memory.png) — what a room remembers, plus Return arriving mid-activity | **Band one shipped** (`ClassMemoryScreen`, `/groups/:id/memory`). The Return card at the bottom is NOT built — it is the harder half and the one that could turn the app into a nag, so it stays a proposal until the memories exist to return. |

## Standing conventions these mockups encode

- **Faces, not counts.** Seven names in a comma list is something you read;
  seven faces is something you glance at.
- **State, not links.** A band shows fourteen children, not "Manage
  children →".
- **The warning sits beside the fix.** Ratio shortfall renders next to the
  adults, not on a compliance screen.
- **Adding is inline.** A "+" that navigates away is how one job becomes
  seven screens.
