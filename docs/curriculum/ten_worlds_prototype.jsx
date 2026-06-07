// CANONICAL CURRICULUM — "If You Built a World" (10 weeks · 10 worlds · 1 Different World)
//
// Source of truth for ALL themed-world content (see docs/WORLD.md). The
// user authored this as a working React prototype on 2026-06-07. The Dart
// catalog (lib/features/action_words/themed_worlds.dart) is generated FROM
// this — when they diverge, this wins. Verbatim capture; do not edit the
// content to fit code, edit the code to fit this.
//
// Structure per world: week, name, emoji, color, tagline, question, and the
// ten facets (people, culture, map, tools, language, food, music, rules,
// problems, dreams) + verbs (3 featured, from the 12 Action Words) +
// activities (6-8 concrete).

import { useState } from "react";

const WORLDS = [
  {
    week: 1,
    name: "World of Me",
    emoji: "🪞",
    color: "#ff6b6b",
    tagline: "Before you build a world, you have to know who's building it.",
    question: "If you were a world, what would be inside you?",
    people: "Population: 1. Just you. But you're a whole country. Your heart is the capital city. Your hands are the workers. Your brain is the library. Your stomach is the kitchen. Your feet are the roads.",
    culture: "The culture is your habits. What do you do every morning? That's your tradition. What makes you laugh? That's your entertainment. What scares you? That's your monster. What makes you feel safe? That's your castle.",
    map: "Draw a map of yourself. Head = the thinking mountains. Chest = the feeling ocean. Arms = the reaching highways. Legs = the moving rivers. Belly = the hunger volcano. Label everything. This is the map of your country.",
    tools: "Your five senses. Eyes are binoculars. Ears are satellites. Nose is a weather detector. Hands are builders. Tongue is a food scientist. What's your strongest tool? That's your superpower.",
    language: "Your name. Your title. Your declaration. 'My name is ___. My title is ___. And this is my world.' That's the national anthem. Say it every morning.",
    food: "What would your world eat? If you were a country, what's the national dish? Draw it. Name it. Is it sweet or salty? Hot or cold? Does everyone eat it or just the brave ones?",
    music: "What does your world sound like? Hum your national anthem — just 4 notes. Repeat it. That's your song. Nobody else has that melody.",
    rules: "Three rules for your world. You pick them. They can be anything. 'Everyone has to dance at lunch.' 'No yelling except outside.' 'You have to say hi to everyone.' Your rules, your world.",
    problems: "Every world has a problem. What's yours? 'Sometimes I feel invisible.' 'Sometimes I'm too loud.' 'Sometimes I don't know what to say.' Name it. That's what your world is working on. Not fixing. Working on.",
    dreams: "If your world could have one wish, what would it be? Not a toy. Not a thing. A FEELING. 'I wish everyone felt brave.' 'I wish nobody felt alone.' That wish goes on the Wall.",
    verbs: "SHINE (introduce yourself), WATCH (observe yourself in a mirror for 60 seconds), BUILD (make the body map)",
    activities: [
      "Body map: trace your body on butcher paper, label the countries inside you",
      "Mirror minute: look at yourself for 60 seconds without laughing — harder than you think",
      "National anthem: hum 4 notes, repeat, teach it to a partner",
      "Three rules: write or draw your world's three laws",
      "Baby photo match: guess which baby is which classmate",
      "Fingerprint art: press your thumb in ink — that pattern exists nowhere else in the universe",
    ],
  },
  {
    week: 2,
    name: "World of Stories",
    emoji: "📚",
    color: "#cc5de8",
    tagline: "Every world starts with 'once upon a time.' This one starts with yours.",
    question: "If you could live inside any story, which one would you choose?",
    people: "Heroes, villains, sidekicks, narrators, and the people in the background nobody talks about. Who are the background characters in YOUR story? The person who makes your lunch. The person who drives the bus. They have stories too.",
    culture: "The culture is how stories get told. Some worlds tell stories around fires. Some tell them in books. Some tell them in drawings. Some tell them by dancing. How does YOUR world tell stories?",
    map: "Draw the map of a story. Every story has: a HOME (where it starts), a ROAD (the journey), a DARK PLACE (where it gets scary), and a NEW HOME (where you end up, changed). Draw all four. That's every story ever told.",
    tools: "Words, pictures, voices, and hands. A storyteller needs all four. Today your tool is: whichever one you're best at. Some kids draw the story. Some tell it. Some act it out. All count.",
    language: "Once upon a time. The end. Suddenly. But then. Meanwhile. These are the magic words of stories. Learn five story words this week. Use them.",
    food: "What does the character in your story eat? Draw their meal. Is it magical food? Is it regular food? The meal tells you about the character.",
    music: "Every story has a soundtrack. Happy moments sound like ___. Scary moments sound like ___. Make the sounds with your mouth. That's the score.",
    rules: "Stories have rules: the hero has to try 3 times before they succeed. Bad things happen in the middle, not the end. The ending has to be different from the beginning. Something has to CHANGE.",
    problems: "Every story needs a problem or there's no story. What's the problem in YOUR story? Write it on a sticky note. That's the engine of the whole thing.",
    dreams: "How does your story end? Not 'happily ever after.' Specifically. What CHANGED? The character was scared and now they're brave. The character was alone and now they have a friend. The change IS the dream.",
    verbs: "SPARK (start a story from one sentence), ECHO (continue someone else's story), FLOW (don't stop the story river — keep drawing/talking/acting)",
    activities: [
      "Story river: tape 3 pages together, draw a continuous story left to right, don't stop",
      "One-word story circle: each kid adds one word, build a story as a group",
      "Story bag: pull 3 random objects from a bag, make a story with all 3",
      "Act it out: groups of 3, one story, no words, just bodies",
      "Background character: pick a fairy tale, tell the story from the background character's view",
      "Story map: draw HOME → ROAD → DARK PLACE → NEW HOME for your own life so far",
    ],
  },
  {
    week: 3,
    name: "World of Nature",
    emoji: "🌿",
    color: "#51cf66",
    tagline: "Everything outside was here before us and will be here after us.",
    question: "If the trees could talk, what would they say about us?",
    people: "The people are not people. The citizens are trees, bugs, birds, worms, fungi, moss, lichen, wind, rain, and dirt. They've been running this world for billions of years without our help.",
    culture: "Nature's culture is cycles. Spring, summer, fall, winter. Seed, sprout, flower, fruit, seed again. Sunrise, sunset. Tide in, tide out. Nothing in nature happens once. Everything repeats.",
    map: "Walk outside. Draw a map of everything within 50 steps of the door. Every tree, every crack, every puddle, every bug. The map should take the whole week to finish because you keep discovering things you missed.",
    tools: "Magnifying glass, ears, bare feet, patience. Nature's tools are slow. You can't rush a bug. You can't speed up a cloud. The tool is WAIT.",
    language: "Learn 5 nature words: CANOPY (the ceiling of leaves), HABITAT (where something lives), NOCTURNAL (awake at night), MIGRATION (traveling far), SYMBIOSIS (two things helping each other). Use each 3 times.",
    food: "Everything eats something. The bug eats the leaf. The bird eats the bug. The cat eats the bird. Draw the chain. Where are YOU in the chain? What did you eat today and what ate THAT?",
    music: "Go outside. Close eyes. Listen for 2 minutes. The birds, the wind, the insects, the distant traffic. That's nature's music. It never stops and it's never the same twice.",
    rules: "Nature's rules: everything is connected, nothing is wasted, everything changes, and the slow things always outlast the fast things.",
    problems: "The world of nature has one big problem: us. Not as a guilt trip — as a real question. 'What do humans do that nature didn't ask for?' Honest answers. Sticky notes on the wall.",
    dreams: "If nature could make one wish, what would it be? Ask the tree. Ask the worm. Ask the river. Their answers are different from yours. That's the point.",
    verbs: "WATCH (bug safari — observe one creature for 2 full minutes), LISTEN (sound map — eyes closed, draw where sounds come from), WAIT (plant a seed, wait, wait, wait)",
    activities: [
      "Bug safari: find a bug, watch it for 2 minutes, draw what it does",
      "Sound map: sit still outside, map every sound with directional arrows",
      "50-step map: map everything within 50 steps of the door",
      "Food chain: draw what you ate, what that ate, what THAT ate",
      "Seed plant: plant it Day 1, measure every day, patience is visible",
      "Leaf press: collect, press between books, tape in journal after 3 days",
      "Bark rubbing: hold paper against a tree, rub with crayon, the texture appears",
      "Cloud watch: lie down, 3 minutes, name every shape",
    ],
  },
  {
    week: 4,
    name: "World of Water",
    emoji: "🌊",
    color: "#4ABED9",
    tagline: "The water in your cup is older than the dinosaurs.",
    question: "If you were a drop of water, where would your journey take you?",
    people: "The citizens are: rivers, lakes, oceans, rain, ice, clouds, tears, puddles, dewdrops, and the water inside you. You are 60% water. You are mostly a citizen of this world already.",
    culture: "Water's culture is flow. It never fights obstacles — it goes around them. It never rushes — it arrives when it arrives. It never stays one shape — it becomes the container. Water's culture is the opposite of force.",
    map: "Map the water in your building. Where does it come in? (Faucets.) Where does it go out? (Drains.) Where does it hide? (Pipes in the walls.) Where does it collect? (Puddles, cups, toilets.) The invisible plumbing is the map.",
    tools: "Cups, funnels, sponges, eyedroppers, ice cube trays, spray bottles. Every tool is a way to MOVE water, HOLD water, CHANGE water, or RELEASE water.",
    language: "EVAPORATE (water disappears into air), CONDENSE (air becomes water drops), EROSION (water slowly wears away rock), CURRENT (water that moves in one direction), TRANSLUCENT (light goes through it). Five water words. Use each 3 times.",
    food: "Everything needs water to grow, cook, or survive. Make a snack that involves water: wash fruit, mix juice, freeze popsicles. Watch water become food.",
    music: "Fill 5 glasses with different amounts of water. Tap them with a spoon. Different notes. You made a water xylophone. Play a song.",
    rules: "Water's rules: always flow downhill, take the shape of whatever holds you, never disappear — just change form, and be patient enough to carve a canyon.",
    problems: "Some places have too much water (floods). Some don't have enough (drought). Some have dirty water. What would you do if you turned on the faucet and nothing came out? This is real for millions of kids.",
    dreams: "If water could dream, it would dream of being clean. Draw the cleanest water you can imagine. Where is it? What does it taste like? Who drinks it?",
    verbs: "FLOW (pour water through an obstacle course of cups and funnels), SOLVE (how do you move water from here to there without spilling?), ECHO (make a splash, listen to the echo)",
    activities: [
      "Water journey: map a drop of water from cloud to faucet to drain to ocean to cloud again",
      "Ice race: give each kid an ice cube on a plate — who can melt it fastest? How?",
      "Sink or float: 10 objects, predict, test, record",
      "Water xylophone: 5 glasses, different levels, play a tune",
      "Sponge relay: carry water across the room in a sponge without dripping",
      "Rain gauge: cup outside, measure after rain, chart it",
      "Evaporation watch: put water on the sidewalk, trace the outline, check every 30 min — it's shrinking",
      "Water inside you: 'You're 60% water. Where is it? Your blood, your spit, your tears, your sweat.'",
    ],
  },
  {
    week: 5,
    name: "World of Music",
    emoji: "🎵",
    color: "#E0C050",
    tagline: "Before there were words, there were songs. Music is the first language.",
    question: "If your life had a soundtrack, what would it sound like right now?",
    people: "The citizens are: rhythm (the heartbeat), melody (the voice), harmony (friends singing together), silence (the pause that makes the next note matter), and noise (the beautiful chaos of everything at once).",
    culture: "Music's culture is call and response. One person sings, others answer. One drum beats, others join. Nothing in music happens alone. Even a solo is a conversation between the player and the silence.",
    map: "Map the sounds in your life. Morning sounds (alarm, birds, breakfast). School sounds (voices, pencils, chairs). Night sounds (tv, crickets, breathing). Draw the map as a timeline from wake-up to sleep. That's your sound landscape.",
    tools: "Your body IS the instrument. Clap. Stomp. Snap. Hum. Whistle. Tap your chest. Slap your thighs. Click your tongue. You have ten instruments before you touch a single object.",
    language: "RHYTHM (a pattern that repeats), TEMPO (how fast or slow), MELODY (the tune you hum), HARMONY (two sounds that go together), CRESCENDO (getting louder). Five music words.",
    food: "Music and food overlap: you can BEAT eggs and BEAT a drum. You WHISK batter and WHISK a brush on a cymbal. What other cooking words are also music words? Make a list. The worlds are connected.",
    music: "Create a 4-beat rhythm. Teach it to a partner. They add to it. Teach the combined rhythm to another pair. By the end you have a class composition built from everyone's contribution. Nobody composed it. Everyone composed it.",
    rules: "Music's rules: the silence between notes matters as much as the notes, the rhythm holds everything together, you can't make a mistake if you keep playing, and loud isn't better — right is better.",
    problems: "Some sounds hurt (yelling, sirens, scary noise). Some sounds heal (a lullaby, a whisper, rain). What's the difference? Volume? Tone? Intention? The same hand can slap or applaud. The difference is the feeling behind the force.",
    dreams: "If you could hear one sound for the rest of your life, what would it be? Not a song — a SOUND. Waves? A purr? Your mom's laugh? Your own heartbeat? That sound is your dream. Draw it as a wave.",
    verbs: "ECHO (repeat a rhythm, then change it), LISTEN (close eyes, identify 5 sounds in 60 seconds), PLAY (free rhythm — make noise with anything for 2 minutes, no rules)",
    activities: [
      "Body percussion: learn a 4-clap pattern, teach it, layer it, perform it",
      "Sound walk: walk the building, collect sounds, recreate them with your body",
      "Water xylophone: different water levels = different notes = a song",
      "Freeze dance: music plays = dance, music stops = freeze for 5 seconds",
      "Hum telephone: hum a melody around the circle, see how it changes",
      "Drum circle: everyone taps something, one person leads, the rest layer in",
      "Emotion soundtrack: 'happy sounds like ___' 'scared sounds like ___' make each one",
      "Singing names: sing your name instead of saying it, everyone sings it back",
    ],
  },
  {
    week: 6,
    name: "World of Space",
    emoji: "🚀",
    color: "#6B5B95",
    tagline: "Everything you've ever known is on one tiny dot floating in infinite darkness.",
    question: "If an alien visited your classroom, what would confuse them most?",
    people: "The citizens are: stars (who shine alone in the dark), planets (who orbit something bigger), moons (who reflect someone else's light), comets (who visit once and disappear), and black holes (who hold everything together invisibly).",
    culture: "Space culture is distance and patience. The light from the nearest star took 4 YEARS to reach you. The message you send takes time to arrive. Space teaches you that not everything is instant. Some things travel for years before they land.",
    map: "You can't draw a map of space because it's infinite. So draw a map of what you CAN see: the sun, the moon, the stars you notice at night. That's YOUR sky map. Nobody else sees the sky from your exact spot on earth.",
    tools: "Telescopes (to see far), rockets (to go far), spacesuits (to survive far), and math (to calculate far). But the biggest tool is imagination — because nobody's been to most of space. We imagine it first and go later.",
    language: "ORBIT (going around something), GRAVITY (what holds you down), CONSTELLATION (a pattern of stars), LIGHTYEAR (how far light travels in one year), ECLIPSE (when one thing blocks another). Five space words.",
    food: "Astronaut food. Everything is dried, sealed, and squeezed from pouches. No crumbs — they float and break machines. What would YOU eat in space? Draw your space meal. Eat snack from a pouch today (applesauce squeezers).",
    music: "Space is silent. Sound can't travel in a vacuum. But if you COULD hear the planets, what would they sound like? Jupiter would be deep and rumbling. Mercury would be fast and high. Make the sounds. That's your space symphony.",
    rules: "Space rules: everything orbits something, gravity always wins, the bigger you are the more things orbit you, and the darkness between stars is not empty — it's full of things we haven't found yet.",
    problems: "Space is lonely. The distances are so vast that signals take years. What if you sent a message and the answer didn't arrive until you were grown up? Write a message to the future you. Seal it. Open it at the end of summer.",
    dreams: "If you could name a star, what would you call it? Not a person's name. A FEELING name. Star of Courage. Star of Laughter. Star of Patience. Name your star. Put it on the ceiling. That's your constellation.",
    verbs: "SHINE (name your star, make it visible), WAIT (time a minute of darkness and silence — that's what space feels like), SPARK (invent an alien — draw it, name it, give it 3 habits)",
    activities: [
      "Alien invention: draw an alien, name it, give it 3 habits from the verb cards",
      "Star naming: name a star after a feeling, put it on the ceiling",
      "Planet walk: walk the distance between planets scaled to the yard (earth to sun = 10 steps, earth to jupiter = 52 steps)",
      "Message to the future: write a note to yourself, seal it, open last day of summer",
      "Gravity test: drop 10 objects from the same height — do they all land at the same time?",
      "Dark room: flashlight is the sun, ball is the earth, see how shadows work = eclipse",
      "Space food taste test: eat snack from squeeze pouches like astronauts",
      "Constellation creation: connect dots on black paper with white crayon, name the pattern",
    ],
  },
  {
    week: 7,
    name: "World of Dreams",
    emoji: "💭",
    color: "#B8B8D0",
    tagline: "The world you visit every night when you close your eyes.",
    question: "Where do you go when you're asleep?",
    people: "The citizens of dreams are: the you that flies, the you that talks to animals, the you that's in a house that's your house but also not your house. Dream people are familiar and strange at the same time. That's what makes them dreams.",
    culture: "Dream culture has no rules about time. You can be at school and then instantly at the beach. You can be 5 years old and also an adult. Things that don't make sense together make perfect sense in dreams. The culture is: impossible is normal.",
    map: "Draw a map of a dream you had. If you can't remember one, draw a map of a dream you WANT to have. Dream maps don't have straight roads. They have swirls, jumps, and doors that lead to unexpected places.",
    tools: "Imagination, memory, feelings, and fear. Dreams use your real life as material and remix it into something new. The tool is: everything you experienced today becomes tonight's raw material.",
    language: "SURREAL (like a dream — real and unreal at the same time), SUBCONSCIOUS (the part of your brain that thinks while you sleep), LUCID (knowing you're dreaming while you dream), SYMBOL (when one thing stands for another), NIGHTMARE (a dream that scares you but can't hurt you). Five dream words.",
    food: "Have you ever eaten in a dream? What did it taste like? Most people can't taste in dreams. Draw a dream meal — food that doesn't exist. Cloudcake. Rainbow soup. Invisible toast that fills you up anyway.",
    music: "Dream music is the sound of things that don't make sound. The color blue humming. A tree singing. Your house breathing. Make those sounds with your voice. That's dream music.",
    rules: "Dream rules: anything can happen, you can't die (you always wake up), time isn't real, and the scariest dreams teach you the most about what you're afraid of. Nightmares are brave dreams.",
    problems: "Some dreams are scary. That's real. You can't control them. But you CAN talk about them. 'I had a dream where ___.' Say it out loud. Out loud it becomes a story. Stories are less scary than secrets.",
    dreams: "The dream of a dream is to be remembered. Most dreams disappear when you wake up. This week: keep a dream journal. First thing every morning, draw or describe what you dreamed. Catch the dream before it fades.",
    verbs: "SPARK (invent a dream — draw a place that doesn't exist), FLOW (dream river — one long drawing with no logic, just flow), ECHO (retell someone else's dream in your own way)",
    activities: [
      "Dream journal: every morning, draw or describe last night's dream before it fades",
      "Dream map: draw a map of a dream — no straight lines, no logic, just feelings",
      "Impossible meal: draw food that doesn't exist and name it",
      "Dream sharing circle: 'I had a dream where ___' — no judgments, just listening",
      "Surreal drawing: draw your classroom but everything is wrong — chairs on ceiling, fish in the air",
      "Dream creature: combine 3 real animals into 1 new creature, name it, describe its habitat",
      "Guided daydream: teacher narrates slowly, kids close eyes and imagine, then draw what they saw",
      "Nightmare flip: draw something scary from a dream, then draw it being silly or friendly",
    ],
  },
  {
    week: 8,
    name: "World of Time",
    emoji: "⏳",
    color: "#D4A843",
    tagline: "You can't see it. You can't hold it. But it changes everything.",
    question: "If you could visit any time — past or future — when would you go?",
    people: "The citizens of time are: babies (who just arrived), kids (you — right in the middle), adults (who forgot what this felt like), grandparents (who remember again), and ghosts (who already left but are still here in the things they made).",
    culture: "Time's culture is layers. Everything you see is built on something older. The school sits on land that was a forest that was an ocean floor. Your language was invented by people who are dead. Your breakfast recipe came from someone's grandmother's grandmother. Nothing is new. Everything is a layer on a layer.",
    map: "Draw four maps of the same place: your street 100 years ago (guess), your street now, your street 100 years from now (imagine), your street 1 million years from now (everything is gone except the rocks). Four maps. Same place. Time is the only variable.",
    tools: "Clocks, calendars, memory, and patience. But the real tool of time is NOTICING. 'What's different from yesterday?' That question IS the tool of time. Ask it every day and you're a time scientist.",
    language: "ANCIENT (very very old), ERA (a long period of time), FOSSIL (something preserved from long ago), GENERATION (the distance from you to your parents to their parents), ETERNAL (lasting forever). Five time words.",
    food: "Some food takes seconds (a grape). Some takes hours (bread). Some takes months (cheese). Some takes years (wine — for grownups). Time is an ingredient. What happens to food when you give it more time? It transforms.",
    music: "Play a song fast. Play it slow. Same song, different feeling. TEMPO is time's version of a mood. Fast time feels exciting. Slow time feels heavy. What tempo is YOUR life right now?",
    rules: "Time's rules: it only goes forward, you can't save it, everyone gets the same amount each day, and the things that last longest are the things that were built slowly.",
    problems: "Time's problem: not enough of it. Or too much of it. Being bored is too much time. Being rushed is not enough. Which is worse? Discuss. Sticky notes on the wall.",
    dreams: "If you could stop time for one hour, what would you do? Not something selfish — something beautiful. 'I would let everyone sleep who's tired.' 'I would hold my mom's hand for an hour without her having to go to work.'",
    verbs: "WAIT (how long can you hold still? time it — that's your personal relationship with time), WATCH (look at one thing for 5 minutes — notice what changes), BUILD (make a time capsule with 5 objects from today)",
    activities: [
      "Stillness timer: how long can you hold completely still? That number is YOUR time",
      "Time capsule: pick 5 objects that describe today, seal in a box, open last week of summer",
      "Four maps: same place, 4 times — past, present, future, far future",
      "Speed vs slow: do everything fast for 1 minute, then everything slow for 1 minute — which felt better?",
      "Paper strip timeline: your life, your grandma's life, the building's life, the earth's life — strips get longer",
      "Before and after: photograph something, change it, photograph again — time passed between the clicks",
      "Old things hunt: find the oldest thing in the building, the newest thing — how do you know?",
      "One day as a grandparent: move slow, talk slow, think about what you'd remember from being 5",
    ],
  },
  {
    week: 9,
    name: "World of Feelings",
    emoji: "💛",
    color: "#E07545",
    tagline: "The biggest world is the one inside you.",
    question: "If your feelings had colors, what would today look like?",
    people: "The citizens are your emotions: Joy (who wants to dance), Sadness (who wants to sit quietly), Anger (who wants to be heard), Fear (who wants to hide), Surprise (who shows up uninvited), and Calm (who holds everyone together).",
    culture: "Feeling culture is weather. Joy is sunshine. Sadness is rain. Anger is a storm. Fear is fog. Calm is a clear night. The weather changes all day. That's normal. A day with only sunshine isn't a real day.",
    map: "Draw a body outline. Color where each feeling lives. Where is happiness? (Chest? Smile?) Where is anger? (Fists? Belly?) Where is fear? (Throat? Legs?) Everyone's map is different. That's the point.",
    tools: "Words, breath, movement, and other people. When you feel too much: BREATHE (count to 5), MOVE (shake it off), TALK (say it out loud), FIND SOMEONE (you don't have to feel it alone).",
    language: "ANXIOUS (worried about something that hasn't happened yet), OVERWHELMED (too many feelings at once), CONTENT (quiet happiness — not excited, just okay), EMPATHY (feeling what someone else feels), RESILIENT (bouncing back after something hard). Five feelings words.",
    food: "Comfort food. What do you eat when you're sad? What do you eat when you're celebrating? Food and feelings are connected. Draw your sad meal and your happy meal. Are they different?",
    music: "Play 5 different songs (or hum them). Which one sounds happy? Which one sounds scary? Which one sounds like thinking? Music IS feelings made audible. Match an emotion to each one.",
    rules: "Feelings rules: all feelings are real, no feeling lasts forever, feelings are not actions (you can feel angry without hitting), and the only bad feeling is one you pretend isn't there.",
    problems: "Sometimes feelings don't match the situation. You feel angry but nothing happened. You feel sad on a happy day. That's called 'feelings are complicated.' The problem isn't the feeling. The problem is thinking something's wrong with you for having it. Nothing's wrong with you.",
    dreams: "If you could give every person on earth one feeling for one day, which feeling would you choose? Not happiness — that's too easy. Maybe courage. Maybe calm. Maybe curiosity. What would the world look like if everyone felt that for just one day?",
    verbs: "LISTEN (to your body — where is the feeling right now?), SHINE (say the feeling out loud — name it in front of people), HELP (notice someone else's feeling and sit with them)",
    activities: [
      "Body map of feelings: outline, color where emotions live in you",
      "Mood weather: check 3 times today — morning, midday, afternoon — draw each one",
      "Feelings walk: walk at the SPEED of your feeling — angry is fast, calm is slow",
      "Emotion soundtrack: what does happy/sad/scared/calm sound like? make each one",
      "Comfort recipe: draw what you need when you're sad — not just food, everything (blanket, mom, quiet)",
      "Empathy exercise: look at a partner's face for 30 seconds, guess how they're feeling, ask if you're right",
      "Feelings evolution: draw 3 panels — a feeling that started one way and became something else",
      "The feelings wall: today's question: 'What's something nobody knows you feel?' anonymous sticky notes",
    ],
  },
  {
    week: 10,
    name: "World of Us",
    emoji: "✨",
    color: "#e050a0",
    tagline: "You visited 9 worlds. Now build the 10th — together.",
    question: "If this room were a country, what would it be called?",
    people: "The citizens are: everyone in this room. You know each other now. You've been Me, Stories, Nature, Water, Music, Space, Dreams, Time, and Feelings together. You are the people of this world. There are no strangers here.",
    culture: "The culture is everything you made. The Wall. The Shelf. The books. The songs. The body maps. The dream journals. The time capsules. The feelings weather. The verb cards worn soft from picking. This room IS the culture. You built it with your hands over nine weeks.",
    map: "Draw the map of THIS world. This room. But not the furniture — the INVISIBLE stuff. Where does laughter happen? (The circle.) Where does quiet happen? (The reading corner.) Where does hard work happen? (The writing table.) Where does friendship happen? (Everywhere.) That's the real map.",
    tools: "The 12 verbs. They were always the tools. CARRY, LISTEN, PLAY, SPARK, FLOW, BUILD, WATCH, WAIT, SOLVE, HELP, ECHO, SHINE. You've been using them for 9 weeks. They're not cards on a table anymore. They're in your body.",
    language: "Every beautiful word you learned all summer. The word wall is the dictionary of this world. ENORMOUS. EPHEMERAL. SHIMMER. CASCADE. LUMINOUS. TRANSLUCENT. CONSTELLATION. RESILIENT. These words belong to you now.",
    food: "The celebration meal. Everyone brings or makes one thing. Share it. The sharing IS the culture.",
    music: "Everyone hums their 4-note anthem from Week 5. One by one. Then all together. That cacophony is the national anthem of THIS world. Beautiful because it's everyone at once.",
    rules: "The rules are the ones you've been living: pick three verbs, do them, discover who you are. That rule works here, at home, at school, anywhere, forever. The rule travels with you.",
    problems: "This world ends on Friday. That's the problem. It's temporary. Ephemeral. But what you built isn't — the book, the skills, the verbs, the way you see. Those leave with you.",
    dreams: "The dream of this world is that it never really ends. You keep picking verbs. You keep asking questions. You keep noticing. You keep carrying things for people. The summer ends. The practice doesn't.",
    verbs: "ALL 12 — one last time. Pick your final 3. Do them. Discover your final world. Write it in your book. That's the last page.",
    activities: [
      "Room map: draw the invisible map of this room — where laughter lives, where quiet lives",
      "Gallery prep: choose your best work from each week, mount and display it",
      "Time capsule opening: open the box from Week 8, remember who you were 2 weeks ago",
      "Avatar evolution: draw your avatar from Week 1 next to your avatar now",
      "Declaration: 'My name is ___. My title is ___. And this is my book.'",
      "The Show: families come, kids stand by their work, the room tells the story",
      "Verb retirement: pick the ONE verb you'll take home and practice forever",
      "Photo comparison: the empty room from Day 1 vs. this room right now, side by side",
    ],
  },
];

