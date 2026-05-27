// Teacher Toolkit — the editorial reference library shipped IN the
// app binary. Five categories of six tools each; each tool is a
// concrete move a teacher can make in the moment.
//
// ## Why this lives in Dart, not the database
//
// 1. Editorial voice matters. This content is curated. Letting every
//    space rewrite it would dilute the voice and create inconsistent
//    advice across programs.
// 2. It's static. The 30 tools don't change daily; ship them in the
//    binary, read them at zero latency, no sync cost.
// 3. It works offline forever. No table -> no sync -> no "syncing
//    your toolkit" spinner. Open the screen on a plane -> it works.
//
// ## The path to CRUD (Wave 162, deferred)
//
// When directors ask to author their own tools, we add a
// toolkit_overrides table that:
//   - Can ADD a new tool to any category (builtin_slug = null).
//   - Can HIDE a built-in for one space (builtin_slug set,
//     hidden = true).
//   - Can OVERRIDE a built-in's fields (builtin_slug set, other
//     fields populated).
//
// The catalog provider then layers overrides on top of the built-ins
// per space. Built-ins keep their stable ToolkitTool.slug so
// overrides survive across content updates.

import 'package:flutter/material.dart';

/// One of the five top-level buckets the toolkit is organized into.
/// String values are stable identifiers — they'll be the foreign key
/// from the overrides table (Wave 162). Don't rename in place; add a
/// new id and migrate if a rename is ever needed.
enum ToolkitCategoryId {
  celebrate,
  toughMoments,
  knowYourKids,
  classroomCulture,
  selfCare,
}

/// A single category in the toolkit. Holds editorial metadata
/// (color, icon, tagline) + the ordered list of tools that belong to
/// it. Categories are presentation; tools are content.
class ToolkitCategory {
  const ToolkitCategory({
    required this.id,
    required this.name,
    required this.glyph,
    required this.color,
    required this.tagline,
    required this.tools,
  });

  final ToolkitCategoryId id;
  final String name;

  /// Single-codepoint glyph used in the React mock (✦ ◈ ◉ ◇ ☉). Lives
  /// next to the category name in tabs and search results.
  final String glyph;

  /// Accent color used for the active-tab underline, the "Try" panel
  /// background, the quick-script chip. Picked to read on both light
  /// and dark surfaces; the screen applies opacity scaling on dark.
  final Color color;

  /// Italic subtitle under the category header.
  final String tagline;

  final List<ToolkitTool> tools;
}

/// One actionable tool. Six fields:
///   - [name]: short title
///   - [when]: the situation ("A kid does something good…")
///   - [instead]: what teachers commonly default to (the anti-pattern)
///   - [tryThis]: the recommended move
///   - [why]: the rationale (the "why this works" sidebar)
///   - [quick]: the one-line script teachers can repeat in the moment
class ToolkitTool {
  const ToolkitTool({
    required this.slug,
    required this.categoryId,
    required this.name,
    required this.when,
    required this.instead,
    required this.tryThis,
    required this.why,
    required this.quick,
  });

  /// Stable identifier — the Wave 162 overrides table joins on this.
  /// Format: `'<category>.<kebab-case-name>'`. Never reuse a slug for a
  /// different tool; once shipped it's a contract.
  final String slug;

  final ToolkitCategoryId categoryId;
  final String name;
  final String when;
  final String instead;
  final String tryThis;
  final String why;
  final String quick;

  /// Concatenated lowercase haystack for fuzzy search.
  String get searchHaystack =>
      '$name $when $instead $tryThis $quick'.toLowerCase();
}

