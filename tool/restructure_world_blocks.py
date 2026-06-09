#!/usr/bin/env python3
"""Restructure world_blocks.json from 5 fortnight blocks into 10 weekly worlds,
aligned 1:1 with ten_worlds.json (the canonical journey — "a new world every
week"). Harvests the prototype's long-form day content for the 7 worlds it
covered (renumbered to their weekly slots) and adds 3 authored worlds
(Stories, Music, Time) + the split Dreams/Us environments. Run once:

    python3 tool/restructure_world_blocks.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/curriculum/world_blocks.json"
old = json.loads(SRC.read_text())["blocks"]
me, nature, water, spacedreams, feelingsus = old  # 5 prototype blocks

# Canonical meta from ten_worlds.json (week/id/name/emoji/color must match).
META = [
    (1, "me", "World of Me", "🪞", "#ff6b6b"),
    (2, "stories", "World of Stories", "📚", "#cc5de8"),
    (3, "nature", "World of Nature", "🌿", "#51cf66"),
    (4, "water", "World of Water", "🌊", "#4ABED9"),
    (5, "music", "World of Music", "🎵", "#E0C050"),
    (6, "space", "World of Space", "🚀", "#6B5B95"),
    (7, "dreams", "World of Dreams", "💭", "#B8B8D0"),
    (8, "time", "World of Time", "⏳", "#D4A843"),
    (9, "feelings", "World of Feelings", "💛", "#E07545"),
    (10, "us", "World of Us", "✨", "#e050a0"),
]


def harvest(block, lo, hi):
    """Days lo..hi (1-based inclusive, by ORIGINAL day number) from a block."""
    return [
        {"title": d["title"], "focus": d["focus"]}
        for d in block["days"]
        if lo <= d["day"] <= hi
    ]


# --- The 3 authored worlds (grounded in ten_worlds themes) -------------------
STORIES_DAYS = [
    {"title": "Once Upon a You", "focus": "Every world starts with 'once upon a time.' Today it starts with yours. Each kid says the first line of their own story out loud — 'Once upon a time there was a kid who…'. Play: the story river — one kid starts a tale, the next adds a sentence, it flows around the circle. Name: NARRATIVE. Bridge: a story is just a chain of 'and then'. Question: 'does your day have a plot?'"},
    {"title": "One Word at a Time", "focus": "The one-word story circle: build a whole story with each person adding ONE word. It goes sideways, it gets silly, it somehow holds together. Play it twice. Name: COLLABORATION. Bridge: nobody owns the story; everybody made it. Question: 'who is the author of a story everyone wrote?'"},
    {"title": "The Story Bag", "focus": "Pull 3 random objects from a bag. They MUST all be in your story. A spoon, a key, a feather → invent how they connect. Draw the scene. Play: act out your three-object story for a partner with no words. Name: IMAGINATION. Bridge: every invention was once an impossible combination. Question: 'what's a story only you could tell?'"},
    {"title": "The Background Character", "focus": "Pick any famous story. Now tell it from the side character — the third pig, the wolf's cousin, the kid in the back. Same events, different eyes. Play: retell a class favorite from the 'wrong' character. Name: PERSPECTIVE. Bridge: the villain is the hero of their own story. Question: 'whose story have you only heard one side of?'"},
    {"title": "Story Map", "focus": "Map your story like a place — where it begins, the trouble in the middle, where it lands. Tape the maps up. Best line of the week into the journal. One Sentence: your whole week as a single story sentence. Books on the Shelf. Transition tease: 'Next week the room goes quiet and green — the world that was here long before any story.'"},
]
MUSIC_DAYS = [
    {"title": "The First Language", "focus": "Before there were words, there were songs. No talking for the first 5 minutes — only sounds. Hum hello. Tap your name. Play: body percussion — clap, stomp, pat a rhythm, pass it around the circle, keep it alive. Name: RHYTHM. Bridge: your heart has been keeping a beat your whole life. Question: 'what's the rhythm of this room right now?'"},
    {"title": "Sound Walk", "focus": "Go outside. Eyes closed. 2 minutes. Collect every sound — near, far, made by people, made by the world. Come back and play your 'sound map' as a song. Play: the hum telephone — hum a tune ear to ear, see how it changes by the end. Name: RESONANCE. Bridge: a sound is just air shivering, and your ear turns the shiver into music. Question: 'where does a sound go when it stops?'"},
    {"title": "Make an Instrument", "focus": "Cups, rubber bands, rice in a jar, a row of water glasses tuned by level. Build something that makes a sound on purpose. Tune the water xylophone — 5 glasses, 5 notes, a tiny song. Play: freeze dance — move while the music plays, statue when it stops. Name: PITCH. Bridge: high and low are the same thing moving fast or slow. Question: 'can you draw a sound?'"},
    {"title": "The Room's Song", "focus": "Combine yesterday's instruments into one room band. A steady beat, a melody on top, everyone in. Record it — this is the room's song. Play: call and response — the leader makes a phrase, the room echoes it back. Name: HARMONY. Bridge: many different sounds, made on purpose at the same time, become ONE thing. Question: 'what makes noise turn into music?'"},
    {"title": "Music Friday", "focus": "Play the room's song one more time, loud. Declaration. Each kid names the soundtrack of their week — 'mine was drums, fast and happy.' Best line into the journal. Transition tease: 'Next week the room goes dark — we leave the ground and go up, way up, into the stars.'"},
]
TIME_DAYS = [
    {"title": "The Invisible River", "focus": "You can't see it, hold it, or stop it — but it changes everything. The stillness timer: sit perfectly still and FEEL one minute pass. Was it long or short? Play: guess-the-minute — eyes closed, raise your hand when you think 60 seconds is up. Nobody agrees. Name: DURATION. Bridge: the same minute feels long in a line and short in a game. Question: 'is time the same speed for everyone?'"},
    {"title": "Before and After", "focus": "Bring a baby photo (or draw 'you at 1'). Three panels: who you were, who you are, who you'll be. Play: the slow-motion race — last one to the wall WITHOUT stopping wins (patience as a skill). Name: CHANGE. Bridge: you grew all year and never felt it happen. Question: 'if you can't feel yourself changing, how do you know you did?'"},
    {"title": "The Long Timeline", "focus": "A paper strip across the whole room: your birthday, today, the dinosaurs, the first humans, the first star. See how tiny your strip is next to forever. Play: fast-walk vs slow-walk — who noticed more on the way? Name: SCALE. Bridge: speed makes you miss things; slowness makes you see. Question: 'what are you moving too fast to notice?'"},
    {"title": "Message to the Future", "focus": "Write a letter to yourself for the last day of summer. Seal it. Don't open it. 'This is a message traveling through time — the you who reads it will be different.' Play: the four maps of one spot (morning / noon / now / imagined-night). Name: PATIENCE. Bridge: a seed you plant today is a message to a future you. Question: 'what's worth waiting for?'"},
    {"title": "Time Friday", "focus": "Look back at the timeline. Declaration — has your title changed since Week 1? Avatar evolution: draw your Week-8 self next to your Week-1 self. Best line into the journal. Transition tease: 'Next week we go inward — to the biggest world of all, the one inside you.'"},
]

# arrival / room / soundtrack / keyMoment / transition, per weekly world.
ENV = {
    "me": (
        "Kids walk in to mirrors on every table, a body-outline paper roll on the floor, their name on a journal at their spot. Nothing explained.",
        "Mirrors everywhere. Butcher paper for body tracing. Unlabeled baby photos on a mystery board. The Wall blank, the Shelf empty — waiting to be filled by them.",
        "Quiet. No music Week 1 — the room's own sound (talking, pencils, laughter) IS the soundtrack.",
        "The baby-photo guessing game: a kid sees their baby picture beside their now-picture and feels the 5-year distance that is everything. The room goes quiet for one second. That second is the program landing.",
        "Cover the mirrors. Leave the feelings maps up. Monday: the room fills with words and 'once upon a time' — the world of stories arrives.",
    ),
    "stories": (
        "Books stand open on every table, propped face-out. A 'story bag' of odd objects sits in the circle. One sentence is written on the board: 'Once upon a time…' with the rest blank.",
        "Cozy. Reading nooks, a story-corner rug, paper for story maps. A shelf of picture books turned cover-out. The Wall has a 'what happens next?' strip.",
        "Soft instrumental storytime music, low — the sound of a page turning.",
        "The one-word story circle the moment it 'breaks' into laughter and somehow still makes sense — ten kids realize they wrote something together that none of them planned.",
        "Put the books away. Monday: leaves on the walls, bird sounds, magnifying glasses — the world that was here before any story.",
    ),
    "nature": (
        "The room is different. Leaves taped to the walls, bird sounds playing, magnifying glasses on every table, a potted plant in the center. The mirrors are gone.",
        "Green everywhere. Magnifying glasses at every station. Seed-starter cups (one per kid). A nature table: rocks, sticks, pinecones, feathers, shells. A bug viewer on the shelf.",
        "Forest ambience — birds, wind through trees, distant water. Underneath conversation, not over it.",
        "The seed sprouting. You can't plan the day — but when a kid comes in and the tiny green thing is THERE, the silence, then the shriek, then everyone crowding one cup on a windowsill: 'IT'S GROWING.'",
        "Take down the leaves. Leave the seeds on the windowsill — they carry forward. Monday: the room is blue and everything drips and flows.",
    ),
    "water": (
        "The room is blue. Blue fabric on the walls, cups of water on every table, ocean sounds, a bowl of ice on the nature table.",
        "Blue everywhere. Water stations: cups, funnels, eyedroppers, sponges, food coloring. A clear container in the center. The seeds from Nature still on the windowsill — they need water.",
        "Ocean waves, rain on a window, a stream — deep and slow. The room should feel submerged.",
        "The food-coloring drop in still water — everyone gathered around one clear cup, nobody stirs, the blue blooms outward in silence. 'That's how kindness works. One drop. No pushing.'",
        "Drain the water stations. Keep the water glasses — they're instruments now. Monday: the room fills with sound and the first language, music.",
    ),
    "music": (
        "Found-sound instruments wait on the tables — cups, rubber-band boxes, rice jars, a row of water glasses. A steady beat is already playing low when kids walk in.",
        "Sound stations everywhere. A 'tuned' water xylophone, body-percussion cue cards, a recording spot for the room's song. The Wall asks 'what does this room sound like?'",
        "A simple rhythm bed under everything — the kind your foot taps without deciding to.",
        "The room band's first take that actually LOCKS — a beat, a melody, everyone in at once, and the room hears itself become one sound instead of ten.",
        "Quiet the instruments. Monday: black paper on the windows, glow stars on the ceiling — we leave the ground and go up.",
    ),
    "space": (
        "A dark room. Black paper on the windows, glow stars on the ceiling, flashlights on every table, one lamp glowing in the corner. Kids go 'whoaaa' at the door.",
        "Dark. Glow-in-the-dark stars overhead. Flashlights everywhere. A globe or Earth image. Black paper + white crayons — drawing with light on darkness.",
        "Ambient space sounds — low drones, distant tones, vastness.",
        "The Pale Blue Dot: 'that tiny speck is Earth — everyone you've ever met, on that dot.' Then arms wide outside: 'this is how big you think you are; above you, forever.' The room goes still.",
        "Leave the stars on the ceiling — they stay forever now. Monday: the room softens, pillows appear, and we go inward, to the world you visit every night.",
    ),
    "dreams": (
        "The stars are still up but the room is softer — fabric draped, pillows in the reading corner, sleep masks and dream-journal inserts on the tables.",
        "Soft and dim. The glow stars stay. Pillows, blankets, a 'dream wall' for drawings. Surreal-art supplies — draw the room with everything wrong.",
        "Soft piano, wind chimes, the sound of slow breathing — vast-internal instead of vast-external.",
        "The guided daydream: ten kids, eyes closed under the glow stars — 'in the forest there's a door, you open it…' Thirty seconds of silence while ten imaginations build ten worlds. Then they draw what was behind the door.",
        "Keep the stars. Put away the sleep masks. Monday: a number line crosses the wall and sand timers sit on every table — the world of time.",
    ),
    "time": (
        "A long paper strip runs the length of one wall. Sand timers sit on every table. Old photos of the neighborhood from decades ago are pinned by the door.",
        "Timers everywhere — sand, digital, a big visible room clock. The wall timeline grows all week. A 'before/after' photo board.",
        "A slow, steady tick under everything — calm, not anxious.",
        "Opening a 'message to the future' from earlier in the summer and reading it aloud — the room feels, for one second, the distance between who wrote it and who's listening.",
        "Roll up the timeline (keep it). Monday: the room goes warm — cushions, soft light, the mirrors return — the biggest world, the one inside you.",
    ),
    "feelings": (
        "The room is warm. Fabric draped softly, warm light, the glow stars still overhead, the seeds now full plants. The mirrors from Week 1 return.",
        "Warm tones. Cushions in the circle. Color-mixing cups at the stations. Feeling-body-outline templates. A 'how are you, really?' anonymous wall.",
        "Gentle — a slow heartbeat sound underneath, soft breathing. The room should feel like being held.",
        "The anonymous 'something nobody knows you feel' notes read aloud — the room goes silent, then 'a kid in this room feels these things and we didn't know. Now we do.'",
        "Leave the feelings maps up. Monday: everything comes off the walls and gets rebuilt as a gallery — the last world, ours, together.",
    ),
    "us": (
        "The work of nine worlds is coming off the walls and being reorganized into a museum. Journals lie open to Page 1 beside Page 50. The kids become curators.",
        "A gallery. One best piece per world per kid, mounted and labeled. Room-comparison photos (Day 1 empty / today full). The kids' own hummed anthem on a loop.",
        "The kids' four-note anthem from Music week, played back — their own music, their own room, their own world.",
        "The final Declaration on the last day: a kid holds up their fat, messy journal — 'My name is ___. My title is ___. And this WAS my book.' The room answers: 'We see you.' They're glowing. LUMINOUS. They know the word for it.",
        "There is no next world. The work comes down, the Wall is archived, the journals go home, the stars stay, the seeds stay. Next summer, new kids walk in and see: someone was here before us.",
    ),
}
WORDS = {
    "me": ["UNIQUE", "ENORMOUS", "SHIMMER", "GENTLE", "FIERCE"],
    "stories": ["ONCE", "WEAVE", "HERO", "TWIST", "BEGIN"],
    "nature": ["CANOPY", "HABITAT", "NOCTURNAL", "SYMBIOSIS", "EROSION"],
    "water": ["EVAPORATE", "CURRENT", "TRANSLUCENT", "RIPPLE", "CASCADE"],
    "music": ["RHYTHM", "MELODY", "RESONATE", "HARMONY", "TEMPO"],
    "space": ["CONSTELLATION", "GRAVITY", "ORBIT", "VAST", "STELLAR"],
    "dreams": ["SURREAL", "LUMINOUS", "REVERIE", "DRIFT", "IMAGINE"],
    "time": ["ETERNAL", "FLEETING", "ANCIENT", "PATIENT", "MOMENT"],
    "feelings": ["EMPATHY", "RESILIENT", "TENDER", "ANTICIPATION", "BRAVE"],
    "us": ["TOGETHER", "BELONG", "EPHEMERAL", "INFINITE", "WE"],
}
WALLQ = {
    "stories": [
        "If you could live inside any story, which one would you choose?",
        "Who is the hero of YOUR story?",
        "What's a story only you could tell?",
        "Whose side of the story have you never heard?",
        "How does your story end — or does it?",
    ],
    "music": [
        "If your life had a soundtrack, what would it sound like right now?",
        "What's the most beautiful sound you've ever heard?",
        "Where does a sound go when it stops?",
        "Can you draw a song?",
        "What turns noise into music?",
    ],
    "time": [
        "If you could visit any time — past or future — when would you go?",
        "Is a minute the same length for everyone?",
        "What's the oldest thing you've ever touched?",
        "What's worth waiting for?",
        "If you can't see time, how do you know it's passing?",
    ],
}

worlds = []
day_no = 1
for week, wid, name, emoji, color in META:
    if wid == "me":
        days = harvest(me, 1, 5)
        wallq = me["wallQuestions"][:5]
    elif wid == "stories":
        days, wallq = STORIES_DAYS, WALLQ["stories"]
    elif wid == "nature":
        days = harvest(nature, 11, 15)
        wallq = nature["wallQuestions"][:5]
    elif wid == "water":
        days = harvest(water, 21, 25)
        wallq = water["wallQuestions"][:5]
    elif wid == "music":
        days, wallq = MUSIC_DAYS, WALLQ["music"]
    elif wid == "space":
        days = harvest(spacedreams, 31, 35)
        wallq = spacedreams["wallQuestions"][:5]
    elif wid == "dreams":
        days = harvest(spacedreams, 36, 40)
        wallq = spacedreams["wallQuestions"][5:10]
    elif wid == "time":
        days, wallq = TIME_DAYS, WALLQ["time"]
    elif wid == "feelings":
        days = harvest(feelingsus, 41, 45)
        wallq = feelingsus["wallQuestions"][:5]
    elif wid == "us":
        days = harvest(feelingsus, 46, 50)
        wallq = feelingsus["wallQuestions"][5:10]

    arrival, room, soundtrack, key, trans = ENV[wid]
    numbered = []
    for d in days:
        numbered.append({"day": day_no, "title": d["title"], "focus": d["focus"]})
        day_no += 1
    worlds.append({
        "week": week,
        "id": wid,
        "name": name,
        "emoji": emoji,
        "color": color,
        "arrival": arrival,
        "room": room,
        "soundtrack": soundtrack,
        "words": WORDS[wid],
        "wallQuestions": wallq,
        "keyMoment": key,
        "transition": trans,
        "days": numbered,
    })

assert day_no == 51, f"expected 50 days, got {day_no - 1}"
assert len(worlds) == 10
for w in worlds:
    assert len(w["days"]) == 5, (w["id"], len(w["days"]))
    assert len(w["wallQuestions"]) == 5, (w["id"], len(w["wallQuestions"]))
    assert len(w["words"]) == 5, w["id"]

SRC.write_text(json.dumps({"worlds": worlds}, indent=2, ensure_ascii=False) + "\n")
print(f"Wrote {len(worlds)} weekly worlds, {day_no - 1} days, to {SRC}")
for w in worlds:
    print(f"  wk{w['week']:>2} {w['emoji']} {w['name']:<18} days {w['days'][0]['day']}-{w['days'][-1]['day']}")
