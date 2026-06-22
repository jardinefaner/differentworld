// Through My Eyes — Session 4 · "The Light Chasers" — the FULL beat
// sequence behind the `photo.s4.light-chasers` summary in
// photo_curriculum.dart. This is the host-facing presenter content: every
// beat the staffer walks through, with "every word to say" kept VERBATIM
// from the source script.
//
// Encoding note: each timed section is one [SessionBeat]. "Chase the Light"
// is the single shooting beat (the per-child photo turns) and carries a
// [BeatGame]; "The Twist" is a quick standing imagination game with NO
// camera turns, so it leaves [SessionBeat.game] null. Say-lines are
// reproduced exactly; do not paraphrase them in code.

import 'package:differentworld/features/curricula/session_script.dart';

const photoSession4Script = SessionScript(
  slug: 'photo.s4.light-chasers',
  sessionNumber: 4,
  title: 'The Light Chasers',
  beats: [
    // ── Before they arrive (5 min prep) ──────────────────────────────
    SessionBeat(
      time: 'prep',
      kind: BeatKind.prep,
      title: 'Before they arrive',
      durationMinutes: 5,
      keyLines: [
        'Tubes out. Wall: nine words.',
        "Have 2–3 flashlights. You'll need a way to make the room dark (blinds/curtains) and ideally access to sun + shade outside.",
        'A leaf or a cup of water for the "glow." Journals, crayons.',
      ],
      script: [
        ScriptLine.cue('Tubes out. Wall: nine words.'),
        ScriptLine.cue('Have 2–3 flashlights.'),
        ScriptLine.cue(
          "You'll need a way to make the room dark (blinds/curtains) and "
          'ideally access to sun + shade outside.',
        ),
        ScriptLine.cue('A leaf or a cup of water for the "glow."'),
        ScriptLine.cue('Journals, crayons.'),
      ],
    ),

    // ── 0:00–0:03 — The Hook: the dark-room demo ─────────────────────
    SessionBeat(
      time: '0:00–0:03',
      kind: BeatKind.hook,
      title: 'The Hook · the dark-room demo',
      startMinute: 0,
      durationMinutes: 3,
      keyLines: [
        "Nine words, photographers. You learned to see, to hunt, to move. Today you chase something you can't hold, can't catch, can't keep still — LIGHT.",
        'Same hand the whole time. Three completely different pictures. What changed? Not the hand. THE LIGHT.',
        "Light is the secret ingredient in every photo you've ever loved.",
      ],
      script: [
        ScriptLine.say(
          'Nine words, photographers. You learned to see, to hunt, to move. '
          "Today you chase something you can't hold, can't catch, can't keep "
          'still — LIGHT.',
        ),
        ScriptLine.say(
          'Everybody, camera up, look at your own hand on the floor. Study '
          'it.',
        ),
        ScriptLine.cue('Five seconds.'),
        ScriptLine.say('Now watch.'),
        ScriptLine.cue('Kill the lights.'),
        ScriptLine.say('Same hand. Look at it now.'),
        ScriptLine.cue("(Murmurs — it's gone gray, flat.)"),
        ScriptLine.cue(
          'Click on a flashlight, low and to the side of your own hand.',
        ),
        ScriptLine.say('Now look at MY hand.'),
        ScriptLine.cue('(Long dramatic shadow, bright edge.)'),
        ScriptLine.say('Whoa, right?'),
        ScriptLine.cue('Lights back on.'),
        ScriptLine.say(
          'Same hand the whole time. Three completely different pictures. '
          'What changed? Not the hand. THE LIGHT. Light is the secret '
          "ingredient in every photo you've ever loved.",
        ),
      ],
    ),

    // ── 0:03–0:06 — The Mission: four kinds of light ─────────────────
    SessionBeat(
      time: '0:03–0:06',
      kind: BeatKind.reveal,
      title: 'The Mission · four kinds of light',
      startMinute: 3,
      durationMinutes: 3,
      keyLines: [
        "Today you're hunters again — but you're not hunting things. You're hunting LIGHT. And light comes in flavors. Four of them.",
        'BRIGHT — full strong light. SHADE — soft cool light. SPARKLE — light BOUNCING off something shiny. And GLOW — light coming THROUGH something thin.',
        "Four lights. Find one of each. The light is the subject now — not the thing it's landing on.",
      ],
      script: [
        ScriptLine.say(
          "Today you're hunters again — but you're not hunting things. You're "
          'hunting LIGHT. And light comes in flavors. Four of them.',
        ),
        ScriptLine.cue('Count:'),
        ScriptLine.say(
          'BRIGHT — full strong light, where everything glows and the shadows '
          'are sharp. SHADE — soft cool light, in the shadow of something. '
          'SPARKLE — light BOUNCING off something shiny. And GLOW — light '
          'coming THROUGH something thin, like a leaf or a cup of water.',
        ),
        ScriptLine.say(
          'Four lights. Find one of each. The light is the subject now — not '
          "the thing it's landing on.",
        ),
      ],
    ),

    // ── 0:06–0:20 — Game: Chase the Light (14 min) ───────────────────
    SessionBeat(
      time: '0:06–0:20',
      kind: BeatKind.game,
      title: 'Game · Chase the Light',
      startMinute: 6,
      durationMinutes: 14,
      keyLines: [
        'BRIGHT first — find something blasted with light, with a hard dark shadow. CLICK.',
        'Four lights. GO.',
        "Lena's holding a leaf to the sun — you can see the VEINS, the light's going right through it!",
      ],
      game: BeatGame(
        name: 'Chase the Light',
        minutes: 14,
        prompt: 'Find four lights — bright, shade, sparkle, glow',
        rules: [
          'BRIGHT first — find something blasted with light, with a hard dark shadow. CLICK.',
          "Now SHADE — go where it's cool and soft. CLICK.",
          'Now SPARKLE — find light bouncing: a window, a puddle, something shiny. CLICK.',
          'Now GLOW — hold a leaf or your hand up to the light and find the light coming THROUGH it. CLICK.',
        ],
      ),
      script: [
        ScriptLine.note(
          '(the shooting beat — outside if you can, or windows + flashlights)',
        ),
        ScriptLine.say(
          'BRIGHT first — find something blasted with light, with a hard dark '
          "shadow. CLICK. Now SHADE — go where it's cool and soft. CLICK. "
          'Now SPARKLE — find light bouncing: a window, a puddle, something '
          'shiny. CLICK. Now GLOW — hold a leaf or your hand up to the light '
          'and find the light coming THROUGH it. CLICK. Four lights. GO.',
        ),
        ScriptLine.cue('Announce:'),
        ScriptLine.say(
          "Sam found SPARKLE — the sun on a puddle, it's a mirror on the "
          'ground!',
        ),
        ScriptLine.say(
          "Lena's holding a leaf to the sun — you can see the VEINS, the "
          "light's going right through it!",
        ),
        ScriptLine.say(
          "Cap's shadow is six feet long because the sun's low — that's a "
          'BRIGHT-light shadow, sharp as a knife.',
        ),
      ],
    ),

    // ── 0:20–0:26 — Looking Together: feel it before you name it ─────
    SessionBeat(
      time: '0:20–0:26',
      kind: BeatKind.cooldown,
      title: 'Looking Together · feel it before you name it',
      startMinute: 20,
      durationMinutes: 6,
      keyLines: [
        "Sit. Look at the BRIGHT photos — everything's loud, colors POP, shadows are hard. Now the SHADE photos — softer, calmer, cooler.",
        "That's a REFLECTION. You photographed the sky by looking DOWN into a puddle.",
        'Light went THROUGH something thin and lit it up from inside — a leaf became a little green window. That warm see-through light is a GLOW.',
      ],
      script: [
        ScriptLine.say(
          "Sit. Look at the BRIGHT photos — everything's loud, colors POP, "
          'shadows are hard. Now the SHADE photos — softer, calmer, cooler. '
          "You can FEEL the difference, right? You don't even need the words "
          'yet — your eyes already know sunshine feels different from shade.',
        ),
        ScriptLine.note('The sparkle ones:'),
        ScriptLine.say(
          "Light BOUNCED off something and into your camera. That's a "
          'REFLECTION. You photographed the sky by looking DOWN into a puddle.',
        ),
        ScriptLine.note('The glow ones:'),
        ScriptLine.say(
          'Light went THROUGH something thin and lit it up from inside — a '
          'leaf became a little green window. That warm see-through light is '
          'a GLOW.',
        ),
      ],
    ),

    // ── 0:26–0:30 — The Twist: the silhouette ────────────────────────
    SessionBeat(
      time: '0:26–0:30',
      kind: BeatKind.frame,
      title: 'The Twist · the silhouette',
      startMinute: 26,
      durationMinutes: 4,
      keyLines: [
        'One more. Point your camera at something with BRIGHT light right behind it — a person in a doorway, a plant on a sunny window. Look at the THING in front. What happened to it?',
        'You turned it into a SILHOUETTE — a black shape with bright light behind.',
        "It's a mystery. Photographers use it to make something ordinary look like a secret.",
      ],
      script: [
        ScriptLine.say(
          'One more. Point your camera at something with BRIGHT light right '
          'behind it — a person in a doorway, a plant on a sunny window. Look '
          'at the THING in front. What happened to it?',
        ),
        ScriptLine.cue('(It went dark, a black shape.)'),
        ScriptLine.say(
          'You turned it into a SILHOUETTE — a black shape with bright light '
          "behind. You can see the shape but not the details. It's a mystery. "
          'Photographers use it to make something ordinary look like a secret.',
        ),
      ],
    ),

    // ── 0:30–0:39 — Drawing: My Best Light (9 min) ───────────────────
    SessionBeat(
      time: '0:30–0:39',
      kind: BeatKind.drawing,
      title: 'Drawing · My Best Light',
      startMinute: 30,
      durationMinutes: 9,
      keyLines: [
        'Three frames. Draw your three best lights. And here — color matters today. Bright light? Press hard, bold colors. Shade? Go soft, light strokes.',
        'Draw the SHADOW as dark as the thing that made it. Draw the glow with the light part in the middle, the dark edges around.',
        "Title: 'Green Window — a GLOW.'",
      ],
      script: [
        ScriptLine.say(
          'Three frames. Draw your three best lights. And here — color matters '
          'today. Bright light? Press hard, bold colors. Shade? Go soft, '
          'light strokes.',
        ),
        ScriptLine.note('Coach:'),
        ScriptLine.say(
          'Draw the SHADOW as dark as the thing that made it. Draw the glow '
          'with the light part in the middle, the dark edges around.',
        ),
        ScriptLine.note('Caption with a word from today:'),
        ScriptLine.say("What's happening in this one?"),
        ScriptLine.response("The light's going through the leaf."),
        ScriptLine.say("Title: 'Green Window — a GLOW.'"),
      ],
    ),

    // ── 0:39–0:44 — The Vocabulary Wall (grows to twelve) ────────────
    SessionBeat(
      time: '0:39–0:44',
      kind: BeatKind.vocab,
      title: 'The Vocabulary Wall · grows to twelve',
      startMinute: 39,
      durationMinutes: 5,
      vocabCards: ['Silhouette', 'Reflection', 'Glow'],
      keyLines: [
        'Twelve coming up. Read me the nine.',
        'Three more — you chased these today.',
        'Twelve words. Three-quarters full.',
      ],
      script: [
        ScriptLine.say('Twelve coming up. Read me the nine.'),
        ScriptLine.cue('They do.'),
        ScriptLine.say('Three more — you chased these today.'),
        ScriptLine.note('[SILHOUETTE]'),
        ScriptLine.say(
          'A dark shape with bright light behind it. You see the shape, not '
          'the details. A mystery.',
        ),
        ScriptLine.response('SILHOUETTE.'),
        ScriptLine.note('[REFLECTION]'),
        ScriptLine.say(
          'Light bouncing off something shiny — a puddle, a window, a spoon. '
          'The world, mirrored.',
        ),
        ScriptLine.response('REFLECTION.'),
        ScriptLine.note('[GLOW]'),
        ScriptLine.say(
          'Light coming THROUGH something thin and lighting it up from inside.',
        ),
        ScriptLine.response('GLOW.'),
        ScriptLine.say('Twelve words. Three-quarters full.'),
      ],
    ),

    // ── 0:44–0:48 — The Closing Circle (using the words now) ─────────
    SessionBeat(
      time: '0:44–0:48',
      kind: BeatKind.closing,
      title: 'The Closing Circle · using the words now',
      startMinute: 44,
      durationMinutes: 4,
      callResponse: 'PHOTOGRAPHERS → SEE',
      keyLines: [
        'Cameras down. Circle. New thing today — when you show me your favorite, use a word from the wall.',
        "Listen to that. You're not just taking photos anymore. You're talking like photographers. You have the WORDS.",
        'What are you? — PHOTOGRAPHERS. What do you do? — SEE.',
      ],
      script: [
        ScriptLine.say(
          'Cameras down. Circle. New thing today — when you show me your '
          'favorite, use a word from the wall.',
        ),
        ScriptLine.cue('Go around:'),
        ScriptLine.response(
          '("Mine\'s a silhouette." "I found a reflection." "Mine glows.")',
        ),
        ScriptLine.say(
          "Listen to that. You're not just taking photos anymore. You're "
          'talking like photographers. You have the WORDS.',
        ),
        ScriptLine.say(
          'Light is the secret ingredient. Change the light, change the '
          'world. Homework: watch the light at your house tonight — at '
          "dinner, at bedtime. Notice when it's hard, when it's soft, when "
          'it glows.',
        ),
        ScriptLine.say('What are you?'),
        ScriptLine.response('PHOTOGRAPHERS.'),
        ScriptLine.say('What do you do?'),
        ScriptLine.response('SEE.'),
        ScriptLine.say('You see the LIGHT now. Go, photographers.'),
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
        'Beautiful light today, photographer.',
      ],
      script: [
        ScriptLine.say('Beautiful light today, photographer.'),
        ScriptLine.cue('To each.'),
      ],
    ),

    // ── After they leave (2 min) ─────────────────────────────────────
    SessionBeat(
      time: 'after',
      kind: BeatKind.after,
      title: 'After they leave',
      durationMinutes: 2,
      keyLines: [
        'Note the best three (the green-window leaf, the puddle-sky, the knife-sharp shadow).',
        'Parent message: "Ask your photographer about the silhouette they made."',
        'Twelve words up. Tubes standing. Session 5: they put it ALL together and photograph their own world.',
      ],
      script: [
        ScriptLine.cue(
          'Note the best three (the green-window leaf, the puddle-sky, the '
          'knife-sharp shadow).',
        ),
        ScriptLine.note(
          'Parent message: "Ask your photographer about the silhouette they '
          'made."',
        ),
        ScriptLine.cue('Twelve words up. Tubes standing.'),
        ScriptLine.note(
          'Session 5: they put it ALL together and photograph their own '
          'world.',
        ),
      ],
    ),
  ],
);
