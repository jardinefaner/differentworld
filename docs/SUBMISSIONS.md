# Submissions — what a learner chooses to share, and how the teacher sees it

**Status:** design approved (2026-05-31). Slice A (offline curate + the
contextual viewer) building now.
**Origin:** "the photos are offline-first; the choice the kids want to
share is what's uploaded — their submission; the teacher view is all of
their galleries; and in the full-screen view it's laid out with the
context, and maybe their reflections / notes."

**The one principle:** **shoot abundantly offline, share deliberately.**
Everything a learner captures stays on the device. Only what they *choose*
to share becomes a **submission** that uploads. The teacher sees each
learner's submitted gallery — and any photo, full-screen, carries its
context (the activity, the prompt, when) and the learner's reflection.

This is the persistence layer the activity runtime (ACTIVITY_RUNTIME.md)
was waiting for, and it obeys the binary-media rule (CLAUDE.md): the bytes
ride Supabase Storage; the synced row carries only a path.

---

## 1. The pipeline

```
capture (local, offline)  →  curate (opt-in select)  →  submit (upload chosen)
                                                            │
                                              teacher aggregate ── contextual present
```

- **Capture** — every shot lands in local device storage immediately. No
  network, ever, at capture time. A kid on a field trip with no signal
  shoots 40 photos; all 40 are safe locally.
- **Curate** — the learner picks which captures to share. The default is
  **nothing shared** — sharing is an explicit, per-photo choice. The
  unshared never leave the device.
- **Submit** — only the chosen photos upload (compressed) to a private
  Storage bucket; their rows + the reflection text sync. Offline at submit
  time → queued, uploaded when online (the `pending:<local-path>` pattern).
- **Teacher aggregate** — the teacher's device sees every learner's
  submission for the activity, grouped by learner: "all of their
  galleries."
- **Contextual present** — any photo, full-screen, is laid out *with its
  context* (activity title, the prompt, capture time, the learner) plus
  the reflection. Same viewer for learner, teacher, and family.

---

## 2. The data model (reuse what exists)

No new heavy tables. A submission is an **entry**; the photos are
**attachments**; both already sync.

- **`entries`** row, `kind = 'submission'`:
  - `subject_id` = the learner, `group_id` = the cohort,
    `schedule_block_id` = the activity's block (the auto-tag from
    LIVE_BLOCK_CONTEXT.md — this is what "everything relates to the
    activity" means concretely).
  - `payload` (jsonb): `{ activityId, prompt, reflection }` — the
    submission-level note + the context to render the viewer.
- **`attachments`** rows, `entity_kind = 'entry'`, `entity_id = <entry>`:
  one per shared photo. `storage_path` → the bytes in the private bucket;
  optional per-photo `caption` (a photo-level reflection). The thumbnail
  path rides alongside (256 dp variant, per CLAUDE.md).
- **Reflections** live as text: the submission-level one in the entry
  payload, per-photo ones on the attachment. Edited with the formless atom
  (`InlineEditableText`).

Why entries + attachments: the family lens, the showcase, and the teacher
view all already know how to read them. A submission is just an entry a
teacher can browse and a family can see.

---

## 3. Storage + privacy (children's PII — treat as audited)

- A **private** bucket (`activity-media`), RLS-scoped to space membership
  (first path segment = the caller's space), signed URLs minted at view
  time (1-hour TTL) — the exact pattern `person-photos` uses.
- **Only shared photos upload.** Unshared captures never touch the
  network — the strongest privacy default: a kid's throwaway / candid
  shots they didn't choose simply don't exist server-side.
- Compress to ~1 MB + a 256 dp thumb at submit time; list/teacher views
  use the thumb, the full-screen viewer the full size.
- No child identifiers in any path or log; signed URLs only, never
  `getPublicUrl`.

---

## 4. The rules (invariants)

- **Capture is always offline-first and never blocks.** A shot commits to
  local storage in one frame; no await, no network, no error state.
- **Nothing uploads without an explicit share.** Default unshared. Toggling
  share off before submit (or after) removes it from the submission;
  un-uploaded bytes stay only on the device.
- **The bytes ride Storage; the row rides PowerSync.** Never a photo
  through the sync stream. The attachment row carries a path string.
- **Submit is optimistic + queued.** Offline submit writes the entry +
  attachments locally with `pending:` paths; the upload queue swaps them
  for Storage paths when online. The learner sees "shared" immediately.
- **One viewer, three audiences.** The full-screen contextual view (photo
  + activity/prompt/time + reflection) is the same widget for the learner
  curating, the teacher reviewing, and the family viewing — fed by the
  entry + attachment, never bespoke per surface.
- **The teacher sees shares, not the raw camera roll.** The aggregate view
  reads submitted entries only; unshared captures are invisible to it.

---

## 5. The acceptance rubric

**Offline + curate (Slice A)**
- ☐ Capture works fully offline; shots persist locally across the run.
- ☐ Default is unshared; sharing is an explicit per-photo toggle.
- ☐ Full-screen viewer shows the photo + context (activity, prompt, time)
  + an editable reflection.
- ☐ Toggling share is reversible; unshared photos are excluded from the
  submission.

**Upload + sync (Slice B)**
- ☐ Submit uploads only shared photos to the private bucket; the entry +
  attachment rows carry paths, sync via PowerSync.
- ☐ Offline submit queues; uploads when online; the row's UUID is stable.
- ☐ Unshared photos never produce a network request.

**Teacher aggregate (Slice C)**
- ☐ The teacher sees every learner's submitted gallery for the activity,
  grouped by learner.
- ☐ Opening a teacher-side photo shows the same contextual viewer.
- ☐ A learner with no submission renders as "nothing shared yet", not a
  blank.

---

## 6. The build seed

**Slice A — offline curate + contextual viewer (runnable now, on-device).**
Extend the Photography screen: after shooting, the gallery becomes a
*curate* surface — each capture has a share toggle (default off); tapping a
photo opens a full-screen contextual viewer (the photo + activity title +
prompt + capture time + an editable reflection via `InlineEditableText`).
All local / in-session — proves the "shoot freely → pick what to share →
see it with context + notes" feel without any backend.

**Slice B — the upload path.** A private `activity-media` bucket
(migration + RLS + a Storage policy) + compress/thumbnail + an upload
queue (extend `photo_upload_queue`) + write the `entries`(kind=submission)
and `attachments` rows on submit. Offline-first via `pending:` paths.

**Slice C — the teacher aggregate.** A surface (reachable from the
schedule block / activity) listing each learner's submitted gallery for
the activity, opening the same contextual viewer. Cross-device; reads
submitted entries grouped by subject.

Slice A is the feel; B is the privacy-respecting upload; C is "the teacher
view is all of their galleries." Each is its own wave — B and C touch the
synced-table + Storage + RLS layers and need a device storage wipe on
deploy.
