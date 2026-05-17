# Different World — domain model

Every noun in our world has **properties** (data state) and **methods**
(what can be done with/to it). Each method has a tier — `v1`, `next`,
or `later` — that drives the roadmap. Each method also has an
**actor** column showing who's allowed to call it; that maps directly
to RLS policies and UI gating.

This document is the source-of-truth pivot point for:
- The data schema (properties → columns)
- The feature list (methods → UI affordances)
- The permission model (actor → RLS + role checks)
- The roadmap (tier → what we build next)

When a new feature is proposed, it lands as a method on a noun first.
If no noun owns it, the noun is missing.

---

## Status legend

- ✅ **v1** — has to ship in the first usable version
- 🔜 **next** — second slice; what we build after v1 is in someone's hands
- 🕓 **later** — important but deferred; on the roadmap, not the punch list

---

## 1. Program

The container for everything. One program per install.

### Properties
- `name`, `slug`
- `address`, `phone`, `tz` *(later)*
- `settings` (jsonb — pickup window, ratios, hours of operation) *(next)*
- *Derived:* `staff_count`, `classroom_count`, `enrolled_children`

### Methods
| Method | Actor | Tier |
|---|---|---|
| `create(name)` (during onboarding) | new user | ✅ |
| `editProfile(fields)` | director | 🔜 |
| `inviteStaff(email, role)` | director | 🔜 |
| `removeStaff(profile)` | director | 🕓 |
| `archive()` | director | 🕓 |
| `getCompliance()` (ratios, attendance %, incidents) | director | 🕓 |
| `export(period, format)` for state inspector | director | 🕓 |

---

## 2. Classroom

A room in a program. Has children, staff, and a daily rhythm.

### Properties
- `name`, `age_range`, `color`, `capacity`
- `program_id`
- *Derived:* `enrolled_count`, `staff_assigned_today`, `ratio_now`, `today_state`

### Methods
| Method | Actor | Tier |
|---|---|---|
| `create(name, age_range)` | director | ✅ |
| `editProfile(fields)` | director, lead teacher | ✅ |
| `archive()` | director | 🕓 |
| `enrollChild(child)` | director | ✅ |
| `unenrollChild(child)` | director | 🔜 |
| `assignStaff(profile, role)` | director | 🔜 |
| `removeStaff(profile)` | director | 🔜 |
| `getRosterFor(date)` | derived | ✅ |
| `getDayState(date)` | derived (used by Today screen) | ✅ |
| `getRatioAt(timestamp)` | derived | 🕓 |
| `createDayPlan(date, activities)` | lead teacher | 🕓 |

---

## 3. Staff (Profile)

A person on the team. Currently every Profile is a staff member;
family/guardians have their own noun (below).

### Properties
- `id` (= `auth.users.id`)
- `display_name`, `email`, `photo_url`
- `role`: `director` | `lead_teacher` | `teacher` | `assistant`
- `program_id`
- `phone`, `qualifications`, `notes` *(later)*
- *Derived:* `assigned_classrooms`, `is_clocked_in_now`

### Methods
| Method | Actor | Tier |
|---|---|---|
| `signIn()` (Google OAuth) | self | ✅ |
| `signOut()` | self | ✅ |
| `acceptInviteToProgram()` | self | 🔜 |
| `editOwnProfile()` (name, photo) | self | 🔜 |
| `changeRole(profile, new_role)` | director | 🔜 |
| `clockIn() / clockOut()` (shift tracking) | self | 🕓 |
| `removeFromProgram(profile)` | director | 🕓 |

---

## 4. Child

The unit everything else revolves around. A person enrolled in the
program.

### Properties
- `first_name`, `last_name`, `dob`, `photo_url`
- `classroom_id` (current room — children move rooms over time)
- `program_id`
- `allergies`, `dietary_notes`, `medical_conditions`, `iep_notes`
- `enrolled_at`, `withdrawn_at`
- `photo_permission` (bool — can their photo appear in family-facing reports)
- *Derived:* `age`, `current_classroom`, `today_state` (present/absent/etc., events of the day)

