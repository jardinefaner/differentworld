---
name: family-login
description: Family / guardian login is the next big viewer subtype. Data model is in (guardians, subject_guardians, GuardianViewer skeleton); the auth + UI is the work remaining. Triggered when wiring family-side features.
---

# Family / Guardian login

The architecture is staged. What's built, what's left.

## Built

- **`guardians` table** — id, space_id, name, relationship, phone,
  email, authorized_for_pickup, notes. Synced via PowerSync's
  by_space stream.
- **`subject_guardians` join table** — many-to-many, with `is_primary`
  for "default contact" ordering.
- **Drift classes** — `Guardians`, `SubjectGuardians`, plus
  `watchGuardiansForSubject`, `createGuardianForSubject`,
  `unlinkGuardianFromSubject`.
- **Providers** — `guardiansForSubjectProvider`,
  `GuardianActions.{addToSubject, unlink}`.
- **Director UI** — "Family" section on Subject form sheet (edit mode)
  with an "Add guardian" sub-sheet. Director attaches guardians to
  children; teachers / assistants see this section read-only.
- **`GuardianViewer` skeleton** — subclass of `Viewer` in
  `lib/core/viewer/viewer.dart`. Carries the guardian row + the
  scoped list of child subject IDs. All staff caps return false;
  `canSeeSubject(id)` is the per-child gate.

## Not built (next session)

### Auth path

A user signing in is currently always routed to the `members` table
via `handle_new_user`. For guardians:

- **Option A** — Guardian invite carries a "this email becomes a
  guardian, not a member" flag. The `accept_invite` RPC writes a
  `guardians` row instead of (or in addition to) a `members` row.
- **Option B** — At signup, the user picks "I'm staff" vs "I'm family".
  Cleaner UX but cluttered first-touch.

Recommend Option A: invites carry an intent (`role` = 'guardian'
joins a new path).

### Viewer resolution

`viewerProvider` currently always returns a `Viewer` from the member
row. Extend it:

```dart
final viewerProvider = Provider<Viewer>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return const Viewer.empty();

  // Try member first.
  final member = ref.watch(currentMemberProvider).value;
  if (member != null) {
    return Viewer(member: member, space: ref.watch(currentSpaceProvider).value);
  }

  // Try guardian.
  final guardian = ref.watch(currentGuardianProvider).value;
  if (guardian != null) {
    final children = ref.watch(myChildrenProvider).value ?? [];
    return GuardianViewer(
      guardian: guardian,
      childSubjectIds: children.map((s) => s.id).toList(),
      space: ref.watch(currentSpaceProvider).value,
    );
  }

  return const Viewer.empty();
});
```

Plus `currentGuardianProvider` and `myChildrenProvider` (streams
keyed by the signed-in `auth.uid()`, scoping to the guardian's
subject_guardians rows).

### Family-side UI

- **Today** — replace the staff Today with a child-list. Per child:
  status (checked-in / late), today's last observation, last photo.
- **Per-child detail** — full feed of observations + meals + naps,
  photos, recent attendance, medical notes (read-only).
- **Messages** — thread per teacher per child.
- **Pickup auth** — guardian manages their own list of approved
  pickup people for each of their kids.
- **Billing** — invoice list + pay.

### Schema gaps

The `guardians` table doesn't yet link to `auth.users.id` — guardian
rows currently are just contact entries that staff create. For a
guardian to LOG IN we need either:
- A `user_id uuid references auth.users(id)` column on `guardians`,
  populated when an invite is accepted by an authenticated user.
- Or a parallel approach where the guardian-side identity IS
  auth.users and the `guardians` table's `id` IS `auth.users.id`.

The latter mirrors how members already work and is simpler. Migration
to add the constraint comes when the auth flow lands.

## Where to look

- `lib/core/viewer/viewer.dart` — `GuardianViewer` class
- `lib/features/guardians/guardians_providers.dart` — providers + actions
- `lib/features/subjects/widgets/subject_form_sheet.dart` — the
  `_GuardiansSection` widget and `_AddGuardianSheet`
- `supabase/migrations/20260518000001_universal_rename.sql` — the
  guardians + subject_guardians table definitions

## When you start the family-side wave

Read this skill, then the `viewer-lens` skill. Build in this order:

1. Migration: add `user_id` to guardians OR repurpose `id`
2. Guardian invite intent in `app.accept_invite`
3. `currentGuardianProvider` + `myChildrenProvider`
4. Extend `viewerProvider` to resolve guardian viewers
5. Family-side Today (the simple version: list of children with status)
6. Per-child timeline (observations + photos + attendance)
7. Pickup auth UI for the guardian's own list
8. Messages (separate table — `messages(id, thread_id, ...)`)
9. Billing (its own wave)
