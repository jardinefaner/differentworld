// Through My Eyes — a 3-week / 6-session photography curriculum for
// ages 5-7. Editorial content shipped in the binary (same trajectory
// as the Teacher Toolkit): the curriculum is a Dart const today,
// readable at zero latency, offline-forever; a per-space overrides
// table can layer on later if directors ask to author their own
// sessions.
//
// Each session is a complete day's plan: setup, game, looking-
// together discussion, AI label examples, end ritual, takeaway,
// materials. The Vocabulary Journey is a separate view that surfaces
// which photography terms attach to which session.
//
// Editorial voice MATTERS — these are voice-driven scripts, not bullet
// summaries. The block text is intentional and shouldn't be rewritten
// in code. If a future override-table edit needs to change phrasing,
// the slug stays so the persona's tooling can reference a specific
// session.

import 'package:flutter/material.dart';

/// Stable identifier for a single session — survives reordering and
/// future override-table joins. Format: `'photo.s<number>.<slug>'`.
class PhotoSession {
  const PhotoSession({
    required this.slug,
    required this.number,
    required this.week,
    required this.day,
    required this.title,
    required this.color,
    required this.glyph,
    required this.bigIdea,
    required this.setup,
    required this.gameName,
    required this.gameRules,
    required this.gameDuration,
    required this.lookingTogether,
    required this.aiExamples,
    required this.endRitual,
    required this.takeaway,
    required this.materials,
  });

  final String slug;
  final int number;
  final int week;
  final int day;
  final String title;

  /// Editorial accent for this session — used as a left rail, chip
  /// tint, and underline on the active session number. The 6 colors
  /// form a rainbow progression (red → orange → yellow → amber →
  /// green → magenta) so the journey across weeks reads visually.
  final Color color;

  /// Single-codepoint emoji that sits next to the session title.
  /// Decorative only — every place it renders is wrapped in
  /// ExcludeSemantics so screen readers don't speak it.
  final String glyph;

  /// Italic header paragraph — the "this session is about THIS"
  /// one-liner.
  final String bigIdea;

  /// Free-text instructions for the staff before the kids arrive.
  final String setup;

  /// The game's display name (e.g. "The Click Game"). Always paired
  /// with the 🎮 icon on the surface.
  final String gameName;

  /// Multi-paragraph rules text — full editorial voice, addressed to
  /// the kid ("You have 5 minutes…").
  final String gameRules;

  /// Short string like "5 min shooting + 15 min looking together".
  final String gameDuration;

  /// The "Looking Together" guided discussion. Multi-paragraph; can
  /// contain inline quoted dialogue (`'WHOA! Maya got a CLOSE-UP…'`).
  final String lookingTogether;

  /// Three or so concrete photo → AI-label examples. Each one is a
  /// tappable expandable card on the surface; collapsed by default
  /// so the screen scans tight, expanded reveals the full label and
  /// the vocabulary tags that attach.
  final List<PhotoAiExample> aiExamples;

  /// The wrap-up ritual — what the staff does to close the session.
  final String endRitual;

  /// The session's "what they learned (without knowing they learned
  /// it)" line — surfaced as a featured highlight card.
  final String takeaway;

  /// Plain-prose materials list.
  final String materials;
}

class PhotoAiExample {
  const PhotoAiExample({
    required this.photo,
    required this.label,
    required this.terms,
  });

  /// One-line description of the photo the AI is labeling — the
  /// surface shows this as the collapsed-card title.
  final String photo;

  /// The full AI-voice label that gets read aloud to the class.
  /// Multi-sentence, expressive.
  final String label;

  /// Vocabulary chips that attach to this example.
  final List<String> terms;
}

/// One session's slot in the vocabulary journey view. Mirrors the
/// session order; `terms` lists the words that surface naturally
/// during that session's game.
class VocabStop {
  const VocabStop({
    required this.sessionSlug,
    required this.terms,
    required this.naturalNote,
  });

  final String sessionSlug;
  final List<String> terms;

  /// Italic explanation of HOW the words land at this session — the
  /// "they don't learn these, they hear them while…" voice.
  final String naturalNote;
}

