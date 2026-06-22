// Through My Eyes — Session 6 · "The Gallery Show" (the finale) — the FULL
// beat sequence behind the `photo.s6.gallery-show` summary in
// photo_curriculum.dart. This is the host-facing presenter content: every
// beat the staffer walks through, with "every word to say" kept VERBATIM
// from the source script.
//
// Encoding note: each timed section is one [SessionBeat]. Session 6 is the
// exhibition, not a shooting session — there are NO camera turns anywhere,
// so NO beat carries a [BeatGame]. "The Show" uses [BeatKind.game] for arc
// placement (it's the centerpiece) but is the exhibition itself, not a
// photo-turns game. Two closing-kind beats — "The Ceremony" and "The
// Closing Circle" — is intentional (the finale earns both). Say-lines are
// reproduced exactly; do not paraphrase them in code.

import 'package:differentworld/features/curricula/session_script.dart';

const photoSession6Script = SessionScript(
  slug: 'photo.s6.gallery-show',
  sessionNumber: 6,
  title: 'The Gallery Show',
  beats: [
    // ── Before they arrive (the big one) ─────────────────────────────
    SessionBeat(
      time: 'prep',
      kind: BeatKind.prep,
      title: 'Before they arrive · the big one',
      keyLines: [
        "Before they arrive, turn the room into a gallery. Each kid's three best, mounted on colored paper, on the wall.",
        'Under each: a little placard — the title, the kid\'s name, and one or two of the wall-words that fit that photo ("a CANDID," "WORM\'S EYE," "a SILHOUETTE"). Handwritten is perfect.',
        'The room should look important today. It should not look like a classroom.',
      ],
      script: [
        ScriptLine.cue(
          "Before they arrive, turn the room into a gallery. Each kid's three "
          'best, mounted on colored paper, on the wall.',
        ),
        ScriptLine.cue(
          "Under each: a little placard — the title, the kid's name, and one "
          'or two of the wall-words that fit that photo ("a CANDID," "WORM\'S '
          'EYE," "a SILHOUETTE"). Handwritten is perfect.',
        ),
        ScriptLine.cue(
          "The fifteen vocabulary words stay up, like the museum's glossary.",
        ),
        ScriptLine.note(
          'The room should look important today. It should not look like a '
          'classroom.',
        ),
      ],
    ),

    // ── 0:00–0:04 — The Opening (just the kids, before families) ─────
    SessionBeat(
      time: '0:00–0:04',
      kind: BeatKind.hook,
      title: 'The Opening · just the kids, before families',
      startMinute: 0,
      durationMinutes: 4,
      keyLines: [
        'Look at this wall. Look what you made. Two weeks ago, none of you had ever looked through a camera on purpose.',
        "Now there's an EXHIBITION on this wall — with titles, and placards, and museum words. And every single word up there, you EARNED. From your own photos.",
        'Today you are not students. Today you are the ARTISTS. The people who love you are coming to see YOUR work.',
      ],
      script: [
        ScriptLine.cue(
          'Gather them in front of the wall. Let them find their own photos.',
        ),
        ScriptLine.say(
          'Look at this wall. Look what you made. Two weeks ago, none of you '
          "had ever looked through a camera on purpose. Now there's an "
          'EXHIBITION on this wall — with titles, and placards, and museum '
          'words. And every single word up there, you EARNED. From your own '
          'photos.',
        ),
        ScriptLine.cue('Pause.'),
        ScriptLine.say(
          'Today you are not students. Today you are the ARTISTS. The people '
          "who love you are coming to see YOUR work. And here's the only thing "
          'you have to do.',
        ),
      ],
    ),

    // ── 0:04–0:09 — The Rehearsal ────────────────────────────────────
    SessionBeat(
      time: '0:04–0:09',
      kind: BeatKind.rules,
      title: 'The Rehearsal',
      startMinute: 4,
      durationMinutes: 5,
      keyLines: [
        'When someone walks up to your photos, you say five words. Watch me.',
        "'This is my photo. It's called…' and then the title. That's it. That's all you have to say.",
        "If you're shy, you don't have to. Your photos do the talking. They're already on the wall. They're already perfect.",
      ],
      script: [
        ScriptLine.say(
          'When someone walks up to your photos, you say five words. Watch me.',
        ),
        ScriptLine.cue('Stand by a photo.'),
        ScriptLine.say(
          "'This is my photo. It's called…' and then the title. That's it. "
          "That's all you have to say.",
        ),
        ScriptLine.say(
          "Let's practice. Stand by your three. When I walk up… go.",
        ),
        ScriptLine.cue('Walk to each kid; let them try it.'),
        ScriptLine.say("This is my photo. It's called Where I Stand."),
        ScriptLine.say(
          'Perfect. If you want to say MORE — what it is, what word it is — you '
          "can. If you're shy, you don't have to. Your photos do the talking. "
          "They're already on the wall. They're already perfect.",
        ),
      ],
    ),

    // ── 0:09–0:40 — The Show (the exhibition) ────────────────────────
    SessionBeat(
      time: '0:09–0:40',
      kind: BeatKind.game,
      title: 'The Show',
      startMinute: 9,
      durationMinutes: 31,
      keyLines: [
        'Each kid stands near their three photos. Step back. Let it happen. Your only job now is to witness it.',
        'Watch for THE MOMENT — it always comes: A parent crouches down to their kid\'s photo, reads the placard, and says, "You took this?" And the kid says, "Yeah. It\'s a candid."',
        'When you see a family lingering, lean in quietly: "Ask them what \'silhouette\' means. They\'ll tell you."',
      ],
      script: [
        ScriptLine.cue(
          'Cast the gallery to the room screen too, if families are remote.',
        ),
        ScriptLine.cue(
          "Families (or other classes, or staff — anyone who'll come) arrive. "
          'Each kid stands near their three photos.',
        ),
        ScriptLine.cue(
          'Step back. Let it happen. Your only job now is to witness it.',
        ),
        ScriptLine.note(
          'Watch for THE MOMENT — it always comes: A parent crouches down to '
          'their kid\'s photo, reads the placard, and says, "You took this?" '
          'And the kid says, "Yeah. It\'s a candid." And the parent has no idea '
          'what that word means — but the kid does. The kid earned it.',
        ),
        ScriptLine.cue('When you see a family lingering, lean in quietly:'),
        ScriptLine.say("Ask them what 'silhouette' means. They'll tell you."),
      ],
    ),

    // ── 0:40–0:50 — The Ceremony ─────────────────────────────────────
    SessionBeat(
      time: '0:40–0:50',
      kind: BeatKind.closing,
      title: 'The Ceremony',
      startMinute: 40,
      durationMinutes: 10,
      keyLines: [
        'Two weeks. Six sessions. Six games. Ten photographers.',
        "Every one of these kids has a certificate today. And it's not a school certificate.",
        "Their words are their fingerprint — Maya's says one thing, Dev's says another, because they each saw the world their own way.",
      ],
      script: [
        ScriptLine.cue(
          'Gather everyone — kids and families — in front of the wall.',
        ),
        ScriptLine.say(
          'Two weeks. Six sessions. Six games. Ten photographers.',
        ),
        ScriptLine.cue('Hold up the first certificate.'),
        ScriptLine.say(
          "Every one of these kids has a certificate today. And it's not a "
          'school certificate. Listen.',
        ),
        ScriptLine.cue('Read one:'),
        ScriptLine.say(
          "'[Name] — Photographer. You have a photographer's eye. You know what "
          "CANDID, WORM'S EYE, and GLOW mean — because you DISCOVERED them, in "
          "your own photos. Keep looking. Keep clicking.'",
        ),
        ScriptLine.say(
          "Their words are their fingerprint — Maya's says one thing, Dev's "
          'says another, because they each saw the world their own way.',
        ),
        ScriptLine.cue(
          'Give each kid their certificate and their three printed photos to '
          'take home. Clap for each name.',
        ),
      ],
    ),

    // ── 0:50–0:54 — The Wall Is Full ─────────────────────────────────
    SessionBeat(
      time: '0:50–0:54',
      kind: BeatKind.vocab,
      title: 'The Wall Is Full',
      startMinute: 50,
      durationMinutes: 4,
      vocabCards: ['Exhibition', 'Body of work', 'Photographer’s eye'],
      keyLines: [
        "Three spaces left on our wall. The last three words — and these aren't about light or angles. These are about what you BECAME.",
        "EXHIBITION — a show of your work, on a wall, for people to see. BODY OF WORK — all the photos a photographer makes, together. PHOTOGRAPHER'S EYE — the way YOU see that nobody else does.",
        'Eighteen words. The wall is full. And every single one, you earned.',
      ],
      script: [
        ScriptLine.say(
          'Three spaces left on our wall. The last three words — and these '
          "aren't about light or angles. These are about what you BECAME.",
        ),
        ScriptLine.note('[EXHIBITION]'),
        ScriptLine.say(
          'A show of your work, on a wall, for people to see. You had one '
          "today. That's an exhibition.",
        ),
        ScriptLine.response('EXHIBITION.'),
        ScriptLine.note('[BODY OF WORK]'),
        ScriptLine.say(
          'All the photos a photographer makes, together. Two weeks of yours. '
          "That's a body of work.",
        ),
        ScriptLine.response('BODY OF WORK.'),
        ScriptLine.note("[PHOTOGRAPHER'S EYE]"),
        ScriptLine.say(
          "The way YOU see that nobody else does. You've had it the whole "
          'time. Now you know its name.',
        ),
        ScriptLine.response("PHOTOGRAPHER'S EYE."),
        ScriptLine.say(
          'Eighteen words. The wall is full. And every single one, you earned.',
        ),
      ],
    ),

    // ── 0:54–0:58 — The Closing Circle ───────────────────────────────
    SessionBeat(
      time: '0:54–0:58',
      kind: BeatKind.closing,
      title: 'The Closing Circle',
      startMinute: 54,
      durationMinutes: 4,
      callResponse: 'PHOTOGRAPHERS → FOREVER',
      keyLines: [
        "I am not going to tell you that you're learning photography. I'm not going to say someday you'll be a photographer.",
        'You ARE a photographer. Right now. Today. These photos on this wall are the proof. Nobody can ever take that away from you.',
        'What are you? — PHOTOGRAPHERS. Forever? — FOREVER. Go see the world, photographers.',
      ],
      script: [
        ScriptLine.say('Cameras in your hands one last time. Circle.'),
        ScriptLine.say(
          "Here's the last thing, and it's the most important. I am not going "
          "to tell you that you're learning photography. I'm not going to say "
          "someday you'll be a photographer.",
        ),
        ScriptLine.cue('Pause.'),
        ScriptLine.say(
          'You ARE a photographer. Right now. Today. These photos on this wall '
          'are the proof. Nobody can ever take that away from you.',
        ),
        ScriptLine.say(
          "You don't need this tube. You never did — remember? The camera was "
          'always in your EYE. So wherever you go, for the rest of your life — '
          'make the frame with your hands, and SEE.',
        ),
        ScriptLine.say('What are you?'),
        ScriptLine.response('PHOTOGRAPHERS.'),
        ScriptLine.say('Forever?'),
        ScriptLine.response('FOREVER.'),
        ScriptLine.say('Go see the world, photographers.'),
      ],
    ),

    // ── As they leave (doorway) ──────────────────────────────────────
    SessionBeat(
      time: '0:58–1:00',
      kind: BeatKind.doorway,
      title: 'As they leave',
      startMinute: 58,
      durationMinutes: 2,
      keyLines: [
        'At the door, each kid, their photos in their hands: "Goodbye, photographer. Keep clicking."',
      ],
      script: [
        ScriptLine.cue('At the door, each kid, their photos in their hands:'),
        ScriptLine.say('Goodbye, photographer. Keep clicking.'),
      ],
    ),

    // ── After they leave ─────────────────────────────────────────────
    SessionBeat(
      time: 'after',
      kind: BeatKind.after,
      title: 'After they leave',
      keyLines: [
        "The wall is full. Eighteen words, ten artists, thirty photos that didn't exist three weeks ago.",
        'Take a photo of the wall — your body of work as the teacher.',
        "Same room as Session 1. But you'll never see it the same way again. Neither will they. That's the whole thing. That's Through My Eyes.",
      ],
      script: [
        ScriptLine.note(
          'The wall is full. Eighteen words, ten artists, thirty photos that '
          "didn't exist three weeks ago.",
        ),
        ScriptLine.cue(
          'Take a photo of the wall — your body of work as the teacher.',
        ),
        ScriptLine.cue(
          "Then look at the room: same room as Session 1. But you'll never see "
          'it the same way again. Neither will they.',
        ),
        ScriptLine.note("That's the whole thing. That's Through My Eyes."),
      ],
    ),
  ],
);
