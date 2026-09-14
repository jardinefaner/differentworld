import 'package:differentworld/features/facilitation/room_beat.dart';

/// Run-scripts for the activities that are NOT games.
///
/// Kept in one map rather than scattered across the screens for the same
/// reason the game ledger is a test: the interesting number is how much of the
/// deck a substitute can start, and that number is only visible if the scripts
/// are countable in one place.
///
/// **These three matter more than the classics, and it is worth saying why.**
/// A substitute who has never opened this app has still played Connect Four —
/// the script there saves them a minute. They have never done Group Talk, Role
/// Cards, or Make a Pattern in their life. For these the script is not a
/// convenience; it is the difference between the activity happening and the
/// room being told "we'll do something else today".
const Map<String, RunScript> activityRunScripts = {
  // Group Talk — a teacher-hosted discussion, one curated prompt at a time.
  // The beats teach the ROOM its norms, which is exactly what a stranger to
  // the group cannot supply: a sub does not know that this room takes turns,
  // or that disagreeing is allowed here.
  '/activity/discussions': [
    RoomBeat('We are going to talk together'),
    RoomBeat('One question at a time', detail: 'There is no right answer'),
    RoomBeat('Listen while someone else has it', detail: 'Then you can add'),
    RoomBeat('You can pass', detail: 'Nobody has to talk'),
  ],

  // Role Cards — each child is an animal for the day, with three habits to
  // try. Without a script this screen reads as a catalogue to browse; the
  // beats are what turn it into something the room DOES.
  '/activity/roles': [
    RoomBeat('Today we each get a role'),
    RoomBeat('Your card has three things you do', detail: 'Try them all day'),
    RoomBeat('Read yours out to us'),
  ],

  // Make a Pattern — build a tile in real life, photograph it, watch it
  // repeat. The first beat is the one a sub would never guess: the making
  // happens OFF the screen, with real objects, and the app only mirrors it.
  '/activity/pattern': [
    RoomBeat('We are making a pattern'),
    RoomBeat('Build one small tile', detail: 'Blocks, leaves, anything'),
    RoomBeat('Then we take a photo of it'),
    RoomBeat('Watch what it does'),
  ],

  // Do It — one real-world action at a time, big on the screen. The whole
  // activity happens AWAY from the app, which is the part a sub would not
  // guess from a screen showing a card.
  '/activity/do-it': [
    RoomBeat('We have one real thing to do'),
    RoomBeat('It is not on the screen', detail: 'We go and do it'),
    RoomBeat('Then we come back and say we did'),
  ],

  // Penny for a Thought — share a thought, drop a penny; the pile is the
  // math. Both halves need saying: a sub reading "Penny" sees a question and
  // has no reason to know pennies are involved at all.
  '/activity/penny': [
    RoomBeat('A penny for a thought'),
    RoomBeat('Say what you think', detail: 'Then drop a penny in'),
    RoomBeat('We count the pile at the end'),
  ],

  // Potions — a recipe the room makes for REAL, from the garden.
  '/activity/potions': [
    RoomBeat('We are making a potion'),
    RoomBeat('The screen gives us the recipe'),
    RoomBeat('We gather the real things', detail: 'Petals, water, a cup'),
    RoomBeat('Then we name it together'),
  ],

  // Letters — the room writes to each other, on paper. Paper-first is the
  // beat that stops a sub hunting for a typing surface that does not exist.
  '/activity/letters': [
    RoomBeat('We are writing notes to each other'),
    RoomBeat('On paper', detail: 'The screen only says who to write to'),
    RoomBeat('Say something kind'),
  ],

  // Fill in the Blank — the room shouts a word for each blank, then hears it
  // read back. The order matters and is the joke: words FIRST, story after.
  '/activity/fill-blank': [
    RoomBeat('We are filling in the blanks'),
    RoomBeat('Shout out a word when asked', detail: 'Do not ask what for'),
    RoomBeat('Then we read the whole thing out'),
  ],

  // Many Paths — how many ways can we reach this number. Not a quiz: the
  // point is the variety, and a sub told "math" will otherwise run it as one.
  '/activity/math': [
    RoomBeat('We have one number'),
    RoomBeat('How many ways can we make it?', detail: 'There is no one answer'),
    RoomBeat('We show all the ways we found'),
  ],
};
