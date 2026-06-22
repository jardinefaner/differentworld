// Through My Eyes — Session 5 · "My Different World" — the FULL beat
// sequence behind the `photo.s5.my-different-world` summary in
// photo_curriculum.dart. This is the host-facing presenter content: every
// beat the staffer walks through, with "every word to say" kept VERBATIM
// from the source script.
//
// Encoding note: each timed section is one [SessionBeat]. "My World in 10"
// is the single shooting beat (the per-child photo turns) and carries a
// [BeatGame]. Session 5 has NO separate drawing beat — the Gallery Walk
// (a quiet looking-together cooldown) and Curate (the standing pick-your-
// three skill beat, no camera) replace it, so neither carries a
// [BeatGame]. Say-lines are reproduced exactly; do not paraphrase them in
// code.

import 'package:differentworld/features/curricula/session_script.dart';

const photoSession5Script = SessionScript(
  slug: 'photo.s5.my-different-world',
  sessionNumber: 5,
  title: 'My Different World',
  beats: [
    // ── Before they arrive (prep) ────────────────────────────────────
    SessionBeat(
      time: 'prep',
      kind: BeatKind.prep,
      title: 'Before they arrive',
      keyLines: [
        'Tubes out. The wall: twelve words. No cards today, no targets — today there are no rules.',
        'Have table space ready (each kid will lay out their "ten").',
        'Journals, crayons, slips of paper for titles.',
      ],
      script: [
        ScriptLine.cue('Tubes out. The wall: twelve words.'),
        ScriptLine.cue(
          'No cards today, no targets — today there are no rules.',
        ),
        ScriptLine.cue(
          'Have table space ready (each kid will lay out their "ten").',
        ),
        ScriptLine.cue('Journals, crayons, slips of paper for titles.'),
      ],
    ),

    // ── 0:00–0:03 — The Hook: everything comes together ───────────────
    SessionBeat(
      time: '0:00–0:03',
      kind: BeatKind.hook,
      title: 'The Hook · everything comes together',
      startMinute: 0,
      durationMinutes: 3,
      keyLines: [
        'Twelve words, photographers. Look what you can do. You learned to SEE. To HUNT. To MOVE. To chase LIGHT. Four superpowers.',
        'Today I give you the biggest job a photographer ever gets.',
        'Today you photograph YOUR world. Not my targets. Not the room I picked. YOUR life, through YOUR eyes. The stuff that matters to YOU.',
      ],
      script: [
        ScriptLine.say(
          'Twelve words, photographers. Look what you can do. You learned to '
          'SEE. To HUNT. To MOVE. To chase LIGHT. Four superpowers.',
        ),
        ScriptLine.cue('Pause.'),
        ScriptLine.say(
          "Today I'm not giving you a hunt. No targets. No game. Today I give "
          'you the biggest job a photographer ever gets.',
        ),
        ScriptLine.cue('Hold up the tube.'),
        ScriptLine.say(
          'Today you photograph YOUR world. Not my targets. Not the room I '
          'picked. YOUR life, through YOUR eyes. The stuff that matters to YOU.',
        ),
      ],
    ),

    // ── 0:03–0:06 — The Mission: your world in ten ───────────────────
    SessionBeat(
      time: '0:03–0:06',
      kind: BeatKind.reveal,
      title: 'The Mission · your world in ten',
      startMinute: 3,
      durationMinutes: 3,
      keyLines: [
        "Here's the whole job. Ten photos. Not nine. Not eleven. TEN. Of anything in your world that matters to you.",
        "And here's the magic rule: if someone looked at your ten photos — a stranger who never met you — they should know who you ARE. Without you saying a word.",
        'Your ten photos are your story. Use everything you know. Get low. Find the light. Hunt the little things. Make it YOURS.',
      ],
      script: [
        ScriptLine.say(
          "Here's the whole job. Ten photos. Not nine. Not eleven. TEN. Of "
          'anything in your world that matters to you.',
        ),
        ScriptLine.say(
          'Your best friend. Your shoes. Your snack. Your favorite corner. The '
          'crack in the sidewalk you always step on. The sky right now. '
          'Whatever is YOURS.',
        ),
        ScriptLine.say(
          "And here's the magic rule: if someone looked at your ten photos — a "
          'stranger who never met you — they should know who you ARE. Without '
          'you saying a word. Your ten photos are your story. Use everything '
          'you know. Get low. Find the light. Hunt the little things. Make it '
          'YOURS.',
        ),
      ],
    ),

    // ── 0:06–0:21 — Game: My World in 10 (15 min) ────────────────────
    SessionBeat(
      time: '0:06–0:21',
      kind: BeatKind.game,
      title: 'Game · My World in 10',
      startMinute: 6,
      durationMinutes: 15,
      keyLines: [
        "Ten photos. Things you LOVE. Take your time — this isn't a race, it's your story. Cameras up… GO.",
        "Dev's photographing his own shoes from the floor — low angle, that's a where I stand photo.",
        "Sam's shooting the light coming through the window onto his journal. He's using everything.",
      ],
      game: BeatGame(
        name: 'My World in 10',
        minutes: 15,
        prompt: 'Ten photos of YOUR world — things that matter to you',
        rules: [
          'Ten photos. Things you LOVE.',
          "Take your time — this isn't a race, it's your story.",
          'If a stranger saw your ten, they should know who you ARE.',
        ],
      ),
      script: [
        ScriptLine.note('(the shooting beat)'),
        ScriptLine.say(
          "Ten photos. Things you LOVE. Take your time — this isn't a race, "
          "it's your story. Cameras up… GO.",
        ),
        ScriptLine.cue(
          'Walk gently — quieter today, less announcer, more witness:',
        ),
        ScriptLine.say(
          "Dev's photographing his own shoes from the floor — low angle, "
          "that's a where I stand photo.",
        ),
        ScriptLine.say(
          "Priya caught her friend mid-laugh — didn't pose, just caught it "
          'real.',
        ),
        ScriptLine.say(
          "Sam's shooting the light coming through the window onto his journal. "
          "He's using everything.",
        ),
      ],
    ),

    // ── 0:21–0:28 — The Gallery Walk: looking together ───────────────
    SessionBeat(
      time: '0:21–0:28',
      kind: BeatKind.cooldown,
      title: 'The Gallery Walk · looking together, the real way',
      startMinute: 21,
      durationMinutes: 7,
      keyLines: [
        'Stop. Now we do something different. Lay your ten out — on the table, or hold up your tube and show them one at a time.',
        "We're going to do what real galleries do. Everybody stands up. We WALK. Slowly. Past everyone's ten. Like a museum. Quiet. Just look.",
        "Ten photos and a whole person shows up. That's what a photographer does — they show you who they are by what they POINT AT.",
      ],
      script: [
        ScriptLine.say(
          'Stop. Now we do something different. Lay your ten out — on the '
          'table, or hold up your tube and show them one at a time.',
        ),
        ScriptLine.say(
          "We're not going to put them on one screen. We're going to do what "
          'real galleries do. Everybody stands up. We WALK. Slowly. Past '
          "everyone's ten. Like a museum. Quiet. Just look.",
        ),
        ScriptLine.cue(
          "The kids walk the room, looking at each other's worlds.",
        ),
        ScriptLine.cue('After:'),
        ScriptLine.say(
          "What did you see in someone ELSE's world that surprised you?",
        ),
        ScriptLine.response("Maya took a photo of her grandma's hands."),
        ScriptLine.response('Dev only took photos of blue things!'),
        ScriptLine.say(
          "Ten photos and a whole person shows up. That's what a photographer "
          'does — they show you who they are by what they POINT AT.',
        ),
      ],
    ),

    // ── 0:28–0:33 — Curate: pick your best three ─────────────────────
    SessionBeat(
      time: '0:28–0:33',
      kind: BeatKind.frame,
      title: 'Curate · pick your best three',
      startMinute: 28,
      durationMinutes: 5,
      keyLines: [
        "Last big job, and it's a grown-up one. Out of your ten, pick your best THREE. The three that are the MOST you. The three for tomorrow's show.",
        "This is the hardest thing photographers do. It's called CURATING — choosing. Leaving good ones out so the best ones SHINE.",
        "Now give each of your three a TITLE. Not 'my shoe.' A real title. You're not just a photographer now. You're the artist who NAMES the work.",
      ],
      script: [
        ScriptLine.say(
          "Last big job, and it's a grown-up one. Out of your ten, pick your "
          'best THREE. The three that are the MOST you. The three for '
          "tomorrow's show.",
        ),
        ScriptLine.say(
          "This is the hardest thing photographers do. It's called CURATING — "
          'choosing. Leaving good ones out so the best ones SHINE.',
        ),
        ScriptLine.cue('Help them choose; resist choosing for them.'),
        ScriptLine.say(
          "Now give each of your three a TITLE. Not 'my shoe.' A real title. "
          "'Where I Stand.' 'Grandma's Hands.' 'The Light On My Book.' You're "
          "not just a photographer now. You're the artist who NAMES the work.",
        ),
        ScriptLine.cue('Write/dictate the three titles.'),
      ],
    ),

    // ── 0:33–0:38 — The Vocabulary Wall (grows to fifteen) ───────────
    SessionBeat(
      time: '0:33–0:38',
      kind: BeatKind.vocab,
      title: 'The Vocabulary Wall · grows to fifteen',
      startMinute: 33,
      durationMinutes: 5,
      vocabCards: ['Candid', 'Story', 'Curate'],
      keyLines: [
        'Read me the twelve.',
        'CANDID — a real moment you caught without posing. STORY — your photos together tell who you are. CURATE — choosing your best.',
        'Fifteen words. One session left — and tomorrow, the wall fills up… because tomorrow is your SHOW.',
      ],
      script: [
        ScriptLine.say('Read me the twelve.'),
        ScriptLine.cue('They do.'),
        ScriptLine.say('Three more — and these are about YOU now.'),
        ScriptLine.note('[CANDID]'),
        ScriptLine.say(
          "A real moment you caught without posing. Nobody said cheese. It's "
          'true.',
        ),
        ScriptLine.response('CANDID.'),
        ScriptLine.note('[STORY]'),
        ScriptLine.say(
          'Your photos together tell who you are. Ten photos, one story — '
          'yours.',
        ),
        ScriptLine.response('STORY.'),
        ScriptLine.note('[CURATE]'),
        ScriptLine.say(
          'Choosing your best. Leaving good ones out so the great ones shine.',
        ),
        ScriptLine.response('CURATE.'),
        ScriptLine.say(
          'Fifteen words. One session left — and tomorrow, the wall fills up… '
          'because tomorrow is your SHOW.',
        ),
      ],
    ),

    // ── 0:38–0:42 — The Closing Circle ────────────────────────────────
    SessionBeat(
      time: '0:38–0:42',
      kind: BeatKind.closing,
      title: 'The Closing Circle',
      startMinute: 38,
      durationMinutes: 4,
      callResponse: 'PHOTOGRAPHERS → MINE',
      keyLines: [
        'Nobody else on earth would take YOUR ten photos. Nobody. Your eyes are the only pair like them.',
        'Tomorrow your three best go on the wall, with your name and your titles, and the people who love you come to SEE them. Tomorrow you have a show.',
        'What are you? — PHOTOGRAPHERS. And whose world did you show today? — MINE.',
      ],
      script: [
        ScriptLine.say('Cameras down. Circle.'),
        ScriptLine.say('Listen.'),
        ScriptLine.say(
          'Nobody else on earth would take YOUR ten photos. Nobody. Your eyes '
          'are the only pair like them. That — not the camera — is what makes '
          "you a photographer. It's what you choose to point at.",
        ),
        ScriptLine.say(
          'Tomorrow is not practice. Tomorrow your three best go on the wall, '
          'with your name and your titles, and the people who love you come to '
          'SEE them. Tomorrow you have a show.',
        ),
        ScriptLine.say('What are you?'),
        ScriptLine.response('PHOTOGRAPHERS.'),
        ScriptLine.say('And whose world did you show today?'),
        ScriptLine.response('MINE.'),
        ScriptLine.say("That's right. Rest up, artists."),
      ],
    ),

    // ── 0:42–0:44 — As they leave ─────────────────────────────────────
    SessionBeat(
      time: '0:42–0:44',
      kind: BeatKind.doorway,
      title: 'As they leave',
      startMinute: 42,
      durationMinutes: 2,
      keyLines: [
        "Can't wait for your show, photographer.",
        'To each.',
      ],
      script: [
        ScriptLine.say("Can't wait for your show, photographer."),
        ScriptLine.cue('To each.'),
      ],
    ),

    // ── After they leave (3 min) ─────────────────────────────────────
    SessionBeat(
      time: 'after',
      kind: BeatKind.after,
      title: 'After they leave',
      durationMinutes: 3,
      keyLines: [
        "Save each kid's three + their titles for tomorrow's gallery. Print/mount tonight if you can.",
        'Send the invitation home: "Come to [Name]\'s photography show tomorrow."',
        'Fifteen words on the wall, three spaces left. Tomorrow they fill — at the show.',
      ],
      script: [
        ScriptLine.cue(
          "Save each kid's three + their titles for tomorrow's gallery. "
          'Print/mount tonight if you can.',
        ),
        ScriptLine.cue(
          'Send the invitation home: "Come to [Name]\'s photography show '
          'tomorrow."',
        ),
        ScriptLine.note(
          'Fifteen words on the wall, three spaces left. Tomorrow they fill — '
          'at the show.',
        ),
      ],
    ),
  ],
);