const List<PhotoSession> photoCurriculum = [
  PhotoSession(
    slug: 'photo.s1.click-game',
    number: 1,
    week: 1,
    day: 1,
    title: 'The Click Game',
    color: Color(0xFFFF6B6B),
    glyph: '📸',
    bigIdea:
        'The camera sees what you see. Point at something. Click. '
        "That's it. You're a photographer now.",
    setup:
        'Give each kid a camera (tablet, phone, or disposable). No '
        "instruction. No 'this is how you hold it.' Let them figure "
        'it out. The first 5 minutes will be chaos — selfies, '
        "blurry floors, accidental shots of the ceiling. THAT'S "
        'THE POINT. Those accidents are their first compositions.',
    gameName: 'The Click Game',
    gameRules:
        'You have 5 minutes. Take as many photos as you can. GO! '
        'Timer starts. Kids run around shooting everything. No '
        'right or wrong. When the timer stops: everyone sits down. '
        'We look at photos together on the big screen (or pass '
        'around the device).',
    gameDuration: '5 min shooting + 15 min looking together',
    lookingTogether:
        'Show 2-3 photos from each kid on the screen. For each '
        'photo, the AI label is read aloud by the teacher in a FUN '
        'voice — not like a lecture, like a sports announcer:\n\n'
        "'WHOA! Maya got a CLOSE-UP of her shoe! The camera is "
        'super near the shoe and the background is all blurry — '
        'photographers call that DEPTH OF FIELD! And look — '
        "there's a shadow going this way because the sun is over "
        "THERE!'\n\n"
        "The kids laugh. They don't know they just learned two "
        "terms. They don't need to.",
    aiExamples: [
      PhotoAiExample(
        photo: 'Blurry shot of the ceiling',
        label:
            'Accidental abstract! This is all blur and light — '
            'photographers actually do this ON PURPOSE sometimes. '
            "It's called motion blur. You moved the camera while "
            'clicking. The ceiling became a painting.',
        terms: ['motion blur', 'abstract'],
      ),
      PhotoAiExample(
        photo: "Extreme close-up of a friend's nostril",
        label:
            'EXTREME CLOSE-UP! You got so close you can see the '
            'DETAILS. Photographers call this MACRO. Usually they '
            'photograph flowers and bugs this close. You '
            "photographed a NOSE. That's funnier.",
        terms: ['extreme close-up', 'macro', 'detail'],
      ),
      PhotoAiExample(
        photo: 'Half a face, half cut off',
        label:
            "You cut the face in half! That's actually a cool move "
            '— only showing PART of something. Photographers call '
            "it CROPPING. The part you can't see makes you want to "
            'look more.',
        terms: ['cropping', 'partial framing'],
      ),
    ],
    endRitual:
        'Each kid picks their ONE favorite photo from today. It '
        "gets printed (or shown on screen with their name). 'This "
        "is [name]'s photo.' Clap for each one. They just had "
        'their first exhibition and it lasted 30 seconds.',
    takeaway:
        "The camera is fun. There's no wrong photo. Even the "
        "'mistakes' have cool names.",
    materials:
        '1 camera/device per kid (or 1 per pair), printer or big '
        'screen, timer.',
  ),
  PhotoSession(
    slug: 'photo.s2.scavenger-hunt',
    number: 2,
    week: 1,
    day: 2,
    title: 'The Scavenger Hunt',
    color: Color(0xFFFF8C6B),
    glyph: '🔍',
    bigIdea:
        'Now we point the camera with PURPOSE. Not just clicking '
        'everything — finding specific things. The hunt gives them '
        'a reason to LOOK.',
    setup:
        'Give each kid (or pair) a simple picture card with 6 '
        'things to find and photograph. All visual — no reading '
        'required. Each card has simple drawings of: something '
        'RED, something ROUND, something TINY, something TALL, a '
        'SHADOW, and a FACE (not a person — a face in an object, '
        'like a face in a tree or an outlet).',
    gameName: 'Photo Scavenger Hunt',
    gameRules:
        'Find all 6 things on your card. Photograph each one. You '
        'have 15 minutes. When you find one, bring it back and '
        'show me. I check it off. First team to get all 6 wins… '
        'but everyone wins because every photo is cool.',
    gameDuration: '15 min hunting + 15 min looking together',
    lookingTogether:
        'Go through each category together. Show all the RED '
        "photos side by side. 'Look — Maya found a red door. "
        "Jayden found a red crayon. Ava found red in someone's "
        "shirt. ALL RED but all DIFFERENT.' The AI labels "
        "describe what's happening in each:\n\n"
        "'Jayden's red crayon: this is a STILL LIFE — a photo of "
        'an object sitting still. The crayon is in the CENTER of '
        'the frame. Nice and simple. Photographers call this a '
        "CENTERED COMPOSITION.'\n\n"
        'Then the SHADOW photos — this is where it gets '
        "exciting. 'YOU PHOTOGRAPHED SOMETHING YOU CAN'T TOUCH. "
        "A shadow isn't a thing — it's what happens when light "
        "gets blocked. You just photographed LIGHT.'",
    aiExamples: [
      PhotoAiExample(
        photo: 'A red fire extinguisher on a white wall',
        label:
            'STILL LIFE with strong color contrast! The red POPS '
            'against the white wall. Photographers love when one '
            'color jumps out — they call it a COLOR POP. The '
            'object is right in the middle — CENTERED COMPOSITION.',
        terms: ['still life', 'color contrast', 'color pop', 'centered'],
      ),
      PhotoAiExample(
        photo: "A shadow of the kid's own hand on the ground",
        label:
            'SHADOW PORTRAIT! You photographed yourself without '
            'being IN the picture. Just your shadow. The shadow '
            'is long and stretched because the sun is low. '
            'Photographers use shadows to add MYSTERY — you can '
            'see the shape but not the person.',
        terms: ['shadow', 'self-portrait', 'mystery', 'low sun angle'],
      ),
      PhotoAiExample(
        photo: 'A face found in a tree trunk knot',
        label:
            "You found a FACE where there isn't one! This is "
            'called PAREIDOLIA — when your brain sees faces in '
            "things that aren't faces. Photographers LOVE "
            "hunting for these. You have a photographer's eye.",
        terms: ['pareidolia', 'found objects', "photographer's eye"],
      ),
    ],
    endRitual:
        'Each kid picks their best scavenger hunt photo. Print '
        'it. It goes on the PHOTO WALL — a dedicated wall space '
        'for the 3-week program. Two photos per kid on the wall '
        'now (one from Session 1, one from today).',
    takeaway:
        'Looking for something specific makes you SEE more. The '
        "camera isn't just for clicking — it's for hunting.",
    materials:
        'Cameras, printed scavenger hunt cards (picture-based, '
        'no reading), timer, photo wall space.',
  ),
  PhotoSession(
    slug: 'photo.s3.upside-down',
    number: 3,
    week: 2,
    day: 1,
    title: 'The Upside Down Game',
    color: Color(0xFFFFD93D),
    glyph: '🙃',
    bigIdea:
        "Same world, different angle. The room doesn't change — "
        'YOU change. Get low. Get high. Look through things. The '
        "'different world' in Different World is just THIS world "
        'seen differently.',
    setup:
        'Quick demo: teacher takes a photo of a chair from normal '
        'standing height. Then from the ground looking up. Then '
        "from above looking down. Show all three. 'SAME CHAIR. "
        "THREE DIFFERENT WORLDS.' Kids go 'whoa.' Now it's their "
        'turn.',
    gameName: 'The Upside Down Game',
    gameRules:
        'Pick ONE thing in the room. Photograph it from 5 '
        'DIFFERENT ANGLES. Get on the floor and look UP at it. '
        'Stand on a chair (with help!) and look DOWN at it. Get '
        'super close. Get far away. Look at it through something '
        '(a cup, your fingers, a window). Same thing, five '
        'photos. The crazier the angle, the better.',
    gameDuration: '10 min shooting + 15 min looking + 5 min choosing',
    lookingTogether:
        "Show each kid's 5 photos of the same object in sequence. "
        "The class reacts. 'THAT'S the chair? It looks like a "
        "monster from down here!'\n\n"
        'AI labels now describe ANGLE and PERSPECTIVE:\n\n'
        "'LOW ANGLE — you're looking UP at the chair. This makes "
        'the chair look GIANT and POWERFUL. Photographers use '
        'low angles to make things look important. You just '
        "made a chair look like a throne.'\n\n"
        "'BIRD'S EYE VIEW — you're looking straight DOWN. The "
        'chair looks flat, like a drawing. Everything looks '
        "different from above. Maps are bird's eye view!'",
    aiExamples: [
      PhotoAiExample(
        photo: 'A shoe from ground level, looking up',
        label:
            "WORM'S EYE VIEW! You're seeing this shoe the way an "
            'ANT would see it. It looks HUGE. The sole fills the '
            'whole frame. Low angle makes small things look '
            'powerful. This shoe is a mountain to a bug.',
        terms: ["worm's eye view", 'low angle', 'scale', 'perspective'],
      ),
      PhotoAiExample(
        photo: 'Same shoe from directly above',
        label:
            "BIRD'S EYE VIEW! Now the same shoe looks flat and "
            'small. You can see the whole shape — it looks like '
            'a map of a shoe. Same shoe, completely different '
            'story just from changing where YOUR EYES are.',
        terms: ["bird's eye view", 'top-down', 'flat perspective'],
      ),
      PhotoAiExample(
        photo: 'Shoe photographed through a magnifying glass',
        label:
            'FRAME WITHIN A FRAME! The magnifying glass creates a '
            'circle inside your photo. The shoe inside the circle '
            'is magnified and sharp. The shoe outside the circle '
            'is blurry. You accidentally created a special effect '
            'that photographers use in movies!',
        terms: ['frame within a frame', 'lens distortion', 'focus'],
      ),
    ],
    endRitual:
        'Each kid picks their most SURPRISING angle — the one '
        "that made the class go 'whoa!' Print it. Photo wall "
        'grows. Three photos per kid now.',
    takeaway:
        'You can make anything interesting by changing where you '
        "stand. The world doesn't change. Your eyes change.",
    materials:
        'Cameras, step stools or safe chairs for high angles, '
        'magnifying glasses / cups / frames for shooting through.',
  ),
  PhotoSession(
    slug: 'photo.s4.light-chasers',
    number: 4,
    week: 2,
    day: 2,
    title: 'The Light Chasers',
    color: Color(0xFFF5A623),
    glyph: '☀️',
    bigIdea:
        'Light changes everything. The same thing in sunlight, in '
        'shadow, and in dark looks like three different things. '
        "Today we chase light like it's a character in a story.",
    setup:
        'Start indoors with the lights ON. Each kid photographs '
        'their own hand on the table. Then: lights OFF (use '
        'curtains/blinds). Photograph the same hand. Then: '
        'flashlight on the hand from the side. Three photos. '
        "'SAME HAND. Three completely different photos. What "
        "changed? Not your hand. THE LIGHT.'",
    gameName: 'Light Chasers',
    gameRules:
        'Go outside (or use windows and flashlights). Find 4 '
        'types of light: 1) BRIGHT SUNSHINE — something in full '
        'sun. 2) SHADE — something in shadow. 3) SPARKLE — '
        'something that reflects or shines. 4) GLOW — something '
        'where light comes THROUGH it (a leaf, a cup of water, a '
        'thin fabric). Photograph each one.',
    gameDuration: '12 min chasing + 15 min looking + 5 min choosing',
    lookingTogether:
        'Show the SUNSHINE photos: everything is bright, shadows '
        'are sharp, colors are strong. Show the SHADE photos: '
        'softer, cooler, calmer. Show the SPARKLE photos: '
        "'You found light BOUNCING! That's called REFLECTION.' "
        "Show the GLOW photos: 'Light is going THROUGH this — "
        "that's called TRANSLUCENCE. The leaf is like a green "
        "window.'\n\n"
        'This is the session where kids start to FEEL the '
        'difference before they know the words. They can see '
        'that sunshine photos feel different from shade photos. '
        'The AI labels give the why.',
    aiExamples: [
      PhotoAiExample(
        photo: 'A dandelion in full sun, sharp shadow beneath it',
        label:
            'FULL SUN! Hard light from directly above. See that '
            'sharp, dark shadow right under the dandelion? '
            "That's called a HARD SHADOW — it happens when the "
            'light source is strong and direct. The yellow of '
            'the dandelion is super bright because sunlight '
            'makes colors POP.',
        terms: ['hard light', 'hard shadow', 'direct sun', 'saturated color'],
      ),
      PhotoAiExample(
        photo: 'A hand holding a leaf up to the sun',
        label:
            'BACK-LIT LEAF! The light is coming THROUGH the leaf '
            '— you can see the VEINS inside! This is called '
            'TRANSLUCENCE. And because the light is behind the '
            "leaf, YOUR hand is dark — that's a SILHOUETTE. One "
            'photo, two cool things happening!',
        terms: ['backlighting', 'translucence', 'silhouette'],
      ),
      PhotoAiExample(
        photo: 'A puddle reflecting the sky',
        label:
            'REFLECTION! The puddle is like a mirror on the '
            'ground. You photographed the SKY by looking DOWN. '
            "That's a trick photographers love — finding the "
            'world reflected in unexpected places. Water, '
            'windows, sunglasses, spoons — all mirrors if you '
            'look.',
        terms: ['reflection', 'found mirror', 'unexpected perspective'],
      ),
    ],
    endRitual:
        'Each kid picks their best light photo. But this time: '
        'they tell the class ONE THING about it using a word '
        "they learned today. 'My photo has a SILHOUETTE.' 'I "
        "found a REFLECTION.' They're using the language now. "
        'Print it. Photo wall: four photos per kid.',
    takeaway:
        'Light is the secret ingredient. Change the light, '
        'change the world.',
    materials:
        'Cameras, flashlights (2-3), access to outdoor space '
        'with sun and shade, thin fabric or leaves for '
        'translucence.',
  ),
  PhotoSession(
    slug: 'photo.s5.my-different-world',
    number: 5,
    week: 3,
    day: 1,
    title: 'My Different World',
    color: Color(0xFF51CF66),
    glyph: '🌍',
    bigIdea:
        "Everything you've learned — clicking, hunting, angles, "
        'light — comes together. Today you photograph YOUR '
        'world. Not assignments. Not games. YOUR eyes, YOUR '
        'world, YOUR story. This is your photo essay.',
    setup:
        'No cards. No scavenger hunt. No rules. Just one prompt: '
        "'Photograph your world. What does YOUR life look like "
        'through a camera? Your friends, your shoes, your snack, '
        'your favorite spot, the crack in the sidewalk you always '
        'step on, the sky right now. 10 photos. Your photos. '
        "Your world.'",
    gameName: 'My World in 10 Photos',
    gameRules:
        'Take exactly 10 photos. Not 9, not 11. TEN. Of anything '
        'you want. The only rule: each photo must be something '
        "that matters to YOU. 'If someone looked at these 10 "
        'photos, they should know who you are without meeting '
        "you.' (For 5-year-olds, simplify: 'Take 10 photos of "
        "things you LOVE.')",
    gameDuration: '15 min shooting + 15 min curating + gallery prep',
    lookingTogether:
        'This session is different. Instead of the teacher '
        'showing photos on a big screen, each kid lays their 10 '
        'photos out on a table (printed quickly or displayed on '
        'a device). The other kids WALK AROUND and look, like a '
        'real gallery.\n\n'
        'The AI labels are printed small and placed next to '
        'each photo. But this time, the kids read them (with '
        "help) THEMSELVES. They're recognizing the words now: "
        "'It says close-up! I DID a close-up!'\n\n"
        'Then: each kid picks their BEST 3 from the 10. These '
        '3 will be in the final gallery tomorrow.',
    aiExamples: [
      PhotoAiExample(
        photo: "Kid's best friend laughing, blurry in motion",
        label:
            "CANDID PORTRAIT with motion blur! Your friend didn't "
            "know you were taking this — that's what makes it "
            'REAL. The blur on their hands shows they were '
            'moving. Their eyes are sharp but everything else is '
            'soft. This photo FEELS like laughing. You captured '
            'a FEELING, not just a face.',
        terms: ['candid', 'motion blur', 'emotion capture', 'authenticity'],
      ),
      PhotoAiExample(
        photo: "Kid's own feet on a puddle-wet sidewalk",
        label:
            'SELF-PORTRAIT without your face! Just your shoes '
            'and the wet sidewalk. LOW ANGLE — the camera is '
            'almost on the ground. The puddle reflects a little '
            "bit of sky. This photo says: 'I was HERE. This is "
            "where I stand.' Simple and personal.",
        terms: [
          'feet-first self-portrait',
          'low angle',
          'personal perspective',
          'sense of place',
        ],
      ),
      PhotoAiExample(
        photo: 'A half-eaten snack on a napkin',
        label:
            'STILL LIFE! Photographers have been photographing '
            "food for centuries. This is REAL though — it's your "
            'actual snack, half-eaten, on a crumpled napkin. The '
            'crumbs tell a story: someone was hungry. The '
            'afternoon light makes it warm. This is DOCUMENTARY '
            'PHOTOGRAPHY — photographing life exactly as it is.',
        terms: [
          'still life',
          'documentary',
          'natural light',
          'narrative detail',
        ],
      ),
    ],
    endRitual:
        'Each kid has chosen their best 3. The teacher helps '
        'them write or dictate a title for each photo. Not a '
        "description — a TITLE. 'My Best Friend Laughing.' "
        "'Where I Stand.' 'My Snack.' They're curating. They're "
        "editing. They don't know those are professional skills. "
        "They're just picking their favorites.",
    takeaway:
        'Your eyes are unique. Nobody else would take these 10 '
        "photos. That's what makes you a photographer — not the "
        'camera, but what you choose to point it at.',
    materials:
        'Cameras, quick print capability or devices for display, '
        'table space for mini galleries, paper for titles.',
  ),
  PhotoSession(
    slug: 'photo.s6.gallery-show',
    number: 6,
    week: 3,
    day: 2,
    title: 'The Gallery Show',
    color: Color(0xFFE050A0),
    glyph: '🖼️',
    bigIdea:
        'You took photos. You learned words. You chose your '
        'best ones. Now you show them to the people you love. '
        'This is not a school project. This is YOUR exhibition. '
        'You are a photographer and this is your show.',
    setup:
        'Before the kids arrive: set up the photo wall as a real '
        "gallery. Each kid's 3 best photos (from Session 5) are "
        'printed and mounted on colored paper. The AI label is '
        'printed small underneath each one — like a real museum '
        "placard. The kid's name and the photo's title are "
        'handwritten. The room looks different today. It looks '
        'important.',
    gameName: 'The Gallery Show',
    gameRules:
        'No game today. Today is the real thing. Families are '
        "invited (or other classes, or staff — anyone who'll "
        'come). Each kid stands next to their 3 photos. When '
        "someone walks up, the kid says: 'This is my photo. "
        "It's called [title].' That's it. If they want to say "
        "more, they can. If they're shy, the photos speak.",
    gameDuration: 'Full session — setup, rehearsal, show',
    lookingTogether:
        'The show IS the looking together. Families walk around. '
        'They read the AI labels and discover that their '
        "5-year-old took a photo with 'Rembrandt lighting' or "
        "'negative space' or 'documentary perspective.' The "
        "parent doesn't need to know what those mean. They just "
        "need to see that their kid's photo has MUSEUM WORDS "
        "underneath it. That's the magic.\n\n"
        "The moment: a parent crouches down and says 'You took "
        "THIS?' and the kid says 'Yeah. It's a candid.' And the "
        'parent has no idea what that means but the kid does.',
    aiExamples: [
      PhotoAiExample(
        photo: 'The whole gallery wall',
        label:
            'This is not one photographer — this is TEN. Ten '
            'people, ages 5-7, who two weeks ago had never held a '
            'camera with intention. Six sessions. Six games. And '
            'now: an exhibition with titles, placards, and '
            'professional vocabulary they earned from their own '
            'photos. Every word on these labels came from '
            'something THEY shot. Nothing was taught in advance. '
            'Everything was discovered.',
        terms: ['exhibition', 'body of work', 'collective vision'],
      ),
    ],
    endRitual:
        'After the show: each kid gets to TAKE HOME their 3 '
        'printed photos with the AI labels. They also get a '
        "small 'certificate' (could be handwritten): '[Name] — "
        "Photographer. You have a photographer's eye. You know "
        'what [3 terms they used most] mean because you '
        "DISCOVERED them. Keep looking. Keep clicking.'\n\n"
        'The certificate lists their personal terms — the AI '
        "words that appeared most in THEIR photos. Maya's "
        "might say 'close-up, candid, warm light.' Jayden's "
        "might say 'low angle, silhouette, motion blur.' Their "
        'vocabulary is their fingerprint.',
    takeaway:
        "You are a photographer. Not 'you're learning "
        "photography.' Not 'someday you'll be a photographer.' "
        'RIGHT NOW. These photos on this wall are proof.',
    materials:
        'Printed photos mounted on colored paper, printed AI '
        'labels, wall space, invitations sent home Session 5, '
        'certificates (handwritten or printed).',
  ),
];

