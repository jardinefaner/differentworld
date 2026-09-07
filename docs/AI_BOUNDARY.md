# The AI boundary — every feature, classified

> **AI backstage; children, teachers, objects, movement, and conversation
> frontstage.**
> — [VISION.md](VISION.md), "the one non-negotiable"

This doc applies that line to the actual product: what ships today, what
is proposed, and what is deferred. It exists because a principle nobody
has tested against real features is a slogan.

**How to read a verdict.** Three tests, in order:

1. **Who is the child looking at?** The app, or a person / an object /
   another child?
2. **Whose sentence is it?** A generated one spoken as the room's own, or
   a draft an adult reads, changes, and says themselves?
3. **What happens when it's wrong?** An adult deletes a bad suggestion —
   or a child is told something untrue by something they trust?

**Preserves** = backstage. **Violates** = frontstage, and out or changed.
**Watch** = backstage today, one product decision away from not being.

---

## Shipped

### Preserves

| Feature | Why it's backstage |
|---|---|
| **Voice dictation** — omnibox, observation form, captures | Speech-to-text for an ADULT writing a note. The model converts; the teacher's words stay the teacher's. No child hears it, and a mis-transcription is a typo an adult fixes. |
| **`nudge.dart`** — recompose the day from a plain sentence | Explicitly rules-based: *"no LLM, no chat reply."* The host says what happened; the app proposes a **structured change to confirm**. Test 2 passes by construction — nothing is said to the room. |
| **`compose_intent.dart`** — a typed phrase becomes a drafted block | Same shape. The output is a draft in an editor, never an answer. |
| **Content bank + curated libraries** | Authored once by people, replayed. The generation is offline and human-reviewed; the room receives content an adult chose. |
| **Math generation** | Arithmetic, not a model — "math is free + infinite, no AI needed" (VISION #7). Deterministic and checkable. |
| **`GeneratedPortrait`** | *Not AI.* Deterministic procedural art from a name-seed, like an identicon — same seed, same picture, offline. Defaults OFF, and its own doc says initials are the honest fallback. It is a placeholder that admits it is one. |
| **Signed-photo broker, sync, PowerSync** | Infrastructure. Nobody in the room knows it exists, which is the definition. |

### Violates

| Feature | The problem | What it should be |
|---|---|---|
| **`/speak`** — paste any text, a synthetic voice performs it to the room as editorial type | Built as a staff tool, but its whole design is a voice taking the stage. If it is ever pointed at children — and a big-type karaoke screen invites exactly that — it is a machine performing where a person should be. | Keep it as an **adult rehearsal tool** (hear your own script back), and never route curriculum or story content through it to a room. If reading aloud to children is wanted, that is the teacher's voice, recorded. |

### Fixed — survey read-aloud

Shipped as a violation and corrected 2026-09-07. The original reading
stands in one respect and was wrong in another, and both are worth
keeping on the record.

**Wrong about the setting.** Surveys are run **one child at a time, with
an adult sitting there.** That changes the failure mode the boundary is
actually about: an unsupervised voice telling a child something untrue is
unrecoverable, while a voice a teacher is listening to alongside them is
a supervised aid the adult corrects mid-sentence. Supervision is what
makes it defensible — so the answer is a toggle a program opts into, not
a deletion.

**Right about the default.** The voice was **compulsory**: a child could
not start a survey without first picking one, so a model was the price of
entry to a kid-facing screen. That is the line crossed by default rather
than by decision, and it is the part that needed fixing regardless of who
is in the room.

Now: off by default. Off, the voice cast and the volume slider are not on
the About-you page at all — a child is never asked which machine should
read to them — and playback is guarded so a response saved while it was
on stays silent. On, it behaves as before, and the settings row says what
it IS rather than what it does: *"A computer voice reads the questions.
For pre-readers, with an adult sitting with them."*

Still true, and still not built: the principle-correct answer for
pre-readers is a **person** — a teacher recording each question once,
replayed offline forever. The toggle makes the default honest. It does
not make the recording.

### Watch

| Feature | Why it's near the line |
|---|---|
| **TTS caching in the `tts-cache` bucket** | Fine as infrastructure. It becomes a violation the moment cached synthetic audio is played *to a room* rather than back to the adult who requested it. |
| **Omnibox capture mode** | Today it files a note. If it ever answers a question instead of filing one, the composer has become a chat box and the line has moved. |

---

## Proposed — the dreams in VISION.md

| # | Dream | Verdict | Reasoning |
|---|---|---|---|
| 1 | Every child becomes their own book | **Preserves** | Compiled from what children actually made and adults actually saw. The machine arranges; nothing is invented. |
| 2 | "This is you, and these are your tools" | **Preserves** | An identity a person chooses, rendered. No inference about who somebody is. |
| 3 | Reason to execute — imagination | **Preserves** | The point is the child making something. Any generator here feeds an adult a prompt to offer, not a room a performance. |
| 4 | No typing, no right/wrong, teacher-paced | **Preserves** | Literally the principle restated as an interaction rule — the teacher paces, so the app never does. |
| 5 | Teachers make their own rules | **Preserves** | Adults authoring. Backstage may suggest; adults decide. |
| 6 | Group discussions by topic and age | **Preserves** | Curated questions read by a teacher to a room. The conversation is between people. |
| 7 | Content libraries — brokered refill | **Watch** | The brokered half is a model writing content children will meet. Backstage **only if** a human reviews before it reaches a room; a live refill that lands unreviewed is frontstage by the back door. |
| 8 | Role decks beyond animals | **Preserves** | Authored decks. Generation is an authoring aid. |
| 9 | Action Words of the Day | **Preserves** | A child picks from a human-made list. |
| 10 | Breathable, one visual language | **Preserves** | Design. |
| 11 | Always an exit | **Preserves** | Supports the line: a child can always leave the screen. |
| 12 | Minimal data, on device | **Preserves** | Strengthens it — the less that leaves, the less a model can be fed. |
| 13 | One engine, many worlds | **Preserves** | Structural. |
| 14–18 | Live sessions · supplies · missions · one game language · the classroom remote | **Preserves** | Every one of these puts an **object, a room, or a person** on the stage and keeps the phone as the remote. This family is the principle working as designed. |

## Deferred, from CLAUDE.md

| Item | Verdict | Reasoning |
|---|---|---|
| **Showcase / growth-arc compilation** | **Watch** | Assembling a child's real artifacts is backstage. It crosses the line if it *narrates* — a synthetic voice-over telling a family who their child is becoming is the machine speaking about a person, and no family should receive that. Music and montage from their own material: fine. A generated narrator: out. |
| **Kid journal** | **Watch** | Backstage while the child writes and the app only stores. Frontstage the moment anything replies to them. |
| **Family lens / recaps** | **Preserves** | Staff-written text, scrubbed and sent. A person wrote every word. |
| **Push notifications** | **Preserves** | Plumbing. |
| **Spot the Difference, the classics, the shape protocol** | **Preserves** | Objects and rules. No model anywhere near them. |

---

## The rule for new work

Before building anything with a model in it, answer test 1 in one
sentence: **who is the child looking at?** If the honest answer is the
app, the feature does not get built — a better version of it does, in
which a person, an object, or another child is what the room is facing.

Two consequences worth stating plainly, because they cost something:

- **A synthetic voice is never the accessibility answer for pre-readers.**
  Recording a teacher once is more work and it is the correct work.
- **"An adult reviews it" is the whole boundary**, not a formality. A
  review step that gets skipped under load has not made a feature
  backstage; it has made it frontstage with a delay.