### Methods
| Method | Actor | Tier |
|---|---|---|
| `enroll(classroom, date)` | director | ✅ |
| `editProfile(fields)` | director, lead teacher | ✅ |
| `updatePhoto(file)` | director, lead teacher | 🔜 |
| `transfer(toClassroom, date)` | director | 🕓 |
| `withdraw(date, reason)` | director | 🕓 |
| `markAttendance(date, status)` | any classroom staff | ✅ |
| `pickedUpBy(guardian, time)` | any classroom staff | 🔜 |
| `recordObservation(text, photo?)` | any classroom staff | 🔜 |
| `recordMeal(type, amount, notes?)` | any classroom staff | 🕓 |
| `recordNap(start, end, quality?)` | any classroom staff | 🕓 |
| `recordDiaper(type, time, notes?)` | any classroom staff | 🕓 |
| `recordIncident(category, narrative, severity, photo?)` | any classroom staff | 🕓 |
| `recordMedication(drug, dose, time, administered_by)` | any classroom staff | 🕓 |
| `getDailyReport(date)` (derived from above) | any staff in program | 🔜 |
| `getPortfolio(period)` (derived from observations) | any staff in program | 🕓 |

---

## 5. Day (a date in a classroom)

Not a stored entity — an **aggregate view** the user thinks in. It's
how Maria thinks: "today, my room." The Today screen is just a UI
projection of this noun.

### Properties (all derived)
- `date`, `classroom_id`
- `students_present[]`, `students_absent[]`, `students_unmarked[]`
- `events[]` (every attendance + observation + meal + nap + diaper + pickup, chronological)
- `day_plan` (planned activities) *(later)*
- `open_items[]` — what still needs doing right now ("3 unmarked", "pickup window opening in 30 min")
- `staff_present[]`
- `ratio_at_now`

### Methods
| Method | Actor | Tier |
|---|---|---|
| `markAllPresent()` (bulk; skips already-recorded) | any classroom staff | ✅ |
| `summarizeForFamily(child)` (the family-facing report) | any classroom staff | 🔜 |
| `closeOut()` (end-of-day routine: confirm pickups, send reports) | any classroom staff | 🕓 |
| `getEvents()` | derived | 🔜 |

---

## 6. Observation

A narrative moment captured about a child. Centerpiece of long-term
developmental record-keeping.

### Properties
- `id`, `child_id`, `observer_id` (staff)
- `recorded_at` (timestamp), `observed_at` (when the moment happened — may differ)
- `text` (the narrative)
- `photo_url`, `photo_thumb_url` (optional)
- `domain` (social_emotional | motor_fine | motor_gross | language | cognitive | self_care) — for state-standard alignment later
- `linked_learning_goal_ids[]` *(later)*
- `is_family_visible` (bool — gated for v2 family login)
- `is_milestone` (bool — flag for portfolio highlights)

### Methods
| Method | Actor | Tier |
|---|---|---|
| `create(child, text, photo?, domain?)` | any classroom staff | 🔜 |
| `attachPhoto(file)` | observer | 🔜 |
| `edit(text)` | observer (within X hours), lead teacher | 🔜 |
| `delete()` | observer (within X hours) | 🔜 |
| `markMilestone()` | observer | 🕓 |
| `linkToGoal(goal_id)` | observer | 🕓 |
| `share(family)` | lead teacher | 🕓 |

---

## 7. Attendance record

Probably **NOT a noun the user thinks in** — it's the output of
`Child.markAttendance(date, status)`. We have a table for it
internally but it shouldn't get its own UI surface.

### Properties (internal)
- `id`, `child_id`, `classroom_id`, `program_id`
- `date`, `status` (present | absent | late | early_pickup | excused)
- `recorded_by`, `recorded_at`, `notes`

### Methods
All accessed via `Child.markAttendance` / `Day.markAllPresent`.

| Method | Actor | Tier |
|---|---|---|
| `getHistoryFor(child, period)` | any staff in program | 🕓 |
| `getMonthlyReport(classroom, month)` | director | 🕓 |
| `amend(record, new_status, reason)` (corrections with audit) | lead teacher | 🕓 |

---

## 8. Pickup

When a guardian picks up a child — the closing event of the day for
each child. Currently lives as a status flip on attendance but has
its own lifecycle.

