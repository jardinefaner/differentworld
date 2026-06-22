// Through My Eyes — Session 1 · "The Click Game" — the FULL beat
// sequence behind the `photo.s1.click-game` summary in
// photo_curriculum.dart. This is the host-facing presenter content:
// every beat the staffer walks through, with "every word to say" kept
// VERBATIM from the source script.
//
// Encoding note: each timed section is one [SessionBeat]; Game 3 (the
// Outdoor Hunt) is split into its prep beat plus its three sub-rounds
// (Ground / Sky / Eye-Level), one slide + timer each. Say-lines are
// reproduced exactly; do not paraphrase them in code.

import 'package:differentworld/features/curricula/session_script.dart';

const photoSession1Script = SessionScript(
  slug: 'photo.s1.click-game',
  sessionNumber: 1,
  title: 'The Click Game',
  beats: [
    // ── Before they arrive (5 min prep) ──────────────────────────────
    SessionBeat(
      time: 'prep',
      kind: BeatKind.prep,
      title: 'Before they arrive',
      durationMinutes: 5,
      keyLines: [
        "On a table in the center: 10 toilet paper tubes standing upright like a tiny city. Don't explain them.",
        'The vocabulary wall starts empty today. It fills across 6 sessions.',
        'Have ready: journals, crayons, and one special object hidden.',
      ],
      script: [
        ScriptLine.cue('Set up the room.'),
        ScriptLine.cue(
          'On a table in the center: 10 toilet paper tubes standing upright '
          'like a tiny city.',
        ),
        ScriptLine.note(
          "Don't explain them. Let kids notice and wonder. Curiosity is "
          'your opening energy.',
        ),
        ScriptLine.cue('On the board or a large paper, write nothing. Blank.'),
        ScriptLine.note(
          'The vocabulary wall starts empty today. It fills across 6 '
          'sessions.',
        ),
        ScriptLine.cue(
          'Have ready: journals, crayons, and one special object hidden — '
          'something interesting to look at (a pinecone, a cool rock, a '
          'flower, a shell, a feather, anything with texture and detail).',
        ),
        ScriptLine.note('Keep it hidden in your pocket or a bag.'),
      ],
    ),

    // ── 0:00–0:03 — The Hook ─────────────────────────────────────────
    SessionBeat(
      time: '0:00–0:03',
      kind: BeatKind.hook,
      title: 'The Hook',
      startMinute: 0,
      durationMinutes: 3,
      keyLines: [
        'Before we do anything today, I need to test your eyes.',
        "That's because there's a difference between LOOKING and SEEING.",
        "Today, I'm going to teach you how to see.",
      ],
      script: [
        ScriptLine.cue(
          'Kids sit in the circle. The tubes are visible on the table but '
          'nobody has touched them yet.',
        ),
        ScriptLine.say(
          'Before we do anything today, I need to test your eyes.',
        ),
        ScriptLine.cue("Pause. They're curious."),
        ScriptLine.say(
          'Everybody look at me. Really look. Study my face. My clothes. My '
          'shoes. Everything.',
        ),
        ScriptLine.cue('Give them 5 seconds of looking at you.'),
        ScriptLine.say(
          'Okay. Now. Everybody close your eyes. Keep them closed.',
        ),
        ScriptLine.cue('Wait until every eye is closed.'),
        ScriptLine.say('What color are my shoes?'),
        ScriptLine.cue(
          'Shouts. Guesses. Arguments. Some are right. Some are wrong.',
        ),
        ScriptLine.say("Keep your eyes closed. What's on the wall behind me?"),
        ScriptLine.cue('Harder. Mumbles.'),
        ScriptLine.response('The clock?'),
        ScriptLine.response('The calendar?'),
        ScriptLine.say('Keep them closed. How many chairs are in this room?'),
        ScriptLine.cue('Silence. Nobody knows.'),
        ScriptLine.say('Open your eyes.'),
        ScriptLine.cue('They open.'),
        ScriptLine.say(
          "You've been in this room for weeks. You look at these walls "
          "every single day. But when I asked you to REMEMBER what you've "
          'been looking at... most of it was gone.',
        ),
        ScriptLine.cue('Pause. Let it land.'),
        ScriptLine.say(
          "That's because there's a difference between LOOKING and SEEING. "
          "Looking is what your eyes do all day for free. You can't stop "
          'looking — your eyes are open, they look. Seeing is something '
          'else. Seeing is when you pay attention ON PURPOSE. When you '
          'decide: I am going to NOTICE this thing right now.',
        ),
        ScriptLine.say("Today, I'm going to teach you how to see."),
      ],
    ),

    // ── 0:03–0:06 — The Camera Reveal ────────────────────────────────
    SessionBeat(
      time: '0:03–0:06',
      kind: BeatKind.reveal,
      title: 'The Camera Reveal',
      startMinute: 3,
      durationMinutes: 3,
      keyLines: [
        "I'm going to give each of you the most powerful camera in the world.",
        "Because the photograph isn't in the tube. The photograph is in your EYE.",
        "That's what a camera does. It cuts out all the stuff you DON'T need so you can see the ONE thing that matters.",
      ],
      script: [
        ScriptLine.cue('Walk to the table with the tubes.'),
        ScriptLine.say(
          "I'm going to give each of you the most powerful camera in the "
          'world.',
        ),
        ScriptLine.cue("Pick up one tube. Hold it like it's precious."),
        ScriptLine.say(
          'This camera has no batteries. No screen. No buttons. It never '
          'runs out of storage. It never breaks. It costs zero dollars. And '
          'it takes the best photographs of anything ever invented.',
        ),
        ScriptLine.cue('Hold it up to one eye. Close the other.'),
        ScriptLine.say(
          "Because the photograph isn't in the tube. The photograph is in "
          'your EYE. The tube just helps your eye focus.',
        ),
        ScriptLine.cue(
          "Look through the tube. Scan the room slowly. Stop on a kid's shoe.",
        ),
        ScriptLine.say(
          'Right now... I can see... one shoe. Just one shoe. Not the '
          'person. Not the floor. Not the room. One shoe. Everything else '
          "disappeared. And that shoe is the most interesting shoe I've "
          "ever seen because it's the ONLY thing I'm looking at.",
        ),
        ScriptLine.cue('Put it down.'),
        ScriptLine.say(
          "That's what a camera does. It cuts out all the stuff you DON'T "
          'need so you can see the ONE thing that matters.',
        ),
        ScriptLine.say('Ready to get yours?'),
        ScriptLine.response('YES.'),
        ScriptLine.say(
          "Come get your camera. One at a time. Walk, don't run. These are "
          'precision instruments.',
        ),
        ScriptLine.cue(
          'Let each kid pick up a tube. The moment they hold it up and look '
          'through it, the room goes electric.',
        ),
        ScriptLine.note(
          "Let them explore for 30 seconds. Don't stop the chaos. It's "
          'excitement and excitement is fuel.',
        ),
      ],
    ),

    // ── 0:06–0:08 — The Rules of the Camera ──────────────────────────
    SessionBeat(
      time: '0:06–0:08',
      kind: BeatKind.rules,
      title: 'The Rules of the Camera',
      startMinute: 6,
      durationMinutes: 2,
      callResponse: 'CLICK! / FREEZE! / ASK',
      keyLines: [
        'Three rules for your camera.',
        'Three rules. CLICK, FREEZE, and ASK. Got it?',
        "That was your first photograph. You're already photographers.",
      ],
      script: [
        ScriptLine.say('Okay. Cameras down. Look at me.'),
        ScriptLine.cue("Wait. Some kids won't put them down. That's fine."),
        ScriptLine.cue(
          "Wait. They'll notice everyone else is looking at you. They'll "
          'follow.',
        ),
        ScriptLine.say('Three rules for your camera.'),
        ScriptLine.cue('Hold up one finger.'),
        ScriptLine.say(
          'Rule one. When you find something you want to photograph, you say '
          "CLICK out loud. That's your shutter sound. Let me hear it.",
        ),
        ScriptLine.response('CLICK!'),
        ScriptLine.say('Louder.'),
        ScriptLine.response('CLICK!'),
        ScriptLine.say("Good. That's the sound of seeing."),
        ScriptLine.cue('Two fingers.'),
        ScriptLine.say(
          "Rule two. After you CLICK, you FREEZE. Don't move your camera. "
          "Don't move your body. A photograph is a FROZEN MOMENT. If you "
          'move, the photo is blurry. So you click and you turn into a '
          'statue. Hold it until I come see what you found or until I say '
          "'release.'",
        ),
        ScriptLine.cue('Three fingers.'),
        ScriptLine.say(
          "Rule three. No pointing the camera at someone's face unless they "
          "say it's okay. In the real photography world, you always ask "
          'permission before photographing a person. Same here.',
        ),
        ScriptLine.say('Three rules. CLICK, FREEZE, and ASK. Got it?'),
        ScriptLine.response('Got it.'),
        ScriptLine.say(
          "Let's practice. Everybody hold up your camera. Find something in "
          'this room. Anything. Ready... CLICK!',
        ),
        ScriptLine.response('CLICK!'),
        ScriptLine.cue(
          'Every kid freezes with their tube pointed at something.',
        ),
        ScriptLine.say("FREEZE! Hold it! I'm coming around."),
        ScriptLine.cue("Walk quickly. Glance through a few kids' tubes."),
        ScriptLine.say("Nice. Nice. Interesting. Ooh, that's a good one."),
        ScriptLine.say('RELEASE!'),
        ScriptLine.cue('They relax.'),
        ScriptLine.say(
          "That was your first photograph. You're already photographers. "
          "You just don't know how good you are yet.",
        ),
      ],
    ),

    // ── 0:08–0:15 — Game 1: The Speed Round (indoors) ────────────────
    SessionBeat(
      time: '0:08–0:15',
      kind: BeatKind.game,
      title: 'Game 1 · The Speed Round',
      startMinute: 8,
      durationMinutes: 7,
      keyLines: [
        'You have TWO MINUTES to find TEN things in this room that are interesting through your camera.',
        'TEN CLICKs in TWO MINUTES. GO!',
        "A scratch that looks like a face... nobody ever noticed that face. Until you. That's photography.",
      ],
      game: BeatGame(
        name: 'The Speed Round',
        minutes: 2,
        prompt: 'Ten interesting things, two minutes',
        rules: [
          'Find TEN things in this room that are interesting through your camera. Ten CLICKs.',
          "You don't have to freeze for long — just click, freeze for one second, then move to the next one. Speed matters.",
        ],
      ),
      script: [
        ScriptLine.say('Game one. The Speed Round.'),
        ScriptLine.say(
          'You have TWO MINUTES to find TEN things in this room that are '
          'interesting through your camera. Ten CLICKs. Two minutes. You '
          "don't have to freeze for long — just click, freeze for one "
          "second, then move to the next one. Speed matters. I'm counting "
          'down. TEN CLICKs in TWO MINUTES. GO!',
        ),
        ScriptLine.cue('Start a timer. The room explodes with movement.'),
        ScriptLine.cue(
          "Kids pointing tubes at walls, floors, ceiling, each other's "
          'shoes, the plant, the books, the clock. You walk the room '
          'calling out what you see:',
        ),
        ScriptLine.say(
          'Leah just clicked on the pencil sharpener! Nobody ever looks at '
          'that!',
        ),
        ScriptLine.say(
          "Marcus is on the FLOOR clicking up at the ceiling — bug's eye "
          'view!',
        ),
        ScriptLine.say('Sofia clicked on her own hand — a SELF-PORTRAIT!'),
        ScriptLine.note(
          'Call out observations like a sports announcer. The energy is '
          "HIGH. This is pure play. Pure joy. Zero instruction. They're "
          'learning to look by doing nothing except looking fast.',
        ),
        ScriptLine.cue('Timer goes off.'),
        ScriptLine.say(
          "FREEZE! Whatever you're pointing at, HOLD IT. That's your last "
          'photo.',
        ),
        ScriptLine.say('Who got all ten?'),
        ScriptLine.cue('Hands go up.'),
        ScriptLine.say(
          'Who found something that they NEVER noticed in this room before?',
        ),
        ScriptLine.cue('More hands.'),
        ScriptLine.say('Tell me one. Just one.'),
        ScriptLine.response(
          'The back of the clock has a wire going into the wall!',
        ),
        ScriptLine.response(
          "There's a crack in the window that looks like a lightning bolt!",
        ),
        ScriptLine.response(
          'The stapler has a scratch that looks like a face!',
        ),
        ScriptLine.note('THESE MOMENTS. Celebrate every one.'),
        ScriptLine.say(
          'A scratch that looks like a face. You just saw something that has '
          'been sitting on that desk for YEARS and nobody — not one person '
          '— ever noticed that face. Until you. With a toilet paper tube. '
          "In two minutes. That's photography.",
        ),
      ],
    ),

    // ── 0:15–0:18 — The Cool Down: the special object ────────────────
    SessionBeat(
      time: '0:15–0:18',
      kind: BeatKind.cooldown,
      title: 'The Cool Down · the special object',
      startMinute: 15,
      durationMinutes: 3,
      keyLines: [
        "Find ONE thing about it you've never noticed on something like this before. Don't say it yet. Just look.",
        'You just spent 30 seconds looking at one object and found four things.',
        "There's always more than you think.",
      ],
      script: [
        ScriptLine.say('Sit in the circle. Put your cameras in your lap.'),
        ScriptLine.cue(
          'Pull out the special object. The pinecone, the rock, the shell. Hold it up.',
        ),
        ScriptLine.say(
          "I'm going to pass this around the circle. When you get it, hold "
          'it up to your camera. Look at it through the tube. Find ONE thing '
          "about it you've never noticed on something like this before. "
          "Don't say it yet. Just look. Then pass it.",
        ),
        ScriptLine.cue(
          'Pass the object. Slowly. Each kid holds it, looks through their '
          'tube, passes it on. The room is quiet.',
        ),
        ScriptLine.note(
          'After the chaos of the speed round, the silence is dramatic. The '
          'contrast is the transition.',
        ),
        ScriptLine.cue("Once it's been around:"),
        ScriptLine.say('What did you see?'),
        ScriptLine.response('It has tiny holes in it.'),
        ScriptLine.response('The edges are all different sizes.'),
        ScriptLine.response(
          'If you look really close it looks like a tiny building.',
        ),
        ScriptLine.response('One part is darker than the rest.'),
        ScriptLine.cue('Each answer, you translate:'),
        ScriptLine.say(
          "Tiny holes — that's TEXTURE. The surface isn't smooth. It has a "
          'pattern.',
        ),
        ScriptLine.say(
          "Different sized edges — that's DETAIL. No two parts are the same.",
        ),
        ScriptLine.say(
          "Looks like a building — that's IMAGINATION. Photographers see "
          'things AS other things. You looked at a pinecone and saw '
          'architecture.',
        ),
        ScriptLine.say(
          "One part darker — that's SHADOW. The light hits one side more "
          'than the other. The dark side is hiding.',
        ),
        ScriptLine.say(
          'You just spent 30 seconds looking at one object and found four '
          'things. Imagine if you spent 30 seconds looking at ANYTHING. A '
          "doorknob. A leaf. Your own thumb. There's always more than you "
          'think.',
        ),
      ],
    ),

    // ── 0:18–0:22 — Game 2: The Partner Frame (indoors) ──────────────
    SessionBeat(
      time: '0:18–0:22',
      kind: BeatKind.partner,
      title: 'Game 2 · The Partner Frame',
      startMinute: 18,
      durationMinutes: 4,
      keyLines: [
        'One of you is the PHOTOGRAPHER. One is the GUIDE.',
        'The Guide can ONLY give directions. Not "look at the plant." Instead: "Walk three steps forward. Stop. Look down."',
        'The Guide directs. The Photographer follows. When the Photographer finds it and CLICKs: switch roles.',
      ],
      script: [
        ScriptLine.say(
          'Find a partner. One of you is the PHOTOGRAPHER. One is the GUIDE.',
        ),
        ScriptLine.say(
          'The Guide picks something in the room — anything — and walks the '
          'Photographer to it. But the Guide can ONLY give directions. Not '
          "'look at the plant.' Instead: 'Walk three steps forward. Stop. "
          'Look down. See the green thing? Go closer. Closer. Now point your '
          "camera at the very tip of the leaf.'",
        ),
        ScriptLine.say(
          'The Guide directs. The Photographer follows. When the '
          'Photographer finds it and CLICKs: switch roles.',
        ),
        ScriptLine.cue('Three minutes. Two rounds each.'),
        ScriptLine.note(
          'This teaches COMMUNICATION — the Guide has to translate what they '
          "SEE into WORDS that help someone else see it. That's the core "
          'skill of photography without cameras: making someone else see '
          'what you see using only language.',
        ),
        ScriptLine.cue('Walk the room. Listen to the directions:'),
        ScriptLine.say(
          'Go to the window. No, the other one. Look at the bottom corner. '
          'See that little web? Put your camera RIGHT on it.',
        ),
        ScriptLine.note(
          'The Guide is curating. The Photographer is trusting. Both are '
          'seeing.',
        ),
      ],
    ),

    // ── 0:22–0:40 — Game 3: The Outdoor Hunt — prep ──────────────────
    SessionBeat(
      time: '0:22–0:40',
      kind: BeatKind.game,
      title: 'Game 3 · The Outdoor Hunt',
      startMinute: 22,
      durationMinutes: 18,
      keyLines: [
        "We're going outside. But before we go, I need to give you your mission.",
        "Be PICKY. Don't click everything. Click only the things that surprise you.",
        'Give them 2 minutes to explore freely before the rounds begin.',
      ],
      script: [
        ScriptLine.say(
          "Cameras up. We're going outside. But before we go, I need to give you your mission.",
        ),
        ScriptLine.say(
          "Out there, the world is HUGE. There's sky and ground and trees "
          'and buildings and a million things. Your camera can only see ONE '
          "thing at a time. So your mission is: be PICKY. Don't click "
          'everything. Click only the things that surprise you.',
        ),
        ScriptLine.cue(
          'Walk outside. Give them 2 minutes to explore freely. Then:',
        ),
      ],
    ),

    // ── 0:22–0:40 — Round 1: The Ground Hunt (5 min) ─────────────────
    SessionBeat(
      time: '0:22–0:40',
      kind: BeatKind.game,
      title: 'Round 1 · The Ground Hunt',
      startMinute: 24,
      durationMinutes: 5,
      keyLines: [
        'For the next five minutes, your camera can ONLY point DOWN. At the ground. Nothing above your knees.',
        "What's down there that nobody ever looks at?",
        "'Dragon Shadow, Ground Level.' That's a title.",
      ],
      game: BeatGame(
        name: 'The Ground Hunt',
        minutes: 5,
        prompt: 'Point only DOWN — the ground',
        rules: [
          'Your camera can ONLY point DOWN. At the ground.',
          'Nothing above your knees. You are a ground photographer.',
        ],
      ),
      script: [
        ScriptLine.note('Round 1: The Ground Hunt (5 min)'),
        ScriptLine.say(
          'For the next five minutes, your camera can ONLY point DOWN. At '
          'the ground. Nothing above your knees. You are a ground '
          "photographer. What's down there that nobody ever looks at?",
        ),
        ScriptLine.cue(
          'They crouch. They crawl. They point tubes at cracks, ants, '
          'pebbles, grass blades, gum, shoe prints.',
        ),
        ScriptLine.say(
          "FREEZE CHECK! Everyone freeze where you are. What's in your "
          'camera RIGHT NOW?',
        ),
        ScriptLine.cue(
          'Go to three kids. Look through their frame from behind.',
        ),
        ScriptLine.say(
          "You're looking at a shadow on the concrete. Look at the SHAPE of "
          'the shadow. What does it look like?',
        ),
        ScriptLine.response('A dragon.'),
        ScriptLine.say(
          "A dragon shadow. That's your photograph. 'Dragon Shadow, Ground "
          "Level.' That's a title.",
        ),
      ],
    ),

    // ── 0:22–0:40 — Round 2: The Sky Hunt (5 min) ────────────────────
    SessionBeat(
      time: '0:22–0:40',
      kind: BeatKind.game,
      title: 'Round 2 · The Sky Hunt',
      startMinute: 29,
      durationMinutes: 5,
      keyLines: [
        'New rule. Camera can ONLY point UP. Above your head.',
        "What's up there?",
        'You just found a triangle nobody built. Nature built it with branches and your camera found it.',
      ],
      game: BeatGame(
        name: 'The Sky Hunt',
        minutes: 5,
        prompt: 'Point only UP — the sky',
        rules: [
          'Camera can ONLY point UP. Above your head.',
          'The sky. The trees. The wires. The roofline.',
        ],
      ),
      script: [
        ScriptLine.note('Round 2: The Sky Hunt (5 min)'),
        ScriptLine.say(
          'New rule. Camera can ONLY point UP. Above your head. The sky. The '
          "trees. The wires. The roofline. What's up there?",
        ),
        ScriptLine.cue(
          'They tilt back. Some lie on the ground. Tubes pointing straight '
          'up.',
        ),
        ScriptLine.say(
          'The sky between two branches looks like a SHAPE. What shape?',
        ),
        ScriptLine.response('A triangle!'),
        ScriptLine.say(
          'You just found a triangle nobody built. Nature built it with '
          'branches and your camera found it.',
        ),
      ],
    ),

    // ── 0:22–0:40 — Round 3: The Eye-Level Challenge (5 min) ─────────
    SessionBeat(
      time: '0:22–0:40',
      kind: BeatKind.game,
      title: 'Round 3 · The Eye-Level Challenge',
      startMinute: 34,
      durationMinutes: 5,
      keyLines: [
        "Last round. Camera at YOUR eye level. But the challenge: find three things at eye level that you've NEVER noticed before.",
        'Three things hiding in plain sight.',
        'You found something that was HIDDEN under something else. A historian would be jealous right now.',
      ],
      game: BeatGame(
        name: 'The Eye-Level Challenge',
        minutes: 5,
        prompt: 'Eye level — three things hiding in plain sight',
        rules: [
          'Camera at YOUR eye level.',
          "Find three things at eye level that you've NEVER noticed before. Things you walk past every day.",
        ],
      ),
      script: [
        ScriptLine.note('Round 3: The Eye-Level Challenge (5 min)'),
        ScriptLine.say(
          'Last round. Camera at YOUR eye level. But the challenge: find '
          "three things at eye level that you've NEVER noticed before. "
          'Things you walk past every day. Three things hiding in plain '
          'sight.',
        ),
        ScriptLine.note(
          'This is the hardest round because eye level is where we look all '
          'the time. Finding something new at the height you always look is '
          'genuine observation skill.',
        ),
        ScriptLine.say('Everybody got three? FREEZE on your favorite. HOLD.'),
        ScriptLine.cue('Walk to each kid. Quick.'),
        ScriptLine.say('What is it?'),
        ScriptLine.response('The doorknob has tiny letters on it.'),
        ScriptLine.response(
          "There's a spiderweb in the corner of the window frame.",
        ),
        ScriptLine.response(
          "The sign on that pole is peeling and underneath there's a different color.",
        ),
        ScriptLine.cue('For the peeling sign:'),
        ScriptLine.say(
          'You found something that was HIDDEN under something else. '
          "There's a history under that peel. Something used to be there "
          'that someone covered up. You found it. With a toilet paper tube. '
          'A historian would be jealous right now.',
        ),
      ],
    ),

    // ── 0:40–0:43 — The Frame Game (back inside, energy down) ────────
    SessionBeat(
      time: '0:40–0:43',
      kind: BeatKind.frame,
      title: 'The Frame Game',
      startMinute: 40,
      durationMinutes: 3,
      keyLines: [
        "I'm going to describe a photograph. You point your camera at where you think I'd take it. No wrong answers.",
        "That's why photography is art, not math. There's no right answer. Just YOUR answer.",
        "Every single person's 'most beautiful' is different. And every single one is correct.",
      ],
      script: [
        ScriptLine.note(
          'Quick sitting game to transition from outdoor energy to drawing '
          'energy.',
        ),
        ScriptLine.say(
          "I'm going to describe a photograph. You point your camera at "
          "where you think I'd take it. No wrong answers.",
        ),
        ScriptLine.say(
          'My photograph has something round, something red, and a shadow.',
        ),
        ScriptLine.cue(
          'Kids point tubes everywhere. Some at the clock (round), some at '
          "someone's red shirt, some at the floor shadows.",
        ),
        ScriptLine.say(
          "Everyone's pointing somewhere different. That's because my "
          'description could be a HUNDRED photographs. Every one of you '
          "imagined a different picture from the same words. That's why "
          "photography is art, not math. There's no right answer. Just YOUR "
          'answer.',
        ),
        ScriptLine.cue('Do it three times:'),
        ScriptLine.say(
          "My photograph has something old, something metal, and it's "
          'close-up.',
        ),
        ScriptLine.say(
          'My photograph has something alive, something still, and lots of '
          'sky.',
        ),
        ScriptLine.say(
          "My photograph has the most beautiful thing I've ever seen in it.",
        ),
        ScriptLine.cue(
          'The last one: every kid points somewhere different. Some point at '
          'friends. Some point at artwork. Some point out the window. Some '
          'point at their journal.',
        ),
        ScriptLine.say(
          "Look where everyone is pointing. Every single person's 'most "
          "beautiful' is different. And every single one is correct.",
        ),
      ],
    ),

    // ── 0:43–0:52 — Drawing: My Best Three (9 min) ───────────────────
    SessionBeat(
      time: '0:43–0:52',
      kind: BeatKind.drawing,
      title: 'Drawing · My Best Three',
      startMinute: 43,
      durationMinutes: 9,
      keyLines: [
        "We're going to PRINT our photographs. Not with a printer. With your hand.",
        'Pick your three best CLICKs from today. The three that surprised you the most. Draw them.',
        'You have three minutes per drawing. Quick. Not perfect. The speed is the point.',
      ],
      script: [
        ScriptLine.say(
          "Open your journal. We're going to PRINT our photographs. Not with "
          'a printer. With your hand.',
        ),
        ScriptLine.say('Three small rectangles. Like this.'),
        ScriptLine.cue(
          'Draw three rectangles on the board — roughly 3×4 inches each, in '
          'a row.',
        ),
        ScriptLine.say(
          'Pick your three best CLICKs from today. The three that surprised '
          'you the most. Draw them. Not the whole world. Just what you saw '
          'THROUGH YOUR TUBE. Just the circle of what was inside the frame. '
          "Everything outside the frame doesn't exist.",
        ),
        ScriptLine.say(
          'You have three minutes per drawing. Quick. Not perfect. The speed '
          "is the point. Photographers don't spend an hour on one photo. "
          'They capture the moment and move on.',
        ),
        ScriptLine.cue('Start a timer. Walk the room. As they draw:'),
        ScriptLine.say(
          "Make the crack fill the whole rectangle. It's a CLOSE-UP. "
          'Nothing else in the frame.',
        ),
        ScriptLine.note('(For a kid drawing a crack.)'),
        ScriptLine.say(
          'Draw the branches at the edges. The sky in the middle. The SHAPE '
          'is the subject, not the branches.',
        ),
        ScriptLine.note('(For a kid drawing a sky triangle.)'),
        ScriptLine.say(
          "Your shoe is at the top of the frame — you're looking UP at it. "
          "The ground takes up the bottom half. That's a BUG'S EYE "
          'composition.',
        ),
        ScriptLine.note('(For a kid drawing their shoe from below.)'),
        ScriptLine.cue('As they finish, write captions together:'),
        ScriptLine.say('What was this?'),
        ScriptLine.response('The spiderweb on the fence.'),
        ScriptLine.say('And what was the light doing?'),
        ScriptLine.response('The sun was behind it so it was kind of shiny.'),
        ScriptLine.say(
          "Perfect. Let's write: 'Spiderweb with Backlighting, Eye-Level "
          "Shot.' Sound good?",
        ),
        ScriptLine.cue('The kid nods.'),
        ScriptLine.note(
          'They have a museum-quality caption on a crayon drawing. Both '
          'things are true.',
        ),
      ],
    ),

    // ── 0:52–0:56 — The Vocabulary Wall ──────────────────────────────
    SessionBeat(
      time: '0:52–0:56',
      kind: BeatKind.vocab,
      title: 'The Vocabulary Wall',
      startMinute: 52,
      durationMinutes: 4,
      vocabCards: ['Composition', 'Close-up', 'Subject'],
      keyLines: [
        'Every session, you earn new words. Not because I teach them. Because you DISCOVERED them today and now they need a name.',
        'Three words on the wall. By Session 6, this wall will be full.',
        'Every word up there is one you EARNED by seeing something real.',
      ],
      script: [
        ScriptLine.say(
          'Before we close, we need to start our Vocabulary Wall. Every '
          'session, you earn new words. Not because I teach them. Because '
          'you DISCOVERED them today and now they need a name.',
        ),
        ScriptLine.cue(
          'Hold up three pre-written cards. Tape each one to the wall as you '
          'say it:',
        ),
        ScriptLine.note('[COMPOSITION]'),
        ScriptLine.say(
          'This word means: what you put INSIDE the frame and what you leave '
          "OUTSIDE. When you pointed your tube at the pinecone and saw 'a "
          "tiny building' — that was your composition. You chose what to "
          'include. Everything else vanished. Say it with me.',
        ),
        ScriptLine.response('COMPOSITION.'),
        ScriptLine.note('[CLOSE-UP]'),
        ScriptLine.say(
          'When you got on the ground and pointed your camera at an ant and '
          'you could see its legs — that was a close-up. Getting so close '
          'that the tiny becomes ENORMOUS. Close-up means: fill the frame '
          'with one thing. Leave no room for anything else. Say it.',
        ),
        ScriptLine.response('CLOSE-UP.'),
        ScriptLine.note('[SUBJECT]'),
        ScriptLine.say(
          'The subject is the STAR of your photograph. Everything else is '
          'background. When Leah pointed at the crack in the wall, the crack '
          'was her subject. The wall was just the background. The subject is '
          'the reason you stopped. The reason you said CLICK. Say it.',
        ),
        ScriptLine.response('SUBJECT.'),
        ScriptLine.say(
          'Three words on the wall. By Session 6, this wall will be full. '
          'Every word up there is one you EARNED by seeing something real.',
        ),
      ],
    ),

    // ── 0:56–0:59 — The Closing Circle ───────────────────────────────
    SessionBeat(
      time: '0:56–0:59',
      kind: BeatKind.closing,
      title: 'The Closing Circle',
      startMinute: 56,
      durationMinutes: 3,
      callResponse: 'PHOTOGRAPHERS → SEE',
      keyLines: [
        'You took about forty photographs today. No batteries. No screen. No storage.',
        'Make a frame with your hands. Find one thing nobody else is looking at.',
        'What are you? — PHOTOGRAPHERS. What do photographers do? — SEE.',
      ],
      script: [
        ScriptLine.say('Put your cameras on the table. Sit in the circle.'),
        ScriptLine.cue('Pause.'),
        ScriptLine.say(
          'You took about forty photographs today. No batteries. No screen. '
          'No storage. Forty photographs that exist right now in your MEMORY '
          'and three that exist in your journal.',
        ),
        ScriptLine.say(
          'Most grown-ups take out their phone, tap a button, and never look '
          'at the photo again. You held up a tube, froze, described what you '
          'saw, and drew it by hand. Which person saw more? The one with the '
          'phone or the one with the tube?',
        ),
        ScriptLine.cue('Let them answer. They know.'),
        ScriptLine.say(
          "Here's your homework. Not real homework. Fun homework. Between "
          'now and next session, wherever you go — at home, at the store, in '
          'the car — make a frame with your hands.',
        ),
        ScriptLine.cue('Demo: thumbs and index fingers making a rectangle.'),
        ScriptLine.say(
          'Hold it up. Look through it. Find one thing nobody else is '
          "looking at. You don't need the tube. You don't need a camera. "
          'You have hands and you have eyes and you have a brain that now '
          'knows the difference between looking and seeing.',
        ),
        ScriptLine.say('What are you?'),
        ScriptLine.response('PHOTOGRAPHERS.'),
        ScriptLine.say('What do photographers do?'),
        ScriptLine.response('SEE.'),
        ScriptLine.say("That's right. See you next time, photographers."),
      ],
    ),

    // ── 0:59–1:00 — As they leave ────────────────────────────────────
    SessionBeat(
      time: '0:59–1:00',
      kind: BeatKind.doorway,
      title: 'As they leave',
      startMinute: 59,
      durationMinutes: 1,
      keyLines: [
        'Good work today, photographer.',
        'Say it to every one.',
        'The word PHOTOGRAPHER attached to their identity.',
      ],
      script: [
        ScriptLine.cue('Stand at the door. As each kid walks out:'),
        ScriptLine.say('Good work today, photographer.'),
        ScriptLine.cue('Say it to every one.'),
        ScriptLine.note(
          'The word PHOTOGRAPHER attached to their identity. Not "good job '
          'in class." Not "nice work." '
          "You're a photographer. That title sticks.",
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
        'Write down the three best things a kid said.',
        'These quotes go in parent messages tonight and on the Wall tomorrow.',
        'Pick up the tubes. Stand them on the table. Ready for Session 2.',
      ],
      script: [
        ScriptLine.cue('Write down the three best things a kid said.'),
        ScriptLine.note(
          'The scratch that looks like a face. The shadow dragon. The '
          'triangle the branches built.',
        ),
        ScriptLine.note(
          'These quotes go in parent messages tonight and on the Wall '
          'tomorrow.',
        ),
        ScriptLine.cue('Look at the Vocabulary Wall. Three words.'),
        ScriptLine.note(
          'In 5 more sessions there will be seventeen. The wall is growing. '
          'Just like they are.',
        ),
        ScriptLine.cue(
          'Pick up the tubes. Stand them on the table. Ready for Session 2.',
        ),
        ScriptLine.note("The room is quiet. But it's different now."),
      ],
    ),
  ],
);

/// Resolve the full script for a session slug. Returns null when no script
/// has been encoded for that slug yet. Lives here with the data so the model
/// file (session_script.dart) stays free of any dependency on the scripts.
SessionScript? scriptForSession(String slug) =>
    slug == photoSession1Script.slug ? photoSession1Script : null;
