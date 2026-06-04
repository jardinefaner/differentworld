import 'package:differentworld/features/tools/thinking_tool.dart';

/// Universal thinking tools (docs/THINKING_TOOLS.md, Phase 2) — mental models
/// and methods that reach past the classroom: "for thinking, communicating,
/// teaching, doing." Reference cards in the same shape as the editorial
/// Toolkit (when / why / one move you can make), distilled to one usable form
/// each. Runnable versions (a Think-Pair-Share timer, a 5-Whys stepper) are a
/// later slice; these read.
const List<ThinkingTool> universalThinkingTools = <ThinkingTool>[
  ThinkingTool(
    id: 'first-principles',
    kind: ToolKind.reference,
    name: 'First Principles',
    blurb: 'Strip a problem to what you KNOW is true, then build up',
    whenToUse:
        "You're copying how it's always been done, or an expert says "
        '"that\'s just how it works."',
    why:
        'Reasoning by analogy carries hidden assumptions forward. Boiling a '
        'problem down to its bedrock facts lets you rebuild without inheriting '
        "someone else's constraints — which is where new answers live.",
    script: 'Ask: what do we know for certain here? Now build only from those.',
    tags: ['reasoning', 'problem solving', 'innovation'],
  ),
  ThinkingTool(
    id: 'five-whys',
    kind: ToolKind.reference,
    name: 'The 5 Whys',
    blurb: 'Trace a problem to its root by asking "why" five times',
    whenToUse:
        'Something went wrong and the obvious cause feels too shallow to '
        'actually fix.',
    why:
        'The first answer is usually a symptom. Each "why" peels a layer until '
        'you reach a cause you can change once instead of patching forever.',
    script: 'Ask "why did that happen?" — then ask it again of the answer, '
        'about five times, until it stops being a person and starts being a '
        'system.',
    tags: ['root cause', 'problem solving', 'systems'],
  ),
  ThinkingTool(
    id: 'inversion',
    kind: ToolKind.reference,
    name: 'Inversion',
    blurb: 'Solve it backwards — how would this FAIL?',
    whenToUse:
        "You can't see how to make something succeed, or a plan feels "
        "fragile but you're not sure where.",
    why:
        'Avoiding stupidity is easier than seeking brilliance. Listing every '
        'way a thing could fail, then preventing those, often beats trying to '
        'design success head-on.',
    script:
        'Ask: what would guarantee this goes wrong? Now make sure none of '
        'those happen.',
    tags: ['decisions', 'planning', 'risk'],
  ),
  ThinkingTool(
    id: 'second-order',
    kind: ToolKind.reference,
    name: 'Second-Order Thinking',
    blurb: '"And then what?" — the consequences of the consequences',
    whenToUse:
        'A choice looks obviously good on first glance — a quick fix, an easy '
        'yes.',
    why:
        'First-order effects are visible and immediate; the costs usually hide '
        'one step downstream. Most bad decisions are good first-order ideas '
        'nobody followed forward.',
    script: 'After "this will do X," ask "…and then what?" two or three more '
        'times.',
    tags: ['decisions', 'consequences', 'planning'],
  ),
  ThinkingTool(
    id: 'steel-man',
    kind: ToolKind.reference,
    name: 'Steel-Manning',
    blurb: 'Argue the STRONGEST version of the other side',
    whenToUse:
        'You disagree with someone — a co-teacher, a parent, a policy — and '
        'want to be right, not just win.',
    why:
        'Beating a weak version of an argument (a straw man) teaches you '
        'nothing. Building the best version of it either changes your mind or '
        'makes your own case unbreakable.',
    script: "Before you respond, say their point back so well they'd agree "
        '"yes, that\'s what I mean" — then answer THAT.',
    tags: ['communication', 'conflict', 'reasoning'],
  ),
  ThinkingTool(
    id: 'think-pair-share',
    kind: ToolKind.reference,
    name: 'Think · Pair · Share',
    blurb: 'Everyone thinks first, talks in twos, then shares to the group',
    whenToUse:
        'A discussion where the same three voices always answer and the rest '
        'go quiet.',
    why:
        'Private think-time lets the slow-and-deep contribute; pairing gives a '
        'low-stakes rehearsal; sharing surfaces ideas that would never have '
        'survived a cold call. Participation goes wide, not loud.',
    script:
        'Pose the question. 60s silent think. 90s in pairs. Then a few pairs '
        'share what their PARTNER said.',
    tags: ['teaching', 'discussion', 'participation'],
  ),
  ThinkingTool(
    id: 'systems-thinking',
    kind: ToolKind.reference,
    name: 'Systems Thinking',
    blurb: 'See the loops and flows, not just the parts',
    whenToUse:
        'The same problem keeps coming back no matter how many times you fix '
        'the instance.',
    why:
        'Recurring problems live in the structure — the feedback loops, '
        'delays, and incentives — not the people. Change the loop and the '
        'symptom stops; blame the person and it returns next week.',
    script:
        'Ask: what keeps producing this? Draw what feeds what. Look for the '
        'loop, then change the loop — not the latest instance.',
    tags: ['systems', 'root cause', 'patterns'],
  ),
  ThinkingTool(
    id: 'map-territory',
    kind: ToolKind.reference,
    name: 'The Map Is Not the Territory',
    blurb: "Your model of a thing isn't the thing — go check",
    whenToUse:
        "You're sure you know what a kid, a parent, or a situation is about "
        "before you've actually looked.",
    why:
        'Every plan, label, and reputation is a simplified map. Useful, but '
        'never complete — and when the map and the ground disagree, the ground '
        'wins. Confusing the two is how good people get blindsided.',
    script:
        'Ask: what would I see if my picture of this were wrong? Then go look '
        'for it.',
    tags: ['reasoning', 'observation', 'humility'],
  ),
  ThinkingTool(
    id: 'occams-razor',
    kind: ToolKind.reference,
    name: "Occam's Razor",
    blurb: 'Prefer the simplest explanation that fits the facts',
    whenToUse:
        "You're building an elaborate theory for why something happened "
        '(a behavior, a conflict, a mistake).',
    why:
        'Each added assumption is another thing that has to be true. The '
        'explanation with the fewest moving parts is usually right — and '
        'always the cheapest to test first.',
    script: "Ask: what's the plainest thing that would explain all of this? "
        'Rule that out before inventing anything fancier.',
    tags: ['reasoning', 'problem solving'],
  ),
  ThinkingTool(
    id: 'ten-ten-ten',
    kind: ToolKind.reference,
    name: '10 / 10 / 10',
    blurb: 'How will this feel in 10 minutes, 10 months, 10 years?',
    whenToUse:
        'A decision feels huge in the heat of the moment — a hard conversation, '
        'a reaction you might regret.',
    why:
        'Emotion compresses time; everything feels permanent right now. '
        'Stretching the timeline back out separates what actually matters '
        'long-term from what only stings today.',
    script:
        "Before you act, ask how you'll feel about this in 10 minutes, 10 "
        'months, and 10 years. Decide from the answer that matters most.',
    tags: ['decisions', 'self-management', 'perspective'],
  ),
];