/// The shipped catalog. Modify with care — every tool has a stable
/// slug that future overrides will reference.
const List<ToolkitCategory> toolkitCatalog = [
  ToolkitCategory(
    id: ToolkitCategoryId.celebrate,
    name: 'Celebrate',
    glyph: '✦',
    color: Color(0xFF5CE0D8),
    tagline: 'Make the good days louder than the bad days',
    tools: [
      ToolkitTool(
        slug: 'celebrate.specific-notice',
        categoryId: ToolkitCategoryId.celebrate,
        name: 'The Specific Notice',
        when: 'A kid does something good and you want to celebrate it',
        instead: '"Good job today!"',
        tryThis:
            'Name the exact behavior + what it taught you. "The way you '
            'waited for Marcus to finish before you spoke — that showed '
            "real patience. I'm learning from you.\"",
        why:
            'Generic praise is invisible. Specific noticing says: I SAW '
            'the exact thing you did. It teaches the kid which behavior '
            'matters and why.',
        quick:
            'I noticed you [specific action]. That showed [character '
            'trait]. That taught me [what you learned].',
      ),
      ToolkitTool(
        slug: 'celebrate.running-record',
        categoryId: ToolkitCategoryId.celebrate,
        name: 'The Running Record',
        when:
            'You want to track the good stuff so you have evidence when '
            'it matters',
        instead:
            'Relying on memory (which biases toward recent events and '
            'problems)',
        tryThis:
            'Keep a notes app or small notebook. When a kid does '
            'something worth noting, write: date + name + what '
            'happened. Takes 10 seconds. By November you have a '
            'treasure chest.',
        why:
            "When the bad day comes, you can say: 'Look — here are 40 "
            "days where you were incredible.' Context transforms a "
            'correction into a conversation.',
        quick: '[Date] [Name] — [What they did] — [Why it mattered]',
      ),
      ToolkitTool(
        slug: 'celebrate.public-celebration',
        categoryId: ToolkitCategoryId.celebrate,
        name: 'The Public Celebration',
        when: 'You want to celebrate a kid in front of the class',
        instead: '"Thank you for being good today" (celebrates compliance)',
        tryThis:
            '"I want everyone to know that Jayden taught me something '
            'this week. He showed me that you can disagree with someone '
            'and still be kind to them." Celebrate CHARACTER, not '
            'behavior.',
        why:
            'Compliance praise trains kids to perform for approval. '
            'Character celebration says: who you ARE is valuable. That '
            'sticks.',
        quick:
            'I want everyone to know that [name] taught me something. '
            'They showed me [character insight].',
      ),
      ToolkitTool(
        slug: 'celebrate.parent-text',
        categoryId: ToolkitCategoryId.celebrate,
        name: 'The Parent Text',
        when:
            'You want a parent to hear something good (not just bad news)',
        instead: "Only contacting parents when there's a problem",
        tryThis:
            'A quick text or note: "I wanted you to know that [name] '
            'did something amazing today. [Specific thing]. You should '
            'be really proud." Takes 30 seconds. Changes the '
            'parent-teacher relationship forever.',
        why:
            "Most parents only hear from school when something's wrong. "
            'One positive text builds more trust than ten conferences. '
            'The kid comes home to a parent who already knows they '
            'were great today.',
        quick:
            'Hi — just wanted to share that [name] [specific thing] '
            'today. Really impressive. You should be proud.',
      ),
      ToolkitTool(
        slug: 'celebrate.callback',
        categoryId: ToolkitCategoryId.celebrate,
        name: 'The Callback',
        when: 'A kid who usually struggles has a great moment',
        instead: "Ignoring it because you don't want to make a big deal",
        tryThis:
            'Make a big deal. Privately. Pull them aside: "Hey. I see '
            "you. What you did today? That's the real you. I want you "
            'to know I see it." Don\'t compare to their bad days. Just '
            'celebrate this one.',
        why:
            'Kids who struggle are used to being seen only when they '
            'fail. Being seen when they succeed — privately, genuinely '
            '— rewires how they see themselves.',
        quick: "Hey. I see you. What you just did? That's the real you.",
      ),
      ToolkitTool(
        slug: 'celebrate.5-to-1-ratio',
        categoryId: ToolkitCategoryId.celebrate,
        name: 'The 5:1 Ratio',
        when: 'Every single day',
        instead: 'Correcting as much as you praise (1:1 ratio)',
        tryThis:
            'Five specific positive interactions for every one '
            'correction. Count it. Track it. It feels excessive at '
            "first. It's not. It's the research-backed ratio for a "
            'psychologically safe environment.',
        why:
            'One correction without a foundation of celebration feels '
            'like an attack. One correction inside a pattern of genuine '
            'noticing feels like care.',
        quick:
            'Before I correct, have I celebrated this kid 5 times '
            'recently? If not, celebrate first.',
      ),
    ],
  ),
  ToolkitCategory(
    id: ToolkitCategoryId.toughMoments,
    name: 'Tough Moments',
    glyph: '◈',
    color: Color(0xFFF5A623),
    tagline: 'What to do when it falls apart',
    tools: [
      ToolkitTool(
        slug: 'tough.bad-day-protocol',
        categoryId: ToolkitCategoryId.toughMoments,
        name: 'The Bad Day Protocol',
        when: 'A usually-good kid is having a terrible day',
        instead:
            '"What is wrong with you today?" or "You know better than '
            'this."',
        tryThis:
            'Pull them aside. Lead with relationship, not behavior: '
            "\"I know you. This isn't you. I've seen too many good days "
            "to think this is who you are. What's going on?\" Listen. "
            "Don't solve. Just listen.",
        why:
            'Leading with the relationship says: your identity is '
            "GOOD. Today is a glitch, not a definition. The kid doesn't "
            'have to defend themselves — they can just tell you what '
            'happened.',
        quick: "I know you. This isn't you. What happened today?",
      ),
      ToolkitTool(
        slug: 'tough.cool-down',
        categoryId: ToolkitCategoryId.toughMoments,
        name: 'The Cool Down',
        when: 'A kid is escalated — angry, crying, shut down',
        instead:
            '"Calm down" (which has never once worked in human history)',
        tryThis:
            'Lower YOUR voice. Get physically lower (crouch, sit). Say: '
            "\"I can see this is really hard right now. I'm right here. "
            'Take your time." Give them space but don\'t leave. Your '
            'calm is contagious. Their chaos is asking you to match it. '
            "Don't.",
        why:
            'An escalated kid is in fight-or-flight. Their rational '
            'brain is offline. No words will work. Your physical '
            'presence, low voice, and patience will. The regulation '
            'comes through your body, not your words.',
        quick: "I can see this is hard. I'm right here. Take your time.",
      ),
      ToolkitTool(
        slug: 'tough.two-part-correction',
        categoryId: ToolkitCategoryId.toughMoments,
        name: 'The Two-Part Correction',
        when: 'You need to address a behavior directly',
        instead: '"Stop doing that" (tells them what NOT to do)',
        tryThis:
            'Part 1 — Name what you see without judgment: "I notice '
            "you're throwing things right now.\" Part 2 — Name what "
            'you need: "I need you to keep the materials on the table." '
            'No shame. No why. Just: I see this, I need that.',
        why:
            '"Stop it" is about control. "I notice / I need" is about '
            'clarity. The kid hears what TO do, not just what to stop. '
            'It also avoids the shame spiral of "why would you do '
            'that?"',
        quick:
            "I notice [what's happening]. I need [what you need "
            'instead].',
      ),
      ToolkitTool(
        slug: 'tough.repair',
        categoryId: ToolkitCategoryId.toughMoments,
        name: 'The Repair',
        when: 'After a tough moment, the relationship needs fixing',
        instead: "Pretending it didn't happen / Holding a grudge",
        tryThis:
            'Later that day or the next morning, find the kid. "Hey. '
            'Yesterday was rough for both of us. I want you to know — '
            "we're good. Nothing that happened changed how I feel "
            'about you. We start fresh." Then prove it by treating '
            'them warmly that day.',
        why:
            'Kids are waiting to find out: does my teacher still like '
            "me after I messed up? If you don't repair, they assume "
            'the worst. If you repair, they learn that relationships '
            'survive mistakes. That might be the most important '
            'lesson in school.',
        quick:
            "Yesterday was rough. We're good. Nothing changed between "
            'us.',
      ),
      ToolkitTool(
        slug: 'tough.redirect-without-shame',
        categoryId: ToolkitCategoryId.toughMoments,
        name: 'The Redirect Without Shame',
        when: 'A kid is doing something disruptive but not harmful',
        instead: 'Calling them out in front of everyone',
        tryThis:
            'Walk near them. Make eye contact. Touch the desk gently. '
            'Whisper: "Hey, I need you back with me." No public '
            'correction. No name called across the room. Proximity + '
            'quiet voice + clear request.',
        why:
            'Public correction humiliates. Humiliation creates '
            'resentment. Resentment creates more disruption. The quiet '
            'redirect keeps dignity intact and works faster than any '
            'lecture.',
        quick:
            '[Walk close. Quiet voice.] Hey, I need you back with me.',
      ),
      ToolkitTool(
        slug: 'tough.emergency-pause',
        categoryId: ToolkitCategoryId.toughMoments,
        name: 'The Emergency Pause',
        when: "You're about to lose YOUR cool",
        instead: 'Reacting from frustration',
        tryThis:
            'Say out loud: "I need a moment to think about the best '
            "way to handle this.\" Then take 3 breaths. This isn't "
            "weakness — it's modeling. You're showing kids that adults "
            'also need to regulate, and that pausing is strength.',
        why:
            'Teachers are human. You will get frustrated. The move '
            "isn't never getting frustrated — it's showing kids what "
            'you DO with frustration. You just became the most '
            'powerful lesson in the room.',
        quick:
            'I need a moment to think about the best way to handle '
            'this.',
      ),
    ],
  ),
  ToolkitCategory(
    id: ToolkitCategoryId.knowYourKids,
    name: 'Know Your Kids',
    glyph: '◉',
    color: Color(0xFFCC5DE8),
    tagline: 'The relationship IS the strategy',
    tools: [
      ToolkitTool(
        slug: 'know.two-by-ten',
        categoryId: ToolkitCategoryId.knowYourKids,
        name: 'The 2×10',
        when: "You have a kid you can't connect with",
        instead: 'Waiting for a connection to happen naturally',
        tryThis:
            '2 minutes a day, 10 days in a row. Talk to the kid about '
            "ANYTHING that isn't school. Their shoes. Their weekend. "
            'Their dog. Their game. Two minutes. Non-academic. Ten '
            'straight days. The relationship will shift.',
        why:
            'The hardest kids are usually the ones with the fewest '
            'positive adult relationships. Two minutes of genuine '
            'interest — not behavioral monitoring — says: I see you '
            'as a PERSON, not a problem. Ten days makes it a pattern '
            'they can trust.',
        quick:
            'Hey [name], [genuine non-school question]. 2 minutes. '
            'Repeat tomorrow.',
      ),
      ToolkitTool(
        slug: 'know.interest-inventory',
        categoryId: ToolkitCategoryId.knowYourKids,
        name: 'The Interest Inventory',
        when: 'Beginning of the year or when a new kid arrives',
        instead: 'Assuming you know what a kid cares about',
        tryThis:
            "A simple form or conversation: What do you do when nobody's "
            "telling you what to do? What's something you know a lot "
            "about? What's something you wish adults understood about "
            'you? Keep it. Reference it. A kid who mentioned dinosaurs '
            'in September should hear you mention dinosaurs in '
            'February.',
        why:
            'Knowing what a kid cares about gives you a bridge to them '
            "that's always open. It also tells you what motivates them, "
            'which makes everything from engagement to correction '
            'easier.',
        quick:
            'What do you do when nobody tells you what to do? What do '
            'you wish adults knew about you?',
      ),
      ToolkitTool(
        slug: 'know.door-greeting',
        categoryId: ToolkitCategoryId.knowYourKids,
        name: 'The Door Greeting',
        when: 'Every single morning',
        instead: 'Kids entering to a room where no one acknowledges them',
        tryThis:
            'Stand at the door. Every kid gets one moment: eye contact '
            '+ their name + one specific thing. "Morning, Jayden. Love '
            'the shoes." "Hey, Rani. How was the game last night?" 3 '
            'seconds per kid. 10 minutes total. Changes the entire '
            'day.',
        why:
            'The first moment of the day programs the rest of it. A '
            'kid who walks in unseen starts the day feeling invisible. '
            "A kid who's greeted by name starts the day feeling known. "
            "That's the entire difference.",
        quick:
            'Stand at door. Eye contact. Name. One personal thing. '
            'Every kid. Every day.',
      ),
      ToolkitTool(
        slug: 'know.home-visit-mindset',
        categoryId: ToolkitCategoryId.knowYourKids,
        name: 'The Home Visit Mindset',
        when: "You're confused by a kid's behavior",
        instead: '"This kid is just difficult"',
        tryThis:
            "Ask yourself: what's happening at home that I can't see? "
            'Not to excuse behavior — to understand it. The kid who '
            'falls asleep in class might be sharing a bed with three '
            'siblings. The kid who hoards snacks might not eat dinner. '
            "You don't need to know the details to teach with "
            'compassion for the unknown.',
        why:
            "Every behavior is communication. The question isn't "
            "'why are you doing this TO me?' It's 'what is this "
            "behavior telling me about what you need?'",
        quick:
            "What might be happening that I can't see? What is this "
            'behavior telling me?',
      ),
      ToolkitTool(
        slug: 'know.name-story',
        categoryId: ToolkitCategoryId.knowYourKids,
        name: 'The Name Story',
        when: 'First week of school or when you sense a kid feels unseen',
        instead: 'Just learning to pronounce the name',
        tryThis:
            '"Tell me about your name. Who named you? Why? Does it '
            "mean anything? Do you like it?\" A kid's name is the "
            'first thing that was ever theirs. Asking about it says: '
            'your ORIGIN matters to me.',
        why:
            'Many kids — especially kids from immigrant families or '
            'non-dominant cultures — have names that get mispronounced '
            'or shortened without permission. Asking about the name '
            'honors the whole child, not just the classroom version '
            'of them.',
        quick:
            'Tell me about your name. Who gave it to you? What does it '
            'mean?',
      ),
      ToolkitTool(
        slug: 'know.check-in-question',
        categoryId: ToolkitCategoryId.knowYourKids,
        name: 'The Check-In Question',
        when: "When something feels off but you don't know what",
        instead: '"Are you okay?" (always gets "I\'m fine")',
        tryThis:
            '"On a scale of 1-10, where are you at today?" If they say '
            'anything below 5: "Want to tell me about it or just want '
            'me to know?" This gives them control — they can share '
            'or just feel acknowledged. Both are healing.',
        why:
            '"Are you okay" is a yes/no question and the answer is '
            'always yes. The number gives them a real way to '
            'communicate. And offering the choice between talking '
            'and just being known respects their autonomy.',
        quick:
            '1 to 10, where are you today? Want to talk about it or '
            'just want me to know?',
      ),
    ],
  ),
  ToolkitCategory(
    id: ToolkitCategoryId.classroomCulture,
    name: 'Classroom Culture',
    glyph: '◇',
    color: Color(0xFF748FFC),
    tagline: 'Systems that make good days automatic',
    tools: [
      ToolkitTool(
        slug: 'culture.anchor-ritual',
        categoryId: ToolkitCategoryId.classroomCulture,
        name: 'The Anchor Ritual',
        when: 'First thing every morning, non-negotiable',
        instead: 'Jumping straight into content',
        tryThis:
            'One ritual that never changes. A morning meeting, a '
            'check-in circle, a song, a question of the day. The '
            'content changes but the structure is sacred. Rain or '
            'shine, test day or field trip, the ritual happens. '
            "It's the one thing every kid can count on.",
        why:
            'Predictability is safety. Especially for kids whose lives '
            'outside school are chaotic. The ritual says: this room '
            'is stable. No matter what happened before you got here, '
            'this moment will be the same.',
        quick:
            'Pick one ritual. Do it every day. Never skip. It becomes '
            'the heartbeat of the room.',
      ),
      ToolkitTool(
        slug: 'culture.signal-system',
        categoryId: ToolkitCategoryId.classroomCulture,
        name: 'The Signal System',
        when: "You need the class's attention without yelling",
        instead: "Raising your voice (which just raises everyone's volume)",
        tryThis:
            'A consistent signal: a chime, a clap pattern, a hand '
            'raised and held. The room learns: when this happens, I '
            'stop and look. Practice it explicitly. Time it. Make it a '
            'game. "Let\'s see if we can all be silent in under 5 '
            'seconds." Celebrate when they nail it.',
        why:
            'Yelling trains kids to respond only to volume. A quiet '
            'signal trains them to LISTEN. It also protects your '
            'voice, your energy, and your relationship with the class.',
        quick: 'Pick one signal. Practice it. Time it. Celebrate improvements.',
      ),
      ToolkitTool(
        slug: 'culture.class-agreement',
        categoryId: ToolkitCategoryId.classroomCulture,
        name: 'The Class Agreement',
        when: 'First week of school, revisited monthly',
        instead: "Teacher's rules posted on the wall",
        tryThis:
            '"What kind of classroom do we WANT? Not rules — what does '
            'it FEEL like when it\'s working?" Let the kids generate '
            'it. Write it in their words. "We listen when someone is '
            'talking." "We help each other when it\'s hard." "We don\'t '
            'laugh when someone makes a mistake." They own it because '
            'they wrote it.',
        why:
            'Rules imposed from above create compliance. Agreements '
            'created together create ownership. When a kid breaks the '
            'agreement, you can say: "Is this what we agreed to?" — '
            "and it's the KID's standard, not yours.",
        quick:
            "What does our classroom feel like when it's working? "
            "Write their answers. That's the agreement.",
      ),
      ToolkitTool(
        slug: 'culture.comeback-ritual',
        categoryId: ToolkitCategoryId.classroomCulture,
        name: 'The Comeback Ritual',
        when:
            'A kid returns after being absent, suspended, or having a '
            'rough time',
        instead: 'Pretending nothing happened / Making a big deal',
        tryThis:
            'A simple, warm re-entry. "We missed you. Glad you\'re '
            'back." Then privately: "Do you need anything today? '
            "I'm here.\" No interrogation. No public questions. Just: "
            'the door is open and you belong here.',
        why:
            "A kid coming back is vulnerable. They're wondering: do "
            'they still want me here? Am I in trouble? Did anyone '
            'notice? The comeback ritual answers all three: yes we '
            "want you, no you're not in trouble, yes we noticed.",
        quick:
            "We missed you. Glad you're back. [Privately:] Need "
            'anything today?',
      ),
      ToolkitTool(
        slug: 'culture.volume-map',
        categoryId: ToolkitCategoryId.classroomCulture,
        name: 'The Volume Map',
        when: 'Different activities need different energy levels',
        instead: '"Keep it down!" all day (suppresses natural energy)',
        tryThis:
            'Name the levels: Level 1 = silent work. Level 2 = whisper '
            'pairs. Level 3 = group talk. Level 4 = whole class '
            'discussion. Level 5 = celebration / outdoor voice. Before '
            'each activity: "This is a Level 2 moment." Kids '
            'self-regulate because they know the expectation.',
        why:
            '"Be quiet" is vague and constant and exhausting. The '
            "volume map gives kids a framework. They're not being "
            "quiet because you said so — they're matching the level to "
            "the activity. That's self-regulation, not obedience.",
        quick:
            'Name 5 levels. Post them. Before each activity, state '
            'the level. Kids self-regulate.',
      ),
      ToolkitTool(
        slug: 'culture.last-five-minutes',
        categoryId: ToolkitCategoryId.classroomCulture,
        name: 'The Last 5 Minutes',
        when: 'End of every single day',
        instead: 'Rushing to dismissal',
        tryThis:
            'Five minutes of closure. "One thing you learned. One '
            "thing you're proud of. One thing you're looking forward to "
            'tomorrow." Or simply: "What was the best part of today?" '
            'End warm. Always. The last thing they feel before leaving '
            'becomes what they carry home.',
        why:
            'Kids carry the end of the day into the evening. A rushed, '
            'chaotic dismissal sends them home dysregulated. A warm, '
            'intentional close sends them home feeling seen. It also '
            'gives YOU a chance to end YOUR day well.',
        quick:
            'Best part of today? See you tomorrow. [Genuine warmth. '
            'Every day.]',
      ),
    ],
  ),
  ToolkitCategory(
    id: ToolkitCategoryId.selfCare,
    name: 'Teacher Self-Care',
    glyph: '☉',
    color: Color(0xFF51CF66),
    tagline:
        "You can't pour from an empty cup — and that's not a cliché, "
        "it's physics",
    tools: [
      ToolkitTool(
        slug: 'self.honest-check-in',
        categoryId: ToolkitCategoryId.selfCare,
        name: 'The Honest Check-In',
        when: 'Every morning before the kids arrive',
        instead: 'Powering through on autopilot',
        tryThis:
            'Ask yourself the same 1-10 question you ask your kids. '
            "Where am I today? If you're below a 5, adjust the plan. "
            'Less energy-intensive activities. More independent work. '
            "A video you've been saving. Not every day needs to be a "
            'performance. Some days you just need to survive, and '
            "that's okay.",
        why:
            "Teachers who don't monitor their own state burn out, "
            'snap at kids, and lose the thing that makes them good '
            "— their warmth. A 6/10 teacher who knows they're at 6 "
            'teaches better than a 3/10 teacher pretending to be a 10.',
        quick:
            "1-10, where am I? Below 5 = gentler plan today. That's "
            "not failure. That's wisdom.",
      ),
      ToolkitTool(
        slug: 'self.debrief-buddy',
        categoryId: ToolkitCategoryId.selfCare,
        name: 'The Debrief Buddy',
        when: 'After a hard day, a hard moment, or a hard week',
        instead: 'Processing alone (or not processing at all)',
        tryThis:
            'One colleague you trust. Not your admin — a peer. "Can '
            'I have 5 minutes? Today was rough." Vent. Be heard. No '
            'advice needed unless you ask. Then move on. The '
            'processing is the point, not the solution.',
        why:
            'Teaching is emotionally intense work and most teachers '
            "have zero space to process it. The feelings don't go "
            'away — they accumulate. A debrief buddy keeps the '
            'backlog from breaking you.',
        quick:
            'Find one person. "Can I have 5 minutes?" Vent. Be heard. '
            'Done.',
      ),
      ToolkitTool(
        slug: 'self.good-folder',
        categoryId: ToolkitCategoryId.selfCare,
        name: 'The Good Folder',
        when: "When you're doubting yourself",
        instead: 'Focusing on what went wrong',
        tryThis:
            'A folder (physical or digital) where you keep every '
            'thank-you note, every parent email, every kid drawing, '
            "every moment you're proud of. On the hard days, open it. "
            "It's evidence that you matter. Not motivation — evidence.",
        why:
            'Teaching is one of the few professions where the '
            'feedback loop is broken. You change lives but rarely see '
            'the results. The good folder is your own running record '
            '— proof that the work works.',
        quick:
            'Save every thank-you. Every kind note. Open the folder '
            'when you need it.',
      ),
      ToolkitTool(
        slug: 'self.boundary-bell',
        categoryId: ToolkitCategoryId.selfCare,
        name: 'The Boundary Bell',
        when: 'When school follows you home',
        instead: 'Checking email at 10pm, grading until midnight',
        tryThis:
            "Pick a time. 6pm, 7pm, whatever works. That's the bell. "
            'After the bell: no email, no grading, no lesson '
            "planning, no thinking about Jayden's behavior today. The "
            "work will be there tomorrow. You won't be if you don't "
            'stop.',
        why:
            "The job is infinite. There's always more to do. If you "
            "don't draw the line, the job will consume every hour you "
            "have. The boundary isn't selfish — it's how you stay in "
            'this profession for 30 years instead of 5.',
        quick:
            "Pick a time. After that time: school doesn't exist until "
            'tomorrow morning.',
      ),
      ToolkitTool(
        slug: 'self.permission-slip',
        categoryId: ToolkitCategoryId.selfCare,
        name: 'The Permission Slip',
        when: 'When you feel guilty for not being perfect',
        instead: 'Holding yourself to an impossible standard',
        tryThis:
            'Say to yourself: "I am allowed to have a bad lesson. I '
            'am allowed to not reach every kid today. I am allowed to '
            "use a worksheet because I'm exhausted. I am allowed to "
            'be a human being who teaches, not a teaching machine who '
            'happens to be human."',
        why:
            'The best teachers are often the hardest on themselves. '
            'The guilt is a sign you care — but it can also destroy '
            'you. Permission to be imperfect is not lowering your '
            "standards. It's sustaining your ability to meet them.",
        quick:
            "I'm allowed to be a human who teaches. Today that's "
            'enough.',
      ),
      ToolkitTool(
        slug: 'self.why-reminder',
        categoryId: ToolkitCategoryId.selfCare,
        name: 'The Why Reminder',
        when: "When you've forgotten why you do this",
        instead: 'Grinding through another year on fumes',
        tryThis:
            'Write a letter to yourself at the beginning of the year: '
            'why did you become a teacher? What moment made you choose '
            'this? What do you believe about kids? Seal it. Open it '
            'in February (the hardest month). Read it. Remember.',
        why:
            'February is when most teachers consider quitting. The '
            "letter isn't motivation — it's a time capsule from your "
            'most hopeful self, sent to your most exhausted self. It '
            'says: this is why. This matters. You matter.',
        quick:
            'Write the letter in August. Open it in February. '
            'Remember why.',
      ),
    ],
  ),
];

/// Lookup by stable slug — used by the eventual overrides table to
/// reference a specific built-in tool.
ToolkitTool? findToolBySlug(String slug) {
  for (final cat in toolkitCatalog) {
    for (final tool in cat.tools) {
      if (tool.slug == slug) return tool;
    }
  }
  return null;
}

/// Flat list of every tool across categories — convenient for search.
/// Computed once at first access (the unmodifiable wrapper guards
/// callers from mutating the cache).
final List<ToolkitTool> allToolkitTools = List.unmodifiable([
  for (final c in toolkitCatalog) ...c.tools,
]);

/// Lookup a category by its enum id.
ToolkitCategory categoryById(ToolkitCategoryId id) =>
    toolkitCatalog.firstWhere((c) => c.id == id);
