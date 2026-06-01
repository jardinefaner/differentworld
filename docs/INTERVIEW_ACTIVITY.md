# Interview activity — learn what to ask, then ask

**Status:** design (2026-05-31). **Blocked on one decision:** the video
player dependency (§5). Design-first because that dep is a real platform +
privacy surface — not a quick build like This-or-That.
**Origin:** "an interview activity, where you see YouTube videos of people
interviewing people — this will be the tool to know what to ask."

**The one principle:** **watching great interviews teaches what makes a
great question.** The clips aren't entertainment — they're the *model*. The
kid watches how a good interviewer listens and follows up, builds their own
questions, interviews a partner, and shares the conversation.

---

## 1. The loop

```
watch (learn how to ask) → build your questions → interview a partner → share the Q&A
```

- **Watch** — a short, **curated** interview clip. A "notice this" prompt
  rides alongside ("How did they get the person to say more?").
- **Build** — the kid assembles questions: pick/remix from a **question
  bank** (by topic) + write their own. Teaches open vs closed, follow-ups.
- **Interview** — pair up; one asks, one answers. Capture the answers —
  typed, **voice** (Deepgram, already wired), or a photo of the
  interviewee.
- **Share** — the Q&A becomes a **submission** (SUBMISSIONS.md): questions
  + answers + an optional portrait, tied to `(activity, block, subject)`.
  Teacher + family see it with the same contextual viewer.

---

## 2. Content (from the bank + a curated clip list)

- **Question prompts** — `kind='interview_q'`, payload `{topic, question}`
  ("about a hobby: What got you started?"). Generated/curated **once**,
  banked, crowd-grown by the kids' own good questions (CONTENT_BANK.md).
- **Clips** — a **curated, vetted list** of video IDs + the "notice"
  prompt. NOT open YouTube search, NOT recommendations — a fixed set the
  program approves. This is a curriculum asset, not AI-generated.

---

## 3. Capture reuses what exists

The interview *is* a submission. No new capture machinery:
- Answers: text / Deepgram voice-to-text / a photo — same paths as the
  observation form + photography.
- Stored as an `entries(kind='interview')` + `attachments` (the portrait,
  any audio) — the SUBMISSIONS model. Teacher aggregate + family timeline +
  export come for free.

---

## 4. Rules (kid-safety + privacy, non-negotiable)

- **Curated clips only.** A fixed approved list of IDs. No search, no
  autoplay-next, no recommendation rail — those are the rabbit holes.
- **Privacy-enhanced embed.** Use the no-cookie host and disable related
  videos; the player shows ONE clip and stops. Embedding YouTube is an
  external-service call — document it (it's the first third-party media
  surface in the app) and gate analytics/related off.
- **Kid-mode locked** like every conducted activity (the KidModeLock
  mixin): full screen, staff exit only.
- **No PII to the video host.** Don't pass child identifiers; the embed
  carries only the clip ID.
- **Pairing is teacher-orchestrated** (who interviews whom) — not a kid
  free-for-all; avoids the "no one picked me" problem.

---

## 5. The decision that blocks the build: the video player

Flutter has no first-party YouTube embed. Options:

| Option | Pros | Cons |
|---|---|---|
| **`youtube_player_iframe`** (recommended) | Maintained; iframe under the hood; supports the no-cookie/privacy host + `enableCaption`, no-related flags; web + mobile | New dep; pulls `webview_flutter` transitively; a platform surface to audit (Platform Guard) |
| `webview_flutter` + a hand-built privacy-embed URL | Minimal, full control of the embed params | We hand-roll player controls + lifecycle; more code |
| Bundle/download clips (no YouTube) | Zero third-party, fully private | Licensing + storage; not "YouTube videos" as asked |

**Recommendation:** `youtube_player_iframe` with the privacy host + related
off, behind a thin `InterviewClipPlayer` wrapper so the dep is swappable.
Needs: pubspec add, iOS/Android webview config check (Platform Guard), and
a curated clip list from you.

---

## 6. The rubric

- ☐ Only the curated clip plays; no related videos / autoplay-next / search.
- ☐ The embed carries no child identifier; analytics/related disabled.
- ☐ Questions come from the bank + the kid's own; their good ones can grow
  the bank.
- ☐ The interview saves as a submission (Q&A + optional portrait/audio),
  visible in the teacher aggregate + family timeline.
- ☐ Kid-mode locked; staff exit only.
- ☐ Pairing is set by staff.

---

## 7. Build seed (once the dep is chosen)

**Slice A — watch + build (no recording).** The curated clip player +
the "notice" prompt + the question-builder (bank + write-your-own). Proves
the "learn what to ask" half without the pairing/recording complexity.

**Slice B — interview + share.** Capture answers (text/voice/photo), save
the Q&A as a submission, surface in the teacher/family views.

**Slice C — pairing.** Staff assigns interviewer↔interviewee; the runner
hands each kid their role.

This is the marquee activity and the biggest — its own multi-slice arc,
gated on §5. The other activities (This-or-That, the word game, math,
photography) need none of this and shipped first by design.
