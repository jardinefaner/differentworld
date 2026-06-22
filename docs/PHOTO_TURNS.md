# Per-child timed photo turns

One phone, passed around a cohort, so every child gets a fair, timed turn
with the camera — then the room reviews together and each child's
favorites file into their own folder. Built on the existing Photo Studio
runner ([ACTIVITY_RUNTIME.md](ACTIVITY_RUNTIME.md) §5,
[SUBMISSIONS.md](SUBMISSIONS.md)) plus the photo tag axes.

> The workflow, in the user's words: "one phone, choose a child, give them
> 5 minutes locked, they go shoot, *time's up — give to teacher*, exit +
> choose the next child; after everyone, a group review where each picks
> favorites, filing into per-child folders."

---

## The shape

Three surfaces, one runner.

1. **The picker** — `PhotoTurnsScreen` at `/activity/photo-turns?block=<id>`.
   The "Whose turn?" roster. Staff-run (a normal, un-locked screen). Roster
   = the block's GROUP (`subjectsInGroupProvider`) when a `block` id is
   passed, else the whole visible roster (`subjectsInSpaceProvider`). Tap a
   child → their turn starts. A local `Set<String>` tracks who's done; it
   re-hydrates from the data layer on rebuild (see "Done-tracking" below) so
   a process kill mid-session doesn't reset progress.

2. **The timed turn** — `PhotographyRunnerScreen` in its **turn mode**
   (`turnSubjectId != null`). The picker pushes it imperatively
   (`MaterialPageRoute`, fullscreen). On mount it auto-engages the kid-lock
   and starts a **5-minute countdown** (a const default, `turnDuration`).
   The camera chrome shows the child's name + a big live countdown + the
   mission. **Every shot is stamped** `captured_by_subject_id = this child`
   + `schedule_block_id = the block`, and auto-persisted (a turn shot is a
   keeper — no per-shot heart needed). At 0 the camera **hard-stops** behind
   a "Time's up — give the phone to your teacher" overlay; staff reclaim via
   the hidden 5-tap corner, which pops back to the picker and marks the
   child done.

3. **The review** — `PhotoTurnsReviewScreen`. One strip per child who shot
   (their `attachmentsCapturedByCuratedProvider` folder), a heart on each
   photo. Hearting marks a favorite; favorites float to the top of that
   child's folder. Children who shot nothing don't render a strip.

The plain Photo Studio (`/activity/photo`, no `turnSubjectId`) is
**unchanged** — turn mode is purely additive.

---

## The load-bearing decision: favorites reuse `sort_order` (no migration)

The review's heart needs a "favorite" flag on each photo. Rather than add a
boolean column (a migration + a PowerSync schema bump + a local wipe on
every device), the favorite **reuses the existing `attachments.sort_order`**:

| State | `sort_order` written | Effect |
|---|---|---|
| Favorite | `0` | sorts to the TOP of the child's folder |
| Not a favorite | `1_000_000_000` (sentinel) | sorts below every favorite |

The per-child folder reads through `attachmentsCapturedByCuratedProvider`
→ `AttachmentsDao.watchCapturedByCurated`, which orders
`COALESCE(sort_order, 1e9) ASC, created_at DESC`. The `COALESCE` matters:
SQLite sorts `NULL` **first** on an `ASC` order, so an un-favorited (NULL)
row would wrongly hoist above the favorites — coalescing NULL → the
sentinel pushes it below. The write goes through the existing
`attachmentActions.reorder(id:, sortOrder:)` (a typed Drift UPDATE, so
PowerSync queues it — optimistic + offline-safe).

**Trade-off:** we lose the ability to *also* hand-order non-favorites within
a turn. That's fine — turns don't need manual ordering, and the favorite is
the only ordering signal a review cares about. If a future surface needs
both manual order AND a favorite flag on the same rows, that's the signal to
add the boolean column then.

The non-curated `attachmentsCapturedByProvider` (newest-first) is untouched,
so the growth-book / progress-folder consumers keep their existing order.

---

## Done-tracking (and why it survives a process kill)

