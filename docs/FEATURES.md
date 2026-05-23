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

The drawer's main destinations are **Today**, **Schedule**, **Captures**,
**Tasks**, **Settings**. Everything else is reachable via the omnibox
(`/search`) or via slash commands. Settings is the library / admin
surface — preferences + roster + fleet, not primary workflows.

---

## Attendance
**Path**: `lib/features/attendance/`
**Purpose**: Daily check-in / check-out for one cohort at a time.
**Personas served**: All staff (Maya for oversight, Jordan + Coach Sam day-to-day).
**Discovery surfaces**:
- Routes: `/checklist`, `/groups/:id/attendance`
- Omnibox: yes — "Morning checklist", "Take attendance · {Group.name}" (dynamic per cohort)
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

## Entries
**Path**: `lib/features/entries/`
**Purpose**: Unified daily log — observations, meals, naps, diapers, incidents — all rows in one table with a `kind` discriminator.
**Personas served**: All staff (Jordan + Coach Sam log; Maya reviews; Marcus + Lauren read).
**Discovery surfaces**:
- Routes: `/observations`, `/observations/new`, `/observations/:id/edit`, `/groups/:id/observations`
- Omnibox: yes — "Observations" (gated by `can_observe`), "Observations · {Group.name}" (per cohort), "New {entry label}" (action), "Quick observation · {Name}" (per subject)
- Slash: `/log {kid}` (aliases `/observe`, `/obs`)
- Drawer: no
- Settings: no
**Capabilities**: `can_observe`
**Data**: [entries](SCHEMA.md#entries), [attachments](SCHEMA.md#attachments)
**Surfaces**:
- *Observations index* — `lib/features/entries/observations_index_screen.dart`. Newest-first feed across all groups (filterable).
- *Observations screen* — `lib/features/entries/observations_screen.dart`. Per-cohort feed.
- *Observation form* — `lib/features/entries/observation_form_screen.dart`. Create / edit a single entry; photo attach, voice dictation via Deepgram mic (suffix-icon on the body TextField; owns its own `DeepgramVoiceController` instance — does NOT consume the shared `deepgramVoiceProvider` singleton, to avoid the dual-listener race against AppShell's composer mic).
**Depends on**: Subjects, Groups, Attachments, Photos, Voice (Deepgram dictation on the body field).
**Consumed by**: Exports (Progress Report compiles entries), Captures (promotion destination), Insights (pattern detection), Family (Lauren read), Today (recent activity card).
**Last verified**: 2026-05-22

---

## Exports
**Path**: `lib/features/exports/`
**Purpose**: Compile a child's observations into a shareable PDF and send to family via email or copy-link.
**Personas served**: Maya (creates), All staff with `can_observe` (creates for their subjects), Lauren (recipient), Marcus (recipient).
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
**Consumed by**: Family Today (Lauren sees received reports — not yet wired).
**Last verified**: 2026-05-21

---

## Family
**Path**: `lib/features/family/`
**Purpose**: Guardian (parent) lens. Read-only view of linked children + the messaging surface.
**Personas served**: Lauren, Devon, Helen, Marcus.
**Discovery surfaces**:
- Routes: `/children/:sid` (FamilySubjectDetailScreen), `/messages` (FamilyMessagesScreen — index), `/messages/:subjectId/:guardianId`
- Omnibox: yes — "Messages" (gated by guardian + has-linked-children)
- Slash: none
- Drawer: no — guardian sees a different drawer (TBD); today drawer is staff-only
- Settings: no
**Capabilities**: Guardian role (`member.role == 'guardian'` AND `guardians.user_id == auth.uid()`).
**Data**: [messages](SCHEMA.md#messages), [subjects](SCHEMA.md#subjects) (read-only via direct PostgREST — not in `by_space` stream), [subject_guardians](SCHEMA.md#subject_guardians)
**Surfaces**:
- *Family today* — `lib/features/family/family_today_screen.dart`. Each linked child's card; recent observation count, today's activity. Photo-of-the-moment deferred for Lauren.
- *Family subject detail* — `lib/features/family/family_subject_detail_screen.dart`. Read-only child profile + photo gallery.
- *Family messages index* — `lib/features/family/family_messages_screen.dart`. Per-child thread list.
- *Message thread screen* — `lib/features/messages/message_thread_screen.dart` (cross-feature — see Messages).
**Depends on**: Subjects (direct PostgREST), Guardians, Messages.
**Consumed by**: Nothing — this is a leaf lens.
**Last verified**: 2026-05-21

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

## Insights
**Path**: `lib/features/insights/`
**Purpose**: System-derived questions from patterns — expiring certs, late streaks, stale vehicles, unwritten observations, low-signal surveys.
**Personas served**: Maya (director-tier oversight). All staff with `can_observe` see the surface.
**Discovery surfaces**:
- Routes: `/insights`
- Omnibox: yes — "Insights"
- Slash: `/insights`
- Drawer: no (omnibox-only entry)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Some insights are member-scoped (only the affected staff sees them); some are space-wide.
**Data**: derived — reads [attendance_records](SCHEMA.md#attendance_records), [member_certifications](SCHEMA.md#member_certifications), [vehicle_logs](SCHEMA.md#vehicle_logs), [entries](SCHEMA.md#entries), [captures](SCHEMA.md#captures), [survey_responses](SCHEMA.md#survey_responses). Snooze state in [dismissed_insights](SCHEMA.md#dismissed_insights).
**Surfaces**:
- *Insights screen* — `lib/features/insights/insights_screen.dart`. Card list; tap to drill into the underlying data; swipe to dismiss (per-member snooze).
**Depends on**: Attendance, Certifications, Vehicles, Entries, Captures, Surveys.
**Consumed by**: Today (top-N insight chip).
**Last verified**: 2026-05-21

---

## Invites
**Path**: `lib/features/invites/`
**Purpose**: Staff onboarding via 6-char invite codes (deep link + QR + share-text); cold-launch & warm-app deep links both supported.
**Personas served**: Maya (creates + revokes), Brianna (redeems on her phone).
**Discovery surfaces**:
- Routes: `/settings/team/invite/new`, `/settings/team/invite/:id`
- Omnibox: yes — "Invite a teammate" (action)
- Slash: none
- Drawer: no
- Settings: no — embedded in Team
**Capabilities**: Create / revoke: `can_invite_staff`. Redeem: pre-auth or post-auth without an active space.
**Data**: [invites](SCHEMA.md#invites)
**Surfaces**:
- *Invite create screen* — `lib/features/invites/invite_create_screen.dart`. Role + optional email + expiry chips.
- *Invite share screen* — `lib/features/invites/invite_share_screen.dart`. The created code; copy / QR / share-text.
- *Deep-link listener* — `lib/features/invites/deep_link_listener.dart`. Captures `differentworld://invite/<code>` and the https fallback into `pendingInviteCodeProvider`; consumed by `home_redeem_invite_host.dart`.
**Depends on**: Members (assigning role), Spaces.
**Consumed by**: Team screen (pending-invites list), Onboarding (redeem path).
**Last verified**: 2026-05-21

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

## Messages
**Path**: `lib/features/messages/`
**Purpose**: Staff↔Guardian per-child thread. Async written communication.
**Personas served**: All staff (write to family), Lauren / Devon / Helen / Marcus (receive + reply).
**Discovery surfaces**:
- Routes: `/messages`, `/messages/:subjectId/:guardianId`
- Omnibox: yes — "Messages" (gated by guardian-with-children OR staff)
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
**Purpose**: The persistent bottom composer — search / capture / slash command / voice. The spine of the app's interaction model.
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
**Purpose**: Post-auth, pre-space flow. Lets a new signed-in user join an existing space (via invite code) or create a new one.
**Personas served**: Brianna (joining), Maya (creating).
**Discovery surfaces**:
- Routes: `/onboarding/join-or-create` (and any sub-routes)
- Omnibox: no — pre-space surface
- Slash: none
- Drawer: no — drawer only mounts after space is selected
- Settings: no
**Capabilities**: None — pre-space.
**Data**: [spaces](SCHEMA.md#spaces), [members](SCHEMA.md#members), [invites](SCHEMA.md#invites)
**Surfaces**:
- *Join-or-create screen* — `lib/features/onboarding/join_or_create_screen.dart`. Two paths: enter an invite code, or create a new program. Pushes Create when the user chooses to start fresh.
- *Create space screen* — `lib/features/onboarding/create_space_screen.dart`. Bare-minimum form (program name + vertical). Inserts the `spaces` row + flips the current member into it.
**Depends on**: Invites (redeem), Auth.
**Consumed by**: Router (post-login redirect when `viewer.spaceId == null`).
**Last verified**: 2026-05-22

---

## Photos
**Path**: `lib/features/photos/`
**Purpose**: Signed-URL minting + cached display for person photos (avatars, observation attachments). Bytes live in Supabase Storage's private `person-photos` bucket; rows carry only the bucket-relative path.
**Personas served**: All staff (upload + view), All guardians (view their own children).
**Discovery surfaces**:
- Routes: none — utility widgets
- Omnibox: no
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: Read via signed URL (RLS-scoped to space membership; first path segment must match caller's `members.space_id`). Write: any staff who can mutate the parent row.
**Data**: References [members](SCHEMA.md#members).`avatar_url`, [subjects](SCHEMA.md#subjects).`photo_url`, [attachments](SCHEMA.md#attachments) — none of those tables is owned by this feature.
**Surfaces**:
- *PersonAvatar widget* — `lib/shared/widgets/person_avatar.dart`. Renders an avatar by minting a 1-hour signed URL.
- *PersonPhotoNetwork* — used by gallery + viewer sites.
- *Signed-URL provider* — `lib/features/photos/person_photo_url.dart`. `signedPersonPhotoUrlProvider` is the single mint point; handles legacy full-URL rows via `extractPersonPhotoPath`.
**Depends on**: Supabase Storage client.
**Consumed by**: Members, Subjects, Entries (attachment display), Family.
**Last verified**: 2026-05-21

---

## Pickup
**Path**: `lib/features/pickup/`
**Purpose**: Authorized-pickup records — who's allowed to take a child home.
**Personas served**: Maya (configures), All staff (verifies at dismissal), Lauren / Devon (their entries).
**Discovery surfaces**:
- Routes: none — embedded in Subject detail
- Omnibox: no
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: Configure: `can_authorize_pickup` (gated cap). Verify at dismissal: all staff.
**Data**: Lives in [subjects](SCHEMA.md#subjects).capabilities JSONB (`pickup_people`, `authorized_pickup_guardian_ids`, `pickup_strict`).
**Surfaces**: Status: not yet wired to UI. Authorized-pickup section embedded in `lib/features/subjects/subject_detail_screen.dart` is the planned home.
**Status**: stub — data shape lives in `subjects.capabilities` but no dedicated screen yet.
**Depends on**: Subjects, Guardians.
**Consumed by**: Future end-of-day dismissal flow.
**Last verified**: 2026-05-21

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
**Last verified**: 2026-05-21

---

## Schedule
**Path**: `lib/features/schedule/`
**Purpose**: Per-cohort, per-day block planning — activities, locations, leads, and one-tap "X is out, Y is covering" substitution.
**Personas served**: Maya (plans the week — tablet grid deferred), Coach Sam (sees blocks + pre-block brief), Pat (covers absent leads), All staff (see their day).
**Discovery surfaces**:
- Routes: `/schedule`, `/schedule/block`
- Omnibox: yes — "Schedule" (with keywords: day, block, rotation, agenda, plan, field trip, trip), "Schedule · {Group.name}" (per cohort), "Cover today · {Group.name}" (per cohort, action, gated by `can_manage_schedule`)
- Slash: `/schedule`
- Drawer: yes — "Schedule" (main destinations, position 2)
- Settings: no
**Capabilities**: Read: all members. Write: `can_manage_schedule` (director / lead-tier).
**Data**: [schedule_blocks](SCHEMA.md#schedule_blocks), [activities](SCHEMA.md#activities), [locations](SCHEMA.md#locations), [trip_logistics](SCHEMA.md#trip_logistics), [trip_vehicles](SCHEMA.md#trip_vehicles), [permission_slips](SCHEMA.md#permission_slips), [headcounts](SCHEMA.md#headcounts)
**Surfaces**:
- *Schedule screen* — `lib/features/schedule/schedule_screen.dart`. Cohort tabs × time-of-day list (phone-friendly). Tablet grid deferred for Maya.
- *Block edit screen* — `lib/features/schedule/block_edit_screen.dart`. Create / edit one block (start, end, activity, lead, location, kind).
- *Substitute lead sheet* — `lib/features/schedule/widgets/substitute_lead_sheet.dart`. Modal bottom sheet: pick absent lead → pick cover. Bulk-writes `lead_substitute_member_id` for all matching blocks on the day. Surfaceable directly from the omnibox via "Cover today · {Group.name}" (Pat persona) without first entering the schedule editor.
- *Leading-today card* — `lib/features/schedule/widgets/leading_today_card.dart`. Embedded on home; signed-in lead's blocks + cabin notes for today.
**Depends on**: Groups, Members, Activities, Locations, Vehicles (trip assignment).
**Consumed by**: Today (leading-today card), Attendance (block-context for headcounts), Captures (block-context tag), Omnibox (substitute-lead sheet invoked from the per-cohort "Cover today" entry).
**Last verified**: 2026-05-22

---

## Settings
**Path**: `lib/features/settings/`
**Purpose**: Library / admin surfaces — program config, team, fleet, locations, activities, member detail, plus device preferences.
**Personas served**: Maya (all of it), All staff (preferences + read-only team / vehicles), Helen (text-size override), Jordan (outdoor-mode toggle).
**Discovery surfaces**:
- Routes: `/settings`, `/settings/program`, `/settings/team`, `/settings/team/:id`, `/settings/vehicles`, `/settings/locations`. (Activities lives at `/activities`, not under settings, because it's used more often than configured.)
- Omnibox: yes — "Settings", "Program settings", "Team", "Vehicles", "Locations", "Activities"
- Slash: none directly; sub-features may add some later
- Drawer: yes — "Settings" (main destinations, position 5)
- Settings: this IS the settings screen
**Capabilities**: Read: all members. Program settings: `can_manage_space`. Team write / vehicles write: `can_manage_space`.
**Data**: [spaces](SCHEMA.md#spaces), [members](SCHEMA.md#members), [locations](SCHEMA.md#locations) plus what each sub-screen owns.
**Surfaces**:
- *Settings screen* — `lib/features/settings/settings_screen.dart`. Grouped list (Account / Space / Preferences / About).
- *Program settings* — `lib/features/settings/program_settings_screen.dart`. Per-space capability flags + pickup window.
- *Team screen* — `lib/features/settings/team_screen.dart`. Members + pending invites.
- *Member detail* — `lib/features/settings/member_detail_screen.dart`. Per-staff profile + certifications.
- *Locations list* — `lib/features/settings/locations_list_screen.dart`. Place catalog for scheduling.
**Depends on**: Members, Spaces, Vehicles, Locations, Activities, Invites, Certifications.
**Consumed by**: Most features (config), Helen (text scale), Jordan (outdoor mode).
**Last verified**: 2026-05-21

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
- *Subject detail* — `lib/features/subjects/subject_detail_screen.dart`. Profile + guardians + recent observations.
- *Subject edit* — `lib/features/subjects/subject_edit_screen.dart`. Create / update form.
- *Health profile screen* — `lib/features/subjects/health_profile_screen.dart`. Medical intake (allergies, dietary, IEP, etc.).
**Depends on**: Groups, Guardians, Photos.
**Consumed by**: Attendance, Entries, Exports, Family, Messages, Surveys.
**Last verified**: 2026-05-21

---

## Surveys
**Path**: `lib/features/surveys/`
**Purpose**: Questionnaires — templates authored by directors, responses collected from staff or (via kid-mode) from children.
**Personas served**: Maya (authors templates + reviews cross-cohort), All staff (take), Ava (kid-mode take). Guardians (Lauren, Devon, Helen, Marcus) don't reach the survey surface.
**Discovery surfaces**:
- Routes: `/surveys`, `/surveys/:templateId`, `/surveys/:templateId/take/:subjectId`, `/surveys/:templateId/table`
- Omnibox: yes — "Surveys"
- Slash: none
- Drawer: no
- Settings: no — surveys are top-level
**Capabilities**: None for taking. Authoring templates is gated by `can_manage_space`.
**Data**: [survey_responses](SCHEMA.md#survey_responses). Templates live in code today (no `survey_templates` table yet).
**Surfaces**:
- *Survey index* — `lib/features/surveys/survey_list_screen.dart`. List of templates.
- *Survey template detail* — `lib/features/surveys/survey_template_detail_screen.dart`. List of kids who have / haven't taken it.
- *Survey take screen* — `lib/features/surveys/survey_take_screen.dart`. One-question-per-page; auto-enters kid mode for Ava.
- *Survey table* — `lib/features/surveys/survey_table_screen.dart`. Spreadsheet review of all responses for a template.
**Depends on**: Subjects, Kid mode.
**Consumed by**: Insights (low-signal survey detection).
**Last verified**: 2026-05-21

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

## Today
**Path**: `lib/features/today/`
**Purpose**: The daily launchpad. Root destination. Context-driven cards: morning (attendance, leading-today, captures); afternoon (pickup, end-of-day capture).
**Personas served**: All staff (Jordan + Coach Sam's home base), Maya (oversight cards).
**Discovery surfaces**:
- Routes: `/` (TodayScreen)
- Omnibox: yes — "Today"
- Slash: `/today` (alias `/home`)
- Drawer: yes — "Today" (main destinations, position 1)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Cards self-gate by capability.
**Data**: Aggregates from Attendance, Schedule, Captures, Tasks, Insights, Messages, Entries.
**Surfaces**:
- *Today screen* — `lib/features/today/today_screen.dart`. Card list, refresh on pull.
- *Embedded cards* — leading-today (from Schedule), morning-checklist (from Attendance), recent-captures (from Captures), open-tasks (from Tasks), insights (from Insights), unread-messages (deferred).
**Depends on**: nearly everything.
**Consumed by**: Nothing — Today is a leaf.
**Last verified**: 2026-05-21

---

## Vehicles
**Path**: `lib/features/vehicles/`
**Purpose**: Fleet management — create / edit vehicles, pre-trip checkout, post-trip checkin (inspection trail).
**Personas served**: Maya (manages fleet), All staff with `can_drive` (checkout / checkin), Coach Sam (trip days).
**Discovery surfaces**:
- Routes: `/settings/vehicles`, `/settings/vehicles/new`, `/settings/vehicles/:id`, `/settings/vehicles/:id/edit`, `/settings/vehicles/:id/checkout`, `/settings/vehicles/:id/checkin`
- Omnibox: yes — "Vehicles", "{Vehicle.name}" (per vehicle), "Check out · {Vehicle.name}" (action, gated by `can_drive`), "Check in · {Vehicle.name}" (action, gated by `can_drive`), "Add a vehicle" (action, gated by `can_manage_space`)
- Slash: `/checkout {vehicle}` (alias `/co`), `/checkin {vehicle}` (aliases `/ci`, `/return`) — gated by `can_drive || can_manage_space`
- Drawer: no
- Settings: yes — "Vehicles" row under {Space name} group
**Capabilities**: Read: all members. Create / edit: `can_manage_space`. Checkout / checkin: `can_drive` (which itself requires an active Driver cert).
**Data**: [vehicles](SCHEMA.md#vehicles), [vehicle_logs](SCHEMA.md#vehicle_logs), [member_certifications](SCHEMA.md#member_certifications) (Driver cert gates `can_drive`)
**Surfaces**:
- *Vehicles list* — `lib/features/vehicles/vehicles_list_screen.dart`. Fleet roster.
- *Vehicle detail* — `lib/features/vehicles/vehicle_detail_screen.dart`. One vehicle's record + recent log.
- *Vehicle edit* — `lib/features/vehicles/vehicle_edit_screen.dart`. Create / update form.
- *Vehicle inspection* — `lib/features/vehicles/vehicle_inspection_screen.dart`. Pre-trip + post-trip checklist (same screen, different mode).
**Depends on**: Members, Certifications.
**Consumed by**: Schedule (trip assignment), Insights (stale-vehicle signal).
**Last verified**: 2026-05-21

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
**Status**: voice dictation wired in two places — the omnibox composer mic AND the observation-form body field (Jordan's "voice on the floor" item, partially shipped 2026-05-22). Capture-form mic still pending.
**Depends on**: `DEEPGRAM_API_KEY` in `.env`, `record` plugin, mic permission.
**Consumed by**: Omnibox (composer mic — uses the shared `deepgramVoiceProvider` singleton), Entries (observation form body field — instantiates its own `DeepgramVoiceController`, does not consume the singleton).
**Last verified**: 2026-05-22

---

## Coverage gaps to track (auto-populated by persona-audit)

This section is intentionally left for the `persona-audit` agent to fill
in. Run `Agent persona-audit` to refresh.

---

## Drift / discovery warnings (auto-populated by feature-mapper)

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

---

_Last full registry verification: 2026-05-22 (Wave 24 omnibox interaction hardening)._
_If a feature is missing from this file, the feature-mapper agent will
add a stub the next time it runs. Don't hand-write entries unless
you're also updating the agent's view of truth._
