// Through My Eyes — Session 3 · "The Upside Down Game" — the FULL beat
// sequence behind the `photo.s3.upside-down` summary in
// photo_curriculum.dart. This is the host-facing presenter content: every
// beat the staffer walks through, with "every word to say" kept VERBATIM
// from the source script.
//
// Encoding note: each timed section is one [SessionBeat]. "Five Worlds" is
// the single shooting beat (the per-child photo turns) and carries a
// [BeatGame]; "The Twist" is a quick standing imagination game with NO
// camera turns, so it leaves [SessionBeat.game] null. Say-lines are
// reproduced exactly; do not paraphrase them in code.

import 'package:differentworld/features/curricula/session_script.dart';

const photoSession3Script = SessionScript(
  slug: 'photo.s3.upside-down',
  sessionNumber: 3,
  title: 'The Upside Down Game',
  beats: [
    // ── Before they arrive (5 min prep) ──────────────────────────────
    SessionBeat(
      time: 'prep',
      kind: BeatKind.prep,
      title: 'Before they arrive',
      durationMinutes: 5,
      keyLines: [
        'Tubes on the table.',
        'The wall has six words now (Composition · Close-up · Subject · Frame · Shadow · Pop).',
        "Pull one chair into the open — the star of today's demo.",
      ],
      script: [
        ScriptLine.cue('Tubes on the table.'),
        ScriptLine.cue(
          'The wall has six words now (Composition · Close-up · Subject · '
          'Frame · Shadow · Pop).',
        ),
        ScriptLine.cue(
          "Pull one chair into the open — the star of today's demo.",
        ),
        ScriptLine.cue('Journals, crayons.'),
        ScriptLine.note(
          '(Optional: a step-stool for safe high angles; a cup or your '
          'fingers to "shoot through.")',
        ),
      ],
    ),

    // ── 0:00–0:03 — The Hook: callback + the demo ────────────────────
    SessionBeat(
      time: '0:00–0:03',
      kind: BeatKind.hook,
      title: 'The Hook · callback + the demo',
      startMinute: 0,
      durationMinutes: 3,
      keyLines: [
        'Photographers. Six words on that wall. You learned to see, then you learned to hunt. Today you learn to move.',
        "Whoa. From down here it's a GIANT. It looks like a throne.",
        "SAME CHAIR. Three different worlds. The chair didn't move. I moved. Today, you move.",
      ],
      script: [
        ScriptLine.say(
          'Photographers. Six words on that wall. You learned to see, then '
          'you learned to hunt. Today you learn to move.',
        ),
        ScriptLine.say('Watch this chair.'),
        ScriptLine.cue('Hold the tube, look at the chair standing normally.'),
        ScriptLine.say('Boring chair. We see it like this every day.'),
        ScriptLine.cue('Drop to the floor, point the tube UP at it.'),
        ScriptLine.say(
          "Whoa. From down here it's a GIANT. It looks like a throne.",
        ),
        ScriptLine.cue('Stand on the stool, point DOWN.'),
        ScriptLine.say(
          "From up here it's flat — it looks like a drawing of a chair.",
        ),
        ScriptLine.say(
          "SAME CHAIR. Three different worlds. The chair didn't move. I "
          'moved. Today, you move.',
        ),
      ],
    ),

    // ── 0:03–0:06 — The Mission: become the camera that moves ────────
    SessionBeat(
      time: '0:03–0:06',
      kind: BeatKind.reveal,
      title: 'The Mission · become the camera that moves',
      startMinute: 3,
      durationMinutes: 3,
      keyLines: [
        'A lazy photographer takes every photo from right here.',
        'A real photographer gets on the floor. Climbs up high. Looks through things. Tips the camera sideways.',
        'Today you pick ONE thing — and you find FIVE different worlds inside it. Just by moving your body.',
      ],
      script: [
        ScriptLine.say(
          'A lazy photographer takes every photo from right here.',
        ),
        ScriptLine.cue('Stand straight, eyes forward.'),
        ScriptLine.say(
          'Standing up, looking straight ahead. Boring. The whole world has '
          'already seen everything from there.',
        ),
        ScriptLine.say(
          'A real photographer gets on the floor. Climbs up high. Looks '
          'through things. Tips the camera sideways. The crazier the spot you '
          'shoot from, the more the everyday thing turns into something '
          "nobody's ever seen.",
        ),
        ScriptLine.say(
          'Today you pick ONE thing — and you find FIVE different worlds '
          'inside it. Just by moving your body.',
        ),
      ],
    ),

    // ── 0:06–0:20 — Game: Five Worlds (14 min) ───────────────────────
    SessionBeat(
      time: '0:06–0:20',
      kind: BeatKind.game,
      title: 'Game · Five Worlds',
      startMinute: 6,
      durationMinutes: 14,
      keyLines: [
        'Pick one thing. A shoe, a backpack, a plant, anything. Now five photos of that SAME thing:',
        'Same thing. Five worlds. Crazier the angle, the better. Cameras up… GO.',
        "Maya's on the floor under the table looking up at a chair — it's a SPIDER from down there!",
      ],
      game: BeatGame(
        name: 'Five Worlds',
        minutes: 14,
        prompt:
            "One thing, five angles — worm's-eye up, bird's-eye down, super "
            'close, far, and through something',
        rules: [
          "One — lie on the floor and look UP at it, a bug's view.",
          "Two — get up high and look DOWN, a bird's view.",
          'Three — get so close your tube almost touches it.',
          'Four — back way up, far away.',
          'Five — look at it THROUGH something: a cup, your fingers, a window.',
        ],
      ),
      script: [
        ScriptLine.say(
          'Pick one thing. A shoe, a backpack, a plant, anything. Now five '
          'photos of that SAME thing:',
        ),
        ScriptLine.cue('Count on fingers:'),
        ScriptLine.say(
          "One — lie on the floor and look UP at it, a bug's view. Two — get "
          "up high and look DOWN, a bird's view. Three — get so close your "
          'tube almost touches it. Four — back way up, far away. Five — look '
          'at it THROUGH something: a cup, your fingers, a window. Same '
          'thing. Five worlds. Crazier the angle, the better. Cameras up… GO.',
        ),
        ScriptLine.cue('Walk it, announce it:'),
        ScriptLine.say(
          "Maya's on the floor under the table looking up at a chair — it's a "
          'SPIDER from down there!',
        ),
        ScriptLine.say(
          'Theo backed all the way to the wall — his shoe is tiny now, a '
          'little island in a big floor.',
        ),
        ScriptLine.say(
          "Aria's shooting her crayon THROUGH a cup — it's all wobbly and "
          'magic.',
        ),
      ],
    ),

    // ── 0:20–0:26 — Looking Together: same thing, five worlds ────────
    SessionBeat(
      time: '0:20–0:26',
      kind: BeatKind.cooldown,
      title: 'Looking Together · same thing, five worlds',
      startMinute: 20,
      durationMinutes: 6,
      keyLines: [
        "Sit. Let's look at one person's five.",
        "That's a WORM'S EYE view. Low and looking up makes small things mighty. You turned a shoe into a mountain.",
        "Same object. You didn't change the thing — you changed where your EYES were. That's the whole secret of today.",
      ],
      script: [
        ScriptLine.say("Sit. Let's look at one person's five."),
        ScriptLine.cue('Pick a kid; walk through their five angles.'),
        ScriptLine.note("The worm's-eye one:"),
        ScriptLine.say(
          'Look — from the floor, looking UP, the thing looks HUGE and '
          "powerful. That's a WORM'S EYE view. Low and looking up makes small "
          'things mighty. You turned a shoe into a mountain.',
        ),
        ScriptLine.note("The bird's-eye one:"),
        ScriptLine.say(
          "Now from above, looking straight DOWN — it's flat, it looks like a "
          "map. That's a BIRD'S EYE view. Everything looks different from "
          'above.',
        ),
        ScriptLine.say(
          "Same object. You didn't change the thing — you changed where your "
          "EYES were. That's the whole secret of today.",
        ),
      ],
    ),

    // ── 0:26–0:30 — The Twist: make the tiny giant ───────────────────
    SessionBeat(
      time: '0:26–0:30',
      kind: BeatKind.frame,
      title: 'The Twist · make the tiny giant',
      startMinute: 26,
      durationMinutes: 4,
      keyLines: [
        'One more. Cameras up. Find the SMALLEST thing in this room… and make it look like a GIANT.',
        'Get LOW. Get CLOSE. Look UP.',
        "A crumb becomes a boulder. A staple becomes a bridge. You're not lying — that's really what it looks like from an ant's life.",
      ],
      script: [
        ScriptLine.say(
          'One more. Cameras up. Find the SMALLEST thing in this room… and '
          'make it look like a GIANT.',
        ),
        ScriptLine.cue('They drop to the floor, get under it, point up.'),
        ScriptLine.say('Get LOW. Get CLOSE. Look UP.'),
        ScriptLine.say(
          "A crumb becomes a boulder. A staple becomes a bridge. You're not "
          "lying — that's really what it looks like from an ant's life. You "
          "just visited a world that's been here the whole time, too small "
          'for grown-ups to bother with.',
        ),
      ],
    ),

    // ── 0:30–0:39 — Drawing: My Best Three Worlds (9 min) ────────────
    SessionBeat(
      time: '0:30–0:39',
      kind: BeatKind.drawing,
      title: 'Drawing · My Best Three Worlds',
      startMinute: 30,
      durationMinutes: 9,
      keyLines: [
        'Journals. Three frames. Draw your three most SURPRISING angles — the ones that made it stop looking like itself.',
        "Looking up? Then the thing is at the TOP of your frame and it leans over you. Looking down? It's flat in the middle. Draw what the ANGLE did.",
        "Title: 'My Shoe From an Ant's Life.'",
      ],
      script: [
        ScriptLine.say(
          'Journals. Three frames. Draw your three most SURPRISING angles — '
          'the ones that made it stop looking like itself.',
        ),
        ScriptLine.note('Coach:'),
        ScriptLine.say(
          'Looking up? Then the thing is at the TOP of your frame and it '
          "leans over you. Looking down? It's flat in the middle. Draw what "
          'the ANGLE did.',
        ),
        ScriptLine.note('Caption:'),
        ScriptLine.say('What was it, really?'),
        ScriptLine.response('My shoe.'),
        ScriptLine.say('And from where?'),
        ScriptLine.response('The floor.'),
        ScriptLine.say("Title: 'My Shoe From an Ant's Life.'"),
      ],
    ),

    // ── 0:39–0:44 — The Vocabulary Wall (grows to nine) ──────────────
    SessionBeat(
      time: '0:39–0:44',
      kind: BeatKind.vocab,
      title: 'The Vocabulary Wall · grows to nine',
      startMinute: 39,
      durationMinutes: 5,
      vocabCards: ["Worm's eye", "Bird's eye", 'Angle'],
      keyLines: [
        'Read me the six.',
        'You earned three more today — because you DID them with your body.',
        "Nine words. The wall's filling up. Halfway there.",
      ],
      script: [
        ScriptLine.say('Read me the six.'),
        ScriptLine.cue('They do.'),
        ScriptLine.say(
          'You earned three more today — because you DID them with your body.',
        ),
        ScriptLine.note("[WORM'S EYE]"),
        ScriptLine.say(
          'Down low, looking up. Makes small things giant and powerful.',
        ),
        ScriptLine.response("WORM'S EYE."),
        ScriptLine.note("[BIRD'S EYE]"),
        ScriptLine.say(
          'Up high, looking straight down. Everything goes flat, like a map.',
        ),
        ScriptLine.response("BIRD'S EYE."),
        ScriptLine.note('[ANGLE]'),
        ScriptLine.say(
          'The spot you shoot FROM. Change your angle, change the whole photo '
          'without touching the thing.',
        ),
        ScriptLine.response('ANGLE.'),
        ScriptLine.say(
          "Nine words. The wall's filling up. Halfway there.",
        ),
      ],
    ),

    // ── 0:44–0:48 — The Closing Circle ───────────────────────────────
    SessionBeat(
      time: '0:44–0:48',
      kind: BeatKind.closing,
      title: 'The Closing Circle',
      startMinute: 44,
      durationMinutes: 4,
      callResponse: 'PHOTOGRAPHERS → SEE',
      keyLines: [
        "Here's the big secret of today, and it's the secret of this whole place. The world didn't change. The chair didn't move. The shoe is the same shoe. YOU moved. YOU changed. And the whole world turned into something new.",
        "That's what 'a different world' means. It's not somewhere else. It's right here — seen from somewhere new.",
        'What are you? — PHOTOGRAPHERS. And what do photographers do? — SEE.',
      ],
      script: [
        ScriptLine.say('Cameras down. Circle.'),
        ScriptLine.say(
          "Here's the big secret of today, and it's the secret of this whole "
          "place. The world didn't change. The chair didn't move. The shoe is "
          'the same shoe. YOU moved. YOU changed. And the whole world turned '
          'into something new.',
        ),
        ScriptLine.say(
          "That's what 'a different world' means. It's not somewhere else. "
          "It's right here — seen from somewhere new.",
        ),
        ScriptLine.say(
          'Homework: tomorrow, look at one boring everyday thing — your '
          'breakfast, your front door — from the floor, or from up high. '
          'Watch it turn into a different world.',
        ),
        ScriptLine.say('What are you?'),
        ScriptLine.response('PHOTOGRAPHERS.'),
        ScriptLine.say('And what do photographers do?'),
        ScriptLine.response('SEE.'),
        ScriptLine.say('From everywhere. Go, photographers.'),
      ],
    ),

    // ── 0:48–0:50 — As they leave ────────────────────────────────────
    SessionBeat(
      time: '0:48–0:50',
      kind: BeatKind.doorway,
      title: 'As they leave',
      startMinute: 48,
      durationMinutes: 2,
      keyLines: [
        'Good moves today, photographer.',
      ],
      script: [
        ScriptLine.cue('At the door, each kid:'),
        ScriptLine.say('Good moves today, photographer.'),
      ],
    ),

    // ── After they leave (2 min) ─────────────────────────────────────
    SessionBeat(
      time: 'after',
      kind: BeatKind.after,
      title: 'After they leave',
      durationMinutes: 2,
      keyLines: [
        'Note the three best worlds (the throne-chair, the giant crumb, the crayon-through-a-cup).',
        'Parent message: "Ask your photographer to show you something from an ant\'s view."',
        'Nine words on the wall. Stand the tubes up. Session 4 chases light.',
      ],
      script: [
        ScriptLine.cue(
          'Note the three best worlds (the throne-chair, the giant crumb, the '
          'crayon-through-a-cup).',
        ),
        ScriptLine.note(
          'Parent message: "Ask your photographer to show you something from '
          'an ant\'s view."',
        ),
        ScriptLine.cue('Nine words on the wall. Stand the tubes up.'),
        ScriptLine.note('Session 4 chases light.'),
      ],
    ),
  ],
);
