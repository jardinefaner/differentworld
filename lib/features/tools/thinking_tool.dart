import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/features/tools/thinking_tools_catalog.dart';

/// Whether a tool is something you READ (a distilled reference card) or RUN
/// (launched with the room). Some tools will eventually be both; v1 keeps it
/// to one face each.
enum ToolKind { reference, runnable }

/// The unified shape behind the Thinking Tools library
/// (docs/THINKING_TOOLS.md, Phase 1). One shelf over two sources that already
/// exist: the editorial **Toolkit** (reference cards) and the runnable
/// **activities** (run with the room). A plain immutable view-model — adapters
/// map each source into it; nothing existing is rewritten or deleted.
class ThinkingTool {
  const ThinkingTool({
    required this.id,
    required this.kind,
    required this.name,
    required this.blurb,
    this.route,
    this.whenToUse,
    this.why,
    this.script,
    this.tags = const <String>[],
  }) : assert(
         kind != ToolKind.runnable || route != null,
         'A runnable tool must carry a launch route — otherwise the "Run" '
         'affordance would advertise an action it cannot deliver.',
       );

  /// Adapt one editorial Toolkit tool into the unified shape (reference-only —
  /// no route, carries the when/why/script reference face).
  factory ThinkingTool.fromToolkit(ToolkitTool t) => ThinkingTool(
    id: t.slug,
    kind: ToolKind.reference,
    name: t.name,
    // The situation reads well as the card subtitle ("when to reach for it").
    blurb: t.when,
    whenToUse: t.when,
    why: t.why,
    script: t.quick,
    tags: <String>[t.categoryId.name],
  );

  /// Stable id. Reference tools reuse the Toolkit slug; runnable tools use
  /// their activity id.
  final String id;
  final ToolKind kind;

  /// Short title.
  final String name;

  /// One-line "what it's for" — the card subtitle.
  final String blurb;

  /// [ToolKind.runnable] only: the go_router path that launches it.
  final String? route;

  /// Reference face (from the Toolkit): the situation, the rationale, and the
  /// one-line script. Null for runnable-only tools.
  final String? whenToUse;
  final String? why;
  final String? script;

  /// Free-text tags for search / grouping (e.g. the Toolkit category).
  final List<String> tags;

  bool get isRunnable => kind == ToolKind.runnable;

  /// Lowercase haystack for fuzzy search.
  String get searchHaystack =>
      '$name $blurb ${whenToUse ?? ''} ${script ?? ''} ${tags.join(' ')}'
          .toLowerCase();
}

/// The runnable thinking tools — the articulate / reason / collaborate
/// activities from the Brain Breaks deck, surfaced as first-class library
/// entries. A curated SUBSET on purpose: the pure brain-breaks (Breathe,
/// Photo Studio, Make a Pattern) aren't thinking tools and stay out.
///
/// These routes mirror the deck (`brain_breaks_screen.dart`). Phase 2
/// reconciles the two into a single source of truth; for now this small
/// hand-curated list is the decoupled seed.
const List<ThinkingTool> runnableThinkingTools = <ThinkingTool>[
  ThinkingTool(
    id: 'this-or-that',
    kind: ToolKind.runnable,
    name: 'Quick Picks',
    blurb: 'This or that? — pick a side and say why',
    route: '/activity/this-or-that',
    tags: <String>['preference', 'reasoning', 'warm-up'],
  ),
  ThinkingTool(
    id: 'as-if',
    kind: ToolKind.runnable,
    name: 'Act It Out',
    blurb: 'Say it as if… — step into a perspective',
    route: '/activity/as-if',
    tags: <String>['perspective', 'empathy'],
  ),
  ThinkingTool(
    id: 'story',
    kind: ToolKind.runnable,
    name: 'Story Starters',
    blurb: 'Build a story together, one line each',
    route: '/activity/story',
    tags: <String>['collaboration', 'creativity'],
  ),
  ThinkingTool(
    id: 'discussions',
    kind: ToolKind.runnable,
    name: 'Group Talk',
    blurb: 'Discuss — by topic and age',
    route: '/activity/discussions',
    tags: <String>['socratic', 'discussion'],
  ),
  ThinkingTool(
    id: 'fact-or-fib',
    kind: ToolKind.runnable,
    name: 'Fact or Fib',
    blurb: 'True, or made up? — reason it out',
    route: '/activity/fact-or-fib',
    tags: <String>['reasoning', 'evidence'],
  ),
  ThinkingTool(
    id: 'riddles',
    kind: ToolKind.runnable,
    name: 'Riddle Me This',
    blurb: 'Guess the answer — think it through',
    route: '/activity/riddles',
    tags: <String>['lateral', 'puzzle'],
  ),
  ThinkingTool(
    id: 'speak',
    kind: ToolKind.runnable,
    name: 'Speak',
    blurb: 'Read a prompt aloud with big karaoke subtitles',
    route: '/speak',
    tags: <String>[
      'read aloud',
      'karaoke',
      'subtitles',
      'voice',
      'narrate',
      'literacy',
    ],
  ),
];

/// The unified Thinking Tools library: every runnable tool + every editorial
/// reference tool, one shelf. Runnable tools lead (the distinctive "run it
/// with the room" face); the reference set follows.
List<ThinkingTool> buildToolLibrary() => <ThinkingTool>[
  ...runnableThinkingTools,
  ...universalThinkingTools,
  for (final category in toolkitCatalog)
    for (final tool in category.tools) ThinkingTool.fromToolkit(tool),
];