const List<VocabStop> vocabJourney = [
  VocabStop(
    sessionSlug: 'photo.s1.click-game',
    terms: ['close-up', 'depth of field', 'motion blur', 'macro', 'cropping'],
    naturalNote:
        "They don't learn these. They HEAR them as fun "
        'descriptions of their accidents.',
  ),
  VocabStop(
    sessionSlug: 'photo.s2.scavenger-hunt',
    terms: ['still life', 'color pop', 'shadow', 'pareidolia', 'centered'],
    naturalNote:
        'They hunt for things. The words attach to what they '
        'found.',
  ),
  VocabStop(
    sessionSlug: 'photo.s3.upside-down',
    terms: [
      'low angle',
      "bird's eye",
      "worm's eye",
      'frame within frame',
      'perspective',
    ],
    naturalNote:
        'They got on the ground and climbed chairs. The words '
        'describe what their BODY did.',
  ),
  VocabStop(
    sessionSlug: 'photo.s4.light-chasers',
    terms: [
      'hard light',
      'silhouette',
      'backlighting',
      'reflection',
      'translucence',
    ],
    naturalNote:
        'They chased light like a game. The words name what the '
        'light did.',
  ),
  VocabStop(
    sessionSlug: 'photo.s5.my-different-world',
    terms: [
      'candid',
      'documentary',
      'self-portrait',
      'curating',
      'personal perspective',
    ],
    naturalNote: 'They shot THEIR world. The words honor their choices.',
  ),
  VocabStop(
    sessionSlug: 'photo.s6.gallery-show',
    terms: ['exhibition', 'body of work', "photographer's eye"],
    naturalNote: 'They showed their work. The words make it official.',
  ),
];

PhotoSession? findSessionBySlug(String slug) {
  for (final s in photoCurriculum) {
    if (s.slug == slug) return s;
  }
  return null;
}

/// The per-child SHOOTING minutes for a session — the countdown each kid gets
/// on their locked turn. Read from the session's free-text [PhotoSession.gameDuration]
/// (e.g. `'5 min shooting + 15 min looking together'` → 5), taking the FIRST
/// `<n> min` it finds (always the shooting figure in these scripts). Defaults
/// to 5 when the string can't be parsed or the number falls outside a sane
/// 1..20 range, so a malformed override can never hand a child a 0- or
/// 90-minute turn.
int sessionShootMinutes(PhotoSession s) {
  final match = RegExp(r'(\d+)\s*min').firstMatch(s.gameDuration);
  final mins = match == null ? null : int.tryParse(match.group(1)!);
  if (mins == null || mins < 1 || mins > 20) return 5;
  return mins;
}