### Properties
- `id`, `child_id`, `classroom_id`
- `scheduled_at` (from family/program settings)
- `picked_up_at` (timestamp)
- `picked_up_by` (guardian_id)
- `late_minutes` (derived from scheduled vs actual)
- `mood_at_pickup` *(later — optional)*
- `recorded_by` (staff)

### Methods
| Method | Actor | Tier |
|---|---|---|
| `record(guardian, time)` | any classroom staff | 🔜 |
| `markLate(reason?)` | derived; staff annotates | 🔜 |
| `getMonthlyLatePickupReport(classroom)` | director | 🕓 |

---

## 9. Family / Guardian

The people authorized to be in a child's life. Almost no methods in
v1 because family-facing features are deferred to v2+.

### Properties
- `id`, `name`, `relationship` (parent, grandparent, aunt, friend, etc.)
- `phone`, `email`
- `is_authorized_for_pickup` (bool)
- `photo_url` (for pickup verification later)
- `program_id`
- *Children linked via* `student_guardians` *(many-to-many)*

### Methods
| Method | Actor | Tier |
|---|---|---|
| `addToChild(child, relationship)` | director, lead teacher | 🔜 |
| `editProfile(fields)` | director, lead teacher | 🔜 |
| `linkPhotoForPickupVerification()` | director | 🕓 |
| `signInAsFamily()` *(v2 family login)* | self | 🕓 |
| `viewDailyReport(child, date)` *(v2 family-facing)* | self | 🕓 |
| `messageTeacher(child, text)` *(v2 family-facing)* | self | 🕓 |
| `acknowledgeIncidentReport(incident)` *(v2 family-facing)* | self | 🕓 |

---

## 10. (deferred) — Curriculum, Day Plan, Trip, Incident, Medication, Meal, Nap, Diaper

These are real nouns. Each one will get its own section in this
document when we get to them. For v1 / next we deliberately don't
model them as first-class nouns — the data we capture in
`Observation` covers ad-hoc narrative; the rest waits.

When we promote one of these to first-class:
- It gets a section here (properties + methods)
- Its methods get tier-assigned
- It joins the schema (migration), the PowerSync schema, the Drift
  tables, and the UI

---

## Cross-cutting: actors → roles → grants

| Actor mentioned in methods | Maps to DB role | Notes |
|---|---|---|
| `self` (the signed-in user) | `authenticated` + `auth.uid() = profile.id` | Most edit-own-profile methods |
| `any staff in program` | `authenticated` + `profile.program_id matches` | Reads of data within their program |
| `any classroom staff` | `authenticated` + member of the classroom's enrollments | Most daily-routine writes |
| `lead teacher` | role = `lead_teacher` OR `director` | Some elevated writes |
| `director` | role = `director` | Top-of-program admin |
| `family / self (v2)` | not yet implemented | Family login deferred |

(See migration 20260517000003 — current `to authenticated` policies
are temporarily permissive because of the
`auth.uid()`-returns-null issue. Tighten these to the matrix above
once that's resolved.)

---

## The v1 punch list, derived from this document

If you take all the ✅ methods, you get:

**Program**
- create

**Classroom**
- create, editProfile, enrollChild, getRosterFor, getDayState

**Staff**
- signIn, signOut

**Child**
- enroll, editProfile, markAttendance

**Day**
- markAllPresent

That's **10 methods**. Each one has a UI affordance. The shape of v1
is, quite literally, those 10 things working well.

🔜 **next** adds another ~10 around observations, pickups, family
reports, and roster polish.

🕓 **later** is everything else.

---

## How to use this document

When proposing a feature:

1. **Which noun owns it?** If none, the noun is missing — add it.
2. **What method does it become?** Name it.
3. **Who can call it?** Pick the actor.
4. **What tier is it?** ✅ / 🔜 / 🕓.
5. **What property does it write or read?** If a new column, add it
   under Properties.
6. **What's the UI affordance?** A button, a swipe, a form, a card.

If steps 1–5 are unclear, the feature isn't ready to design yet.

If steps 1–5 are clear and the tier is 🕓, write it here and move
on. Don't build it.

If the tier is ✅ or 🔜, this is what we're working on next.
