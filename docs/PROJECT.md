# Different World — what it is

**The one-sentence pitch:** an offline-first app that lets every
teacher in an early-childhood program log what happens to the children
they care for, without it feeling like paperwork.

## What it does, concretely

A teacher opens the app on her phone at 8 AM, marks all 18 of her
children present in under 90 seconds. Throughout the day she taps to
log meals, naps, diaper changes, and the moments worth remembering —
usually a sentence, sometimes with a photo. When her shift ends she
hands off a clean record to the afternoon teacher. At 5 PM, families
get a daily report assembled from those taps. At the end of the week,
the lead teacher has a real record of each child's developmental
moments and the director has compliance-ready attendance for the state
inspector.

It works whether or not the classroom has wifi. Every tap commits
locally and syncs in the background. A teacher who handed off mid-day
can leave a clean record for the afternoon sub.

## Who it's for

**Primary** — *classroom staff (lead teachers, teachers, assistants)*.
The people whose phones the app actually lives on. They open it dozens
of times a day; if it takes more than two taps to do the common thing
they will stop using it and we have failed.

**Secondary** — *program directors*. They don't open it as often, but
they live and die by the records that come out of it: licensing
attendance, ratios, incident reports, family communication logs. They
benefit because teachers are using it; they don't have to do data
entry themselves.

**Tertiary, later** — *families*. Daily reports, photos, pickup auth.
Not in v1. The data is generated as a side effect of teachers using
the app for themselves.

## Why it exists / what's wrong with existing tools

Existing players in this space — Brightwheel, Procare, HiMama,
Lillio, Kinderlime — are decent SaaS dashboards but built for
constant connectivity and admin-first workflows. They feel like
desktop tools squeezed onto a phone.

Specific frustrations we're solving:

- **Spotty wifi kills them.** Most classrooms aren't covered well.
  Teachers either lose data or give up.
- **Too many taps to do the common things.** Mark a kid present? Open
  the app, find the classroom, find the child, choose status, save. 5
  taps for one of 18 students = 90 taps for daily attendance. Ours
  has to be 2 taps in the steady state.
- **Designed for the office, not for one-handed phone use mid-room.**
  Forms have desktop ergonomics. Buttons are too small or in the
  wrong corner. We design for "kid on hip, phone in other hand."
- **PII handling is iffy.** Many of these tools send photos and
  observations to third-party servers without it being obvious. We
  default to private, photos go through signed Storage URLs, and the
  user knows what leaves their device.

## What it explicitly is NOT

- **Not a learning-management system.** Curriculum tracking exists in
  later phases but isn't the heart of the product.
- **Not a parent-communication platform first.** Family-facing
  features emerge from data teachers are already capturing for their
  own purposes, not the other way around.
- **Not a billing / HR / scheduling tool.** Just classroom life.
- **Not a video or audio recorder.** Photos only, for v1. We are not
  designing surveillance infrastructure for two-year-olds.
- **Not multi-program SaaS.** One program per install. We're trying
  to be the thing one program uses well, not the platform that bills
  10,000 programs.

## How it's different in shape

- **Offline-first, not "with offline support."** The local SQLite is
  the source of truth for the UI. Network is an optional
  reconciliation step.
- **Phone-first ergonomics.** Tap count, time-to-action, and
  one-handed reach budget the design.
- **Single-program install.** No tenant switching, no organization
  hierarchies in the UI. Adds up to a much simpler product surface.
- **Privacy by default.** Photos in private Supabase Storage with
  short-lived signed URLs. No analytics with child identifiers.
  Background screenshots hidden on iOS/Android.
- **One codebase, six targets.** iOS / Android / web / macOS /
  Windows / Linux. The team that writes code is small; we don't
  maintain separate apps.

## v1 — what we have to nail

The shape v1 has to take, in order of importance:

1. **"Today" home.** Glanceable status when a teacher opens the app:
   which classroom, how many kids marked / unmarked, the next thing
   that needs doing.
2. **Attendance in 90 seconds for a 20-kid room.** Mark-all-present
   default, single tap to flip individuals to absent / late / early
   pickup / excused. Optimistic local writes, no spinner.
3. **Roster** — add and edit kids, allergies, basic info.
4. **Observation capture.** Pick a child, type or paste a sentence,
   optionally attach a photo. Save. Two taps to start, one to save.
5. **Pickup log.** Who picked the child up, when. Catches late
   pickups without a separate "report."
6. **Family-facing daily report.** Read-only summary of the day per
   child. Family doesn't need to log in for v1 — they get a link or
   PDF.

If those six things work and feel right, we have a product.

## What's deferred (v2+)

These are real features we will need; they are NOT in v1:

- Voice dictation for observations (huge value, complex audio path)
- Face-aligned camera for check-in & student photos
- Curriculum units + day plans + weekly themes + state-standard
  alignment
- Field trips with chaperones + permission slips
- Incident reports (with signatures, parent notification)
- Medication administration log
- Meal / nap / diaper logs as first-class events
- Family login with messaging
- Two-way family communication
- Multi-program / org installations
- Compliance / state-reporting exports (state-specific formats)
- Billing or attendance-based invoicing
- Voice / audio recording of any kind
- Video
- AI assistant in an omnibox
- Multi-language UI

## Tone & voice

- **Warm**, not corporate. Words like "Today" and "Your class," not
  "Dashboard" and "Tenant."
- **Quiet**, not chatty. The app does not interrupt the teacher
  unless something requires their attention.
- **Concrete**, not abstract. "5 students unmarked" beats "incomplete
  status."
- **Respectful of time.** No animations longer than 200ms in the
  steady state. No multi-step modals when one step would do.

## Brand direction (loose, to be tightened)

- **Name**: "Different World" is the working title. Worth revisiting
  before the first public release. The phrase comes from how a
  classroom feels to a child — a small world of its own.
- **Color**: warm and calm, not corporate blue. A soft sage or coral
  tone, paired with high-contrast text. Avoid primary-color "kid"
  palettes; the *teachers* are the audience, not the kids.
- **Type**: system default, slightly larger than typical office apps
  for one-handed reading.
- **Iconography**: rounded, not sharp.

## Success — what "working" looks like

If we hit v1, in a 6-month pilot at one program (3–4 classrooms, 50
children, 10 staff):

- Teachers use it every day, without being asked to.
- Daily attendance takes < 90 seconds per classroom.
- The director's monthly licensing report takes 5 minutes instead of
  a day.
- At least one teacher captures > 5 observations per child per month
  without it feeling like extra work.
- Families say the daily reports are the most consistent
  communication they've ever had from a program.

If we don't hit those, the product isn't doing its job — even if all
the code is clean.