The picker's `_done` `Set` is the progress UI, but it's in-memory — an OS
process kill mid-session would otherwise show everyone "to go" again. The
durable truth lives in the attachments: every turn shot carries
`schedule_block_id`. So when launched from a block, the picker watches
`attachmentsForBlockProvider(blockId)` (ONE stream) and merges every
`captured_by_subject_id` it finds into the displayed done-set. One query
re-hydrates the whole roster's progress; no N-per-child subscriptions.

(The ad-hoc, no-block path has no cheap single-query equivalent, so it
relies on `_done` alone — acceptable, since the block path is the primary
one.)

---

## Lifecycle (the bug surface)

The countdown + the kid-lock across turns are the risk. The invariants:

- **The countdown timer** (`_countdown`, `Timer.periodic`): cancelled in
  `dispose`, on turn-end (`_endTurn`), and the instant it hits 0; never two
  at once (`_startCountdown` cancels before restarting); every tick guards
  on `mounted`. At 0 it does NOT release the lock — the kid keeps the phone
  but can't shoot; staff reclaim.
- **The lock is set SYNCHRONOUSLY** in `initState` for a turn (`_locked =
  true`) so `PopScope` blocks system-back from frame 0 — otherwise a
  one-frame window lets a fast back escape before the deferred lock fires.
  The provider WRITE (kidMode enter + route pin) still defers to a post-
  frame microtask (initState runs inside the parent's build phase, and
  AppShell watches `kidModeProvider` — a synchronous write trips "modified a
  provider while building"). A separate `_lockEngaged` flag guards the
  provider write so the synchronous `_locked` pre-set doesn't short-circuit
  the deferred engage.
- **The pinned route is the LIVE location**, not the constant
  `/activity/photo`. A turn is pushed over the picker's
  `/activity/photo-turns`, so its `matchedLocation` is the picker's — the
  router redirect would bounce the whole stack to the plain studio if we
  pinned `/activity/photo`. `_resolvePinnedRoute` reads
  `GoRouterState.of(context).uri.path` at lock time (post-frame, context
  valid), falling back to `/activity/photo-turns`.
- **Per-child stamp is snapshotted on the `_Shot`** at capture time, not
  re-read from `widget.turnSubjectId` at persist time — so an in-flight
  `_persistShot` can never mis-file one child's photo into another's folder
  if the widget were ever recycled. This is the cross-child privacy
  guarantee.
- **Post-buzzer shots can't land**: `_shoot` re-checks `_timeUp` *after* the
  async `takePicture()` returns, dropping a frame that was mid-capture when
  time ran out.
- **No kid-tapped exit**: the "Done" button is hidden in turn mode. A turn
  ends only on the buzzer or a staff corner-unlock, so a child can't cut
  their own time short or escape into the curate flow.
- **The picker's launch guard** (`_launching`) is set synchronously via
  `setState` before the first `await`, and cleared in a `finally`, so a
  double-tap can't launch two runners and a route-builder throw can't
  deadlock the button.

---

## Discovery surfaces

- **Route:** `/activity/photo-turns?block=<id>&prompt=<text>`
  ([router.dart](../lib/app/router.dart)).
- **Slash:** `/phototurns {prompt}` (aliases: `turns`, `cameraturns`,
  `phototurn`) — gated on `isMobileCapturePlatform` like `/photo`
  ([slash_commands.dart](../lib/features/omnibox/slash_commands.dart)).

A schedule block whose activity runner is Photo Studio is the natural
launch point; a "run as turns" affordance on the block run sheet is the
obvious next wiring step.

---

## Files

- [lib/features/activity_runtime/photo_turns_screen.dart](../lib/features/activity_runtime/photo_turns_screen.dart)
  — the picker + the review.
- [lib/features/activity_runtime/photography_runner_screen.dart](../lib/features/activity_runtime/photography_runner_screen.dart)
  — the runner, now with turn mode.
- [lib/core/db/dao/attachments_dao.dart](../lib/core/db/dao/attachments_dao.dart)
  — `watchCapturedByCurated` (favorites-first ordering).
- [lib/features/photos/attachments_providers.dart](../lib/features/photos/attachments_providers.dart)
  — `attachmentsCapturedByCuratedProvider`.
- [lib/features/schedule/schedule_providers.dart](../lib/features/schedule/schedule_providers.dart)
  — `scheduleBlockByIdProvider` (resolves a block → its group for the roster).