export default function TenWorlds() {
  const [activeWorld, setActiveWorld] = useState(0);
  const [openSection, setOpenSection] = useState(null);

  const w = WORLDS[activeWorld];
  const font = "'Newsreader', Georgia, serif";
  const mono = "'DM Mono', monospace";

  const sections = [
    { key: "people", label: "The People", emoji: "👤", content: w.people },
    { key: "culture", label: "The Culture", emoji: "🎭", content: w.culture },
    { key: "map", label: "The Map", emoji: "🗺", content: w.map },
    { key: "tools", label: "The Tools", emoji: "🔧", content: w.tools },
    { key: "language", label: "The Language", emoji: "💬", content: w.language },
    { key: "food", label: "The Food", emoji: "🍽", content: w.food },
    { key: "music", label: "The Music", emoji: "🎵", content: w.music },
    { key: "rules", label: "The Rules", emoji: "📜", content: w.rules },
    { key: "problems", label: "The Problems", emoji: "⚠️", content: w.problems },
    { key: "dreams", label: "The Dreams", emoji: "💫", content: w.dreams },
  ];

  return (
    <div style={{ minHeight: "100vh", background: "#060608", color: "#b0b0b8", fontFamily: font }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Newsreader:opsz,wght@6..72,300;6..72,400;6..72,600;6..72,700&family=DM+Mono:wght@300;400;500&display=swap');
        @keyframes fadeIn { from { opacity:0; transform:translateY(6px) } to { opacity:1; transform:translateY(0) } }
        ::-webkit-scrollbar { width:3px } ::-webkit-scrollbar-thumb { background:#1a1a1e; border-radius:2px }
      `}</style>

      <div style={{ padding: "24px 18px 10px", borderBottom: "1px solid #111114" }}>
        <p style={{ fontFamily: mono, fontSize: "8px", color: "#2a2a30", letterSpacing: "3px", margin: "0 0 2px" }}>
          10 WEEKS · 10 WORLDS · 1 DIFFERENT WORLD
        </p>
        <h1 style={{ fontSize: "20px", fontWeight: 300, color: "#e8e8ec", margin: "0 0 10px" }}>
          If You Built a World
        </h1>

        <div style={{ display: "flex", gap: "3px", overflowX: "auto", paddingBottom: "4px" }}>
          {WORLDS.map((world, i) => (
            <button key={i} onClick={() => { setActiveWorld(i); setOpenSection(null); }} style={{
              padding: "6px 4px", minWidth: "42px",
              background: activeWorld === i ? `${world.color}12` : "#0a0a0e",
              border: `1px solid ${activeWorld === i ? world.color + "33" : "#131316"}`,
              borderRadius: "6px", cursor: "pointer", textAlign: "center",
              transition: "all 0.15s", flexShrink: 0,
            }}>
              <span style={{ fontSize: "16px" }}>{world.emoji}</span>
              <div style={{ fontFamily: mono, fontSize: "7px", color: activeWorld === i ? world.color : "#2a2a30" }}>
                W{world.week}
              </div>
            </button>
          ))}
        </div>
      </div>

      <div key={activeWorld} style={{ padding: "14px 18px 60px", maxWidth: "540px", animation: "fadeIn 0.25s ease" }}>
        {/* Header */}
        <div style={{ textAlign: "center", marginBottom: "16px" }}>
          <div style={{ fontSize: "40px" }}>{w.emoji}</div>
          <h2 style={{ fontSize: "22px", fontWeight: 300, color: w.color, margin: "6px 0 2px" }}>{w.name}</h2>
          <p style={{ fontSize: "12px", color: "#55555f", fontStyle: "italic", margin: "0 0 6px" }}>{w.tagline}</p>
          <p style={{ fontSize: "14px", color: "#8888a0", margin: 0, fontWeight: 600 }}>"{w.question}"</p>
        </div>

        {/* Sections */}
        {sections.map((s, i) => (
          <div key={s.key}
            onClick={() => setOpenSection(openSection === s.key ? null : s.key)}
            style={{
              background: openSection === s.key ? `${w.color}06` : "#0b0b0f",
              border: `1px solid ${openSection === s.key ? w.color + "22" : "#151518"}`,
              borderLeft: `3px solid ${openSection === s.key ? w.color : "#1a1a1e"}`,
              borderRadius: "6px", padding: "12px 14px", marginBottom: "4px",
              cursor: "pointer", transition: "all 0.15s",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                <span style={{ fontSize: "14px" }}>{s.emoji}</span>
                <span style={{ fontSize: "13px", fontWeight: 600, color: openSection === s.key ? w.color : "#77778a" }}>
                  {s.label}
                </span>
              </div>
              <span style={{ fontFamily: mono, fontSize: "10px", color: "#2a2a30", transform: openSection === s.key ? "rotate(180deg)" : "none", transition: "transform 0.2s" }}>▼</span>
            </div>
            {openSection === s.key && (
              <p style={{ fontSize: "12px", color: "#9898a8", lineHeight: 1.65, margin: "10px 0 0", animation: "fadeIn 0.2s ease" }}>
                {s.content}
              </p>
            )}
          </div>
        ))}

        {/* Verbs */}
        <div style={{
          marginTop: "10px", padding: "14px 16px",
          background: `${w.color}06`, border: `1px solid ${w.color}15`,
          borderRadius: "8px",
        }}>
          <div style={{ fontFamily: mono, fontSize: "8px", color: w.color, letterSpacing: "2px", marginBottom: "6px", opacity: 0.5 }}>
            THIS WEEK'S VERBS
          </div>
          <p style={{ fontSize: "13px", color: w.color, lineHeight: 1.6, margin: 0 }}>{w.verbs}</p>
        </div>

        {/* Activities */}
        <div style={{ marginTop: "10px" }}>
          <div style={{ fontFamily: mono, fontSize: "8px", color: "#33333d", letterSpacing: "2px", marginBottom: "8px" }}>
            ACTIVITIES
          </div>
          {w.activities.map((a, i) => (
            <div key={i} style={{
              padding: "8px 12px", background: "#0b0b0f",
              border: "1px solid #131316", borderRadius: "6px",
              marginBottom: "4px",
            }}>
              <p style={{ fontSize: "12px", color: "#8888a0", lineHeight: 1.5, margin: 0 }}>{a}</p>
            </div>
          ))}
        </div>

        {/* Journey bar */}
        <div style={{
          marginTop: "16px", display: "flex", gap: "2px",
          justifyContent: "center", alignItems: "center",
        }}>
          {WORLDS.map((world, i) => (
            <div key={i} onClick={() => { setActiveWorld(i); setOpenSection(null); }} style={{
              width: i === activeWorld ? "24px" : "16px",
              height: i === activeWorld ? "24px" : "16px",
              borderRadius: "50%",
              background: i <= activeWorld ? `${world.color}30` : "#0c0c0f",
              border: `1px solid ${i <= activeWorld ? world.color + "44" : "#1a1a1e"}`,
              display: "flex", alignItems: "center", justifyContent: "center",
              cursor: "pointer", transition: "all 0.2s",
              fontSize: i === activeWorld ? "12px" : "8px",
            }}>
              {world.emoji}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
