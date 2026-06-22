/// Catalog of the full-screen activity RUNNERS a scheduled block can launch
/// directly (instead of the generic `/arc` teaching arc).
///
/// Each entry mirrors a `/activity/<slug>` route already wired in
/// `router.dart` — this file does NOT define routes, it names the
/// launchable ones so a stored `runner_slug` capability on an Activity can
/// resolve to "open THIS runner."
///
/// Why a const catalog (not a table): the runners are code surfaces, fixed
/// at build time; "don't add a table to hold what code constants express."
/// A director picks one per Activity; the picked slug rides the Activity's
/// `capabilities` JSON (key `ActivityCaps.runnerSlug`).
library;

/// One launchable activity runner.
class ActivityRunner {
  const ActivityRunner({
    required this.slug,
    required this.route,
    required this.label,
    this.takesPrompt = false,
  });

  /// Stable id stored on the Activity's caps (`runner_slug`). Matches the
  /// last path segment of [route] (e.g. `photo` ↔ `/activity/photo`).
  final String slug;

  /// The go_router path this runner lives at.
  final String route;

  /// Human label for the "Runs as" picker.
  final String label;

  /// Whether the route accepts a `?prompt=` query parameter that seeds an
  /// on-screen instruction (only Photo Studio today).
  final bool takesPrompt;
}

/// Every full-screen runner a block can launch. Order is "creator / maker
/// surfaces first, then host-run games, then the conducted math" so the
/// picker reads roughly by how a director thinks of them.
const List<ActivityRunner> kActivityRunners = [
  // Maker / creator surfaces — produce something that persists.
  ActivityRunner(
    slug: 'photo',
    route: '/activity/photo',
    label: 'Photo Studio',
    takesPrompt: true,
  ),
  ActivityRunner(slug: 'do-it', route: '/activity/do-it', label: 'Do It'),
  ActivityRunner(
    slug: 'penny',
    route: '/activity/penny',
    label: 'Penny for a Thought',
  ),
  ActivityRunner(slug: 'potions', route: '/activity/potions', label: 'Potions'),
  ActivityRunner(slug: 'letters', route: '/activity/letters', label: 'Letters'),
  ActivityRunner(
    slug: 'fill-blank',
    route: '/activity/fill-blank',
    label: 'Fill in the Blank',
  ),
  ActivityRunner(
    slug: 'pattern',
    route: '/activity/pattern',
    label: 'Make a Pattern',
  ),
  ActivityRunner(
    slug: 'breathe',
    route: '/activity/breathe',
    label: 'Mindful Minute',
  ),
  // Host-run games — ephemeral, content from the content bank.
  ActivityRunner(
    slug: 'this-or-that',
    route: '/activity/this-or-that',
    label: 'This or That',
  ),
  ActivityRunner(
    slug: 'starts-with',
    route: '/activity/starts-with',
    label: 'Starts With',
  ),
  ActivityRunner(slug: 'as-if', route: '/activity/as-if', label: 'As If'),
  ActivityRunner(slug: 'riddles', route: '/activity/riddles', label: 'Riddles'),
  ActivityRunner(
    slug: 'grid-reveal',
    route: '/activity/grid-reveal',
    label: 'Grid Reveal',
  ),
  ActivityRunner(
    slug: 'fact-or-fib',
    route: '/activity/fact-or-fib',
    label: 'Fact or Fib',
  ),
  ActivityRunner(
    slug: 'story',
    route: '/activity/story',
    label: 'Story Starters',
  ),
  ActivityRunner(
    slug: 'rhyme-time',
    route: '/activity/rhyme-time',
    label: 'Rhyme Time',
  ),
  ActivityRunner(
    slug: 'discussions',
    route: '/activity/discussions',
    label: 'Group Discussions',
  ),
  ActivityRunner(slug: 'roles', route: '/activity/roles', label: 'Role Cards'),
  // Math — the conducted runner + the one-question game.
  ActivityRunner(slug: 'math', route: '/activity/math', label: 'Math'),
  ActivityRunner(
    slug: 'math-game',
    route: '/activity/math-game',
    label: 'Math Game',
  ),
];

/// The runner for [slug], or null when [slug] is null / empty / unknown.
/// Unknown slugs (a runner that was removed since the Activity was tagged)
/// return null so callers fall back to the default `/arc` launch.
ActivityRunner? runnerForSlug(String? slug) {
  if (slug == null || slug.isEmpty) return null;
  for (final r in kActivityRunners) {
    if (r.slug == slug) return r;
  }
  return null;
}
