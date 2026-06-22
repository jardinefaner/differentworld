// Through My Eyes — Session 2 · "The Hunt" — the FULL beat sequence behind
// the `photo.s2.scavenger-hunt` summary in photo_curriculum.dart. This is
// the host-facing presenter content: every beat the staffer walks through,
// with "every word to say" kept VERBATIM from the source script.
//
// Encoding note: each timed section is one [SessionBeat]. "The Hunt" is the
// single shooting beat (the per-child photo turns) and carries a [BeatGame];
// "The Twist" is a quick standing imagination game with NO camera turns, so
// it leaves [SessionBeat.game] null. Say-lines are reproduced exactly; do
// not paraphrase them in code.

import 'package:differentworld/features/curricula/session_script.dart';

const photoSession2Script = SessionScript(
  slug: 'photo.s2.scavenger-hunt',
  sessionNumber: 2,
  title: 'The Hunt',
  beats: [
    // ── Before they arrive (5 min prep) ──────────────────────────────
    SessionBeat(
      time: 'prep',
      kind: BeatKind.prep,
      title: 'Before they arrive',
      durationMinutes: 5,
      keyLines: [
        'The tubes are back, standing on the center table — their cameras are waiting for them.',
        "On the vocabulary wall: the three words from last time, already up — Composition. Close-up. Subject. Don't point at them yet.",
        'Have ready: journals, crayons, and (optional) six little picture-cards — pictures only, no words.',
      ],
      script: [
        ScriptLine.cue(
          'The tubes are back, standing on the center table — their cameras '
          'are waiting for them.',
        ),
        ScriptLine.cue(
          'On the vocabulary wall: the three words from last time, already up '
          '— Composition. Close-up. Subject.',
        ),
        ScriptLine.note("Don't point at them yet. They'll notice."),
        ScriptLine.note(
          'Hidden in your pocket: nothing new today — the room itself is the '
          'treasure.',
        ),
        ScriptLine.cue(
          'Have ready: journals, crayons, and (optional) six little '
          'picture-cards, each a simple drawing — a red blob, a circle, a '
          'tiny dot, a tall line, a shadow shape, a smiley face. No words on '
          'them. Pictures only.',
        ),
        ScriptLine.note(
          "(No cards? You'll call the targets out loud instead. Works either "
          'way.)',
        ),
      ],
    ),

    // ── 0:00–0:03 — The Hook: the callback ───────────────────────────
    SessionBeat(
      time: '0:00–0:03',
      kind: BeatKind.hook,
      title: 'The Hook · the callback',
      startMinute: 0,
      durationMinutes: 3,
      keyLines: [
        'Photographers. Last time, I taught you the difference between two words. Who remembers them?',
        "Today I'm going to make it harder. Today you don't just see. Today you HUNT.",
        "When you're hunting for something, you see ten times more.",
      ],
      script: [
        ScriptLine.cue('Kids in the circle, tubes on the table.'),
        ScriptLine.say(
          'Photographers. Last time, I taught you the difference between two '
          'words. Who remembers them?',
        ),
        ScriptLine.cue('Let them try.'),
        ScriptLine.response('Looking and seeing.'),
        ScriptLine.say(
          'Looking is free. Your eyes do it all day. Seeing is when you '
          'NOTICE — on purpose.',
        ),
        ScriptLine.cue('Pause.'),
        ScriptLine.say(
          "Today I'm going to make it harder. Today you don't just see. Today "
          'you HUNT.',
        ),
        ScriptLine.cue('Pick up a tube. Hold it to your eye.'),
        ScriptLine.say(
          'Quick test. Cameras up. Everybody — find me something RED in this '
          "room. Right now. When you've got it in your frame… CLICK.",
        ),
        ScriptLine.response('CLICK!'),
        ScriptLine.cue('Tubes swing to red shirts, a red marker, a red book.'),
        ScriptLine.say("FREEZE. Don't move."),
        ScriptLine.cue('Walk fast, glance through a few.'),
        ScriptLine.say("Red. Red. Ooh — red I didn't even know was here."),
        ScriptLine.say(
          'RELEASE. Now — three seconds ago, were you LOOKING at that red '
          'thing? No. It was just there. But the second I gave you a job — '
          "find red — your eyes went and FOUND it. That's the secret. When "
          "you're hunting for something, you see ten times more.",
        ),
      ],
    ),

    // ── 0:03–0:06 — The Mission: point with purpose ──────────────────
    SessionBeat(
      time: '0:03–0:06',
      kind: BeatKind.reveal,
      title: 'The Mission · point with purpose',
      startMinute: 3,
      durationMinutes: 3,
      keyLines: [
        'Last time your camera could point at anything. Beautiful chaos. Today is different.',
        "A hunter doesn't shoot at everything. A hunter is PATIENT. A hunter is looking for ONE specific thing.",
        'Today your camera has a MISSION. Six things to find.',
      ],
      script: [
        ScriptLine.say(
          'Last time your camera could point at anything. Click click click, '
          'whatever you wanted. Beautiful chaos. Today is different.',
        ),
        ScriptLine.cue('Hold the tube like a hunter.'),
        ScriptLine.say(
          "A hunter doesn't shoot at everything. A hunter is PATIENT. A "
          'hunter is looking for ONE specific thing, and waits, and when it '
          'appears — got it.',
        ),
        ScriptLine.cue('Scan slowly through the tube, then stop sharp.'),
        ScriptLine.say(
          "Today your camera has a MISSION. Six things to find. And here's "
          'the part nobody believes until they try it — some of these six '
          'things have been in this room the whole time, every single day, '
          'and you have NEVER seen them. Until today. Because today, '
          "you're hunting.",
        ),
      ],
    ),

    // ── 0:06–0:09 — The Six Targets ──────────────────────────────────
    SessionBeat(
      time: '0:06–0:09',
      kind: BeatKind.reveal,
      title: 'The Six Targets',
      startMinute: 6,
      durationMinutes: 3,
      keyLines: [
        "Here's your hunt. Six things. You photograph all six.",
        'One — RED. Two — ROUND. Three — TINY. Four — TALL. Five — a SHADOW. And six… a FACE hiding in something.',
        'Six targets. One camera. Go find them with your eyes.',
      ],
      script: [
        ScriptLine.cue(
          'Hold up each picture-card (or just call it, with your fingers or '
          'the tube as the visual).',
        ),
        ScriptLine.say(
          "Here's your hunt. Six things. You photograph all six.",
        ),
        ScriptLine.cue('Count them on your fingers, slow.'),
        ScriptLine.say(
          'One — something RED. Two — something perfectly ROUND. Three — '
          'something TINY, so small most people walk right past it. Four — '
          'something TALL, you have to point your camera UP. Five — a SHADOW. '
          'Not a thing — a shadow. And six… the hard one… a FACE. Not a '
          "person's face. A face HIDING in something. In a doorknob. In a "
          'plug in the wall. In the back of a chair. Faces are hiding '
          'everywhere and most grown-ups never see a single one.',
        ),
        ScriptLine.cue('Pause on that.'),
        ScriptLine.say(
          'Six targets. One camera. Go find them with your eyes.',
        ),
      ],
    ),

    // ── 0:09–0:24 — Game: The Hunt (15 min) ──────────────────────────
    SessionBeat(
      time: '0:09–0:24',
      kind: BeatKind.game,
      title: 'Game · The Hunt',
      startMinute: 9,
      durationMinutes: 15,
      keyLines: [
        "When you find a target — CLICK, FREEZE, and call me over so I can see it through your camera. I'll check it off.",
        "Hardest one's the face — save it or hunt it first, your call. Cameras up. Hunters ready… GO.",
        'The face finds are the magic of this session. Treat each one like a discovery, because it is.',
      ],
      game: BeatGame(
        name: 'The Hunt',
        minutes: 15,
        prompt:
            'Find all six: red · round · tiny · tall · a shadow · a hidden face',
        rules: [
          "When you find a target — CLICK, FREEZE, and call me over so I can see it through your camera. I'll check it off.",
          "Find all six. You don't have to go in order.",
          "Hardest one's the face — save it or hunt it first, your call.",
        ],
      ),
      script: [
        ScriptLine.say(
          'When you find a target — CLICK, FREEZE, and call me over so I can '
          "see it through your camera. I'll check it off. Find all six. You "
          "don't have to go in order. Hardest one's the face — save it or "
          'hunt it first, your call. Cameras up. Hunters ready… GO.',
        ),
        ScriptLine.note(
          '(This is the shooting beat — the per-child photo turns.)',
        ),
        ScriptLine.cue('The room turns into a search party.'),
        ScriptLine.note('Walk it like a guide, not a boss:'),
        ScriptLine.say(
          "Tariq's hunting TALL — he's pointing his camera straight up at the "
          'top of the bookshelf. Nobody looks up there.',
        ),
        ScriptLine.say(
          'Priya found ROUND — the doorknob! And wait — Priya, is there a '
          'FACE in that doorknob too? Look again…',
        ),
        ScriptLine.say(
          "Nora's on the floor hunting TINY. What is it? A crumb? A staple? "
          'Show me.',
        ),
        ScriptLine.cue('When a kid finds a FACE, stop everything:'),
        ScriptLine.say(
          'EVERYBODY. Nora found a face. In the electrical outlet. Two holes '
          "and a little mouth. It's been smiling at this whole room for YEARS "
          "and she's the first person who ever saw it. Come look. One at a "
          'time.',
        ),
        ScriptLine.note(
          'The face finds are the magic of this session. Treat each one like '
          'a discovery, because it is.',
        ),
      ],
    ),

    // ── 0:24–0:30 — Looking Together: lay them side by side ──────────
    SessionBeat(
      time: '0:24–0:30',
      kind: BeatKind.cooldown,
      title: 'Looking Together · lay them side by side',
      startMinute: 24,
      durationMinutes: 6,
      keyLines: [
        "When you give ten photographers the same target, you get ten different photos. That's why this is art.",
        "You pointed your camera at NOTHING — at the dark shape where the light couldn't reach — and you caught it. You photographed light.",
        "Your brain is a face-finding machine. That has a real name — pareidolia. Your brain found a face nobody built. That's a superpower.",
      ],
      script: [
        ScriptLine.say('Hunters, sit. Cameras in your lap.'),
        ScriptLine.cue('Go category by category.'),
        ScriptLine.note(
          'If you can put photos on the big screen, do; if not, go around and '
          'have each kid describe their find.',
        ),
        ScriptLine.cue('The RED ones, together:'),
        ScriptLine.say(
          'Everybody who hunted red — what did you find? A red shoe. A red '
          "letter on a sign. Red inside someone's backpack. Look — SAME "
          'color, all DIFFERENT things. When you give ten photographers the '
          "same target, you get ten different photos. That's why this is art.",
        ),
        ScriptLine.cue('Then the SHADOWS — slow down here:'),
        ScriptLine.say(
          "You photographed a SHADOW. Think about that. A shadow isn't a "
          "thing you can pick up. It's what happens when something blocks the "
          'light. You pointed your camera at NOTHING — at the dark shape '
          "where the light couldn't reach — and you caught it. You "
          'photographed light. Or really… you photographed where the light '
          "ISN'T.",
        ),
        ScriptLine.cue('Then the FACES:'),
        ScriptLine.say(
          "And the faces. Here's what happened in your brain. There is no "
          'face in a doorknob. But your brain is a face-finding machine — '
          "it's so good at faces it finds them where there aren't any. That "
          'has a real name. Photographers and scientists call it pareidolia. '
          "You don't have to remember the word. Just remember: your brain "
          "found a face nobody built. That's a superpower.",
        ),
      ],
    ),

    // ── 0:30–0:34 — The Twist: the impossible target ─────────────────
    SessionBeat(
      time: '0:30–0:34',
      kind: BeatKind.frame,
      title: 'The Twist · the impossible target',
      startMinute: 30,
      durationMinutes: 4,
      keyLines: [
        "One more hunt. Cameras up. But this one's almost impossible. Find me… one thing… that is BOTH round AND red.",
        "When the target gets harder, you don't see LESS — you see MORE. Your eyes work harder and the room gets bigger.",
        'A photographer never runs out of things to find. The room is infinite if you keep changing the hunt.',
      ],
      script: [
        ScriptLine.note(
          'Quick standing game, raises the difficulty, pure delight.',
        ),
        ScriptLine.say(
          "One more hunt. Cameras up. But this one's almost impossible. I "
          'want you to find me… one thing… that is BOTH round AND red.',
        ),
        ScriptLine.cue('They scan, frantic.'),
        ScriptLine.cue(
          "Some find it (a red ball, a clock, a sticker). Some can't.",
        ),
        ScriptLine.say('Harder. Find something that is tiny AND tall.'),
        ScriptLine.cue(
          '(A pencil standing up. A single tall blade of grass by the '
          'window.)',
        ),
        ScriptLine.say(
          'Hardest. Find something that has a SHADOW shaped like a letter.',
        ),
        ScriptLine.say(
          "See what just happened? When the target gets harder, you don't see "
          'LESS — you see MORE. Your eyes work harder and the room gets '
          'bigger. A photographer never runs out of things to find. The room '
          'is infinite if you keep changing the hunt.',
        ),
      ],
    ),

    // ── 0:34–0:43 — Drawing: My Best Three (9 min) ───────────────────
    SessionBeat(
      time: '0:34–0:43',
      kind: BeatKind.drawing,
      title: 'Drawing · My Best Three',
      startMinute: 34,
      durationMinutes: 9,
      keyLines: [
        'Open your journals. Time to print — with your hand, like last time. Three rectangles.',
        'Pick your three best finds from the hunt. The three that surprised you. Draw only what was INSIDE your tube.',
        'Three minutes each. Fast, not perfect. Hunters move.',
      ],
      script: [
        ScriptLine.say(
          'Open your journals. Time to print — with your hand, like last '
          'time. Three rectangles.',
        ),
        ScriptLine.cue('Draw three frames on the board.'),
        ScriptLine.say(
          'Pick your three best finds from the hunt. The three that surprised '
          'you. Draw only what was INSIDE your tube — the circle of the '
          "frame. Everything outside the frame doesn't exist.",
        ),
        ScriptLine.say('Three minutes each. Fast, not perfect. Hunters move.'),
        ScriptLine.cue('Walk and coach as they draw:'),
        ScriptLine.note('For a red find:'),
        ScriptLine.say(
          'Fill the frame with it. Make the red the SUBJECT — the star. Last '
          "week's word. The thing the whole photo is about.",
        ),
        ScriptLine.note('For a found face:'),
        ScriptLine.say(
          "Just the face part. Get close. That's a CLOSE-UP — the tiny "
          'becomes huge.',
        ),
        ScriptLine.note('For a shadow:'),
        ScriptLine.say(
          'Draw the dark shape, not the thing that made it. The shadow is the '
          'subject now.',
        ),
        ScriptLine.cue('Caption together as they finish:'),
        ScriptLine.say("What's this one?"),
        ScriptLine.response('The face in the outlet.'),
        ScriptLine.say('What was it really?'),
        ScriptLine.response('A plug.'),
        ScriptLine.say("Let's title it: 'The Outlet That's Been Smiling.'"),
      ],
    ),

    // ── 0:43–0:48 — The Vocabulary Wall (it grows) ───────────────────
    SessionBeat(
      time: '0:43–0:48',
      kind: BeatKind.vocab,
      title: 'The Vocabulary Wall · it grows',
      startMinute: 43,
      durationMinutes: 5,
      vocabCards: ['Frame', 'Shadow', 'Pop'],
      keyLines: [
        "You EARNED three words last time. Today you earned three more. Because you discovered them — I'm just giving them names.",
        'FRAME — the EDGE of your photo. SHADOW — a photo of light being blocked. POP — when one thing JUMPS out from everything around it.',
        "Six words on the wall now. By the last session it'll be full. Every single one you earned by finding something real.",
      ],
      script: [
        ScriptLine.say("Walk over to the wall. Read me last week's words."),
        ScriptLine.response('Composition. Close-up. Subject.'),
        ScriptLine.cue('They remember. Celebrate that.'),
        ScriptLine.say(
          'You EARNED three words last time. Today you earned three more. '
          "Because you discovered them — I'm just giving them names.",
        ),
        ScriptLine.cue('Tape up three new cards as you say each:'),
        ScriptLine.note('[FRAME]'),
        ScriptLine.say(
          'The frame is the EDGE of your photo. What you let in, what you cut '
          'out. Every time you hunted ONE target and left everything else out '
          '— that was you choosing your frame.',
        ),
        ScriptLine.response('FRAME.'),
        ScriptLine.note('[SHADOW]'),
        ScriptLine.say(
          'A photo of light being blocked. You photograph something you '
          "can't even touch. Today you all did it.",
        ),
        ScriptLine.response('SHADOW.'),
        ScriptLine.note('[POP]'),
        ScriptLine.say(
          'When one thing JUMPS out from everything around it. The red door '
          "in a gray hallway. That's a POP. Your eye goes straight to it.",
        ),
        ScriptLine.response('POP.'),
        ScriptLine.say(
          "Six words on the wall now. By the last session it'll be full. "
          'Every single one you earned by finding something real.',
        ),
      ],
    ),

    // ── 0:48–0:52 — The Closing Circle ───────────────────────────────
    SessionBeat(
      time: '0:48–0:52',
      kind: BeatKind.closing,
      title: 'The Closing Circle',
      startMinute: 48,
      durationMinutes: 4,
      callResponse: 'PHOTOGRAPHERS → SEE',
      keyLines: [
        'Last time I asked you what the difference was between looking and seeing. Today you proved it.',
        'Give YOURSELF a hunt. Pick one thing — the color blue, or circles, or faces — and hunt it all day.',
        'What are you? — PHOTOGRAPHERS. What do photographers do that everybody else forgets to? — SEE.',
      ],
      script: [
        ScriptLine.say('Cameras on the table. Circle up.'),
        ScriptLine.cue('Pause.'),
        ScriptLine.say(
          'Last time I asked you what the difference was between looking and '
          'seeing. Today you proved it. Because I gave you a hunt, you saw a '
          'face in a wall. A shadow you could photograph. Red in ten places '
          'you walk past every day.',
        ),
        ScriptLine.say(
          "Here's your fun homework. Between now and next time, give YOURSELF "
          'a hunt. Pick one thing — the color blue, or circles, or faces — '
          'and hunt it all day. At home, in the car, at the store. See how '
          "many you find when you're looking on purpose.",
        ),
        ScriptLine.say('What are you?'),
        ScriptLine.response('PHOTOGRAPHERS.'),
        ScriptLine.say(
          'And what do photographers do that everybody else forgets to?',
        ),
        ScriptLine.response('SEE.'),
        ScriptLine.say("That's right. Go hunt, photographers."),
      ],
    ),

    // ── 0:52–0:54 — As they leave ────────────────────────────────────
    SessionBeat(
      time: '0:52–0:54',
      kind: BeatKind.doorway,
      title: 'As they leave',
      startMinute: 52,
      durationMinutes: 2,
      keyLines: [
        'Good hunting today, photographer.',
        'Every one. The identity, again.',
        "It's sticking now — they walked in knowing they're photographers.",
      ],
      script: [
        ScriptLine.cue('At the door, to each kid:'),
        ScriptLine.say('Good hunting today, photographer.'),
        ScriptLine.cue('Every one. The identity, again.'),
        ScriptLine.note(
          "It's sticking now — they walked in knowing they're photographers.",
        ),
      ],
    ),

    // ── After they leave (2 min) ─────────────────────────────────────
    SessionBeat(
      time: 'after',
      kind: BeatKind.after,
      title: 'After they leave',
      durationMinutes: 2,
      keyLines: [
        'Write down the three best finds — the smiling outlet, the round-and-red clock, the shadow shaped like a J.',
        'Those go in parent messages tonight: "Ask your photographer about the face they found in the wall today."',
        'Stand the tubes back up. Ready for Session 3.',
      ],
      script: [
        ScriptLine.cue(
          'Write down the three best finds — the smiling outlet, the '
          'round-and-red clock, the shadow shaped like a J.',
        ),
        ScriptLine.note(
          'Those go in parent messages tonight: "Ask your photographer about '
          'the face they found in the wall today."',
        ),
        ScriptLine.cue(
          'Look at the wall: six words. Three more than yesterday.',
        ),
        ScriptLine.cue('Stand the tubes back up.'),
        ScriptLine.note(
          "Ready for Session 3 — where the room stays the same but you'll "
          'teach them to change the whole world just by where they stand.',
        ),
      ],
    ),
  ],
);
