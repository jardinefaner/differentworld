// Many `nodes.add(...)` runs build the section list; cascades there
// hurt readability more than they help (same lint pattern as the
// overlay variant). Silenced per file.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/omnibox/bottom_omnibox_bar.dart';
import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/omnibox/omnibox_history.dart';
import 'package:differentworld/features/omnibox/omnibox_mode.dart';
import 'package:differentworld/features/omnibox/slash_commands.dart';
import 'package:differentworld/features/voice/deepgram_voice_service.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/floating_actions.dart';
import 'package:differentworld/shared/widgets/floating_back.dart';
import 'package:differentworld/shared/widgets/route_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Persistent app shell. Holds the bottom omnibox bar across every
/// route — the bar stays mounted through page transitions, so the
/// search affordance is always one tap away (thumb-zone) and the
/// experience reads like an LLM chat: composer at the bottom,
/// content above.
///
/// The shell ALSO manages the omnibox's expanded state. When the
/// bar's TextField gains focus, the shell overlays an
/// [_OmniboxResultsPanel] above the body. The route's content stays
/// mounted underneath so dismissing the omnibox returns the user
/// exactly where they were (state preserved, no rebuild).
///
/// Used as the `builder` of a `ShellRoute` in `app/router.dart` so
/// every authenticated route renders inside it.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  bool get _expanded => _focus.hasFocus;

  /// Current mode derived from query + catalog. Recomputed inside
  /// `build` (cheap — single catalog pass with each entry's existing
  /// `score()`). Passed to the bar so its icon / hint morphs, and to
  /// the results panel so it can show the Save-as-capture affordance
  /// when in capture mode.
  OmniboxMode _mode = OmniboxMode.search;

  /// Subscription to the Deepgram voice controller's updates. Non-
  /// null only while a session is live; we tear it down on stop.
  StreamSubscription<VoiceUpdate>? _voiceSub;

  /// Whether the mic button should render as "listening" (red dot,
  /// tap-to-stop). Synced from voice updates.
  bool _voiceActive = false;

  /// What the composer's text was BEFORE the user started dictating.
  /// We restore this prefix and append the transcript so a partial
  /// existing query (e.g. typed "Owen ") isn't blown away by the
  /// voice session.
  String _voicePrefix = '';

  /// Cached voice controller. We grab it via `ref.read` in
  /// `_toggleVoice` and stash it here so `dispose()` can call
  /// `cancel()` without touching `ref` — `ref.read` after the
  /// element is deactivated throws.
  DeepgramVoiceController? _voice;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    unawaited(_voiceSub?.cancel());
    _voiceSub = null;
    // Drop any in-flight session so the WS / mic don't leak past
    // shell teardown. cancel() is fire-and-forget — the controller
    // is provider-owned and survives the shell. We use the cached
    // reference because `ref.read` is unsafe in dispose.
    unawaited(_voice?.cancel());
    _voice = null;
    _focus.removeListener(_onFocusChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // setState so the expanded results panel shows/hides as the bar's
    // field gains and loses focus.
    setState(() {});
  }

  void _clear() {
    _ctrl.clear();
    setState(() => _query = '');
  }

  void _collapse() {
    _clear();
    _focus.unfocus();
  }

  /// Paint the active route's chrome (back button + actions OR a
  /// full-width top overlay) as floating Positioned widgets at the
  /// top of the AppShell's body Stack. Returns a flat list so the
  /// caller can spread it directly into Stack.children.
  ///
  /// Returns an empty list when the chrome is "nothing" (the default
  /// pre-EdgeScaffold-mount state, or the home page).
  List<Widget> _buildTopChrome(RouteChrome chrome, double topInset) {
    // The top overlay (Today's inline search bar) takes over the
    // whole top row.
    if (chrome.topOverlay != null) {
      return [
        Positioned(
          top: topInset + 8,
          left: 8,
          right: 8,
          child: chrome.topOverlay!,
        ),
      ];
    }
    final widgets = <Widget>[];
    if (chrome.showBack) {
      widgets.add(
        Positioned(
          top: topInset + 8,
          left: 8,
          child: FloatingBack(fallbackRoute: chrome.backFallbackRoute),
        ),
      );
    }
    if (chrome.actions.isNotEmpty) {
      widgets.add(
        Positioned(
          top: topInset + 8,
          right: 8,
          child: FloatingActions(children: chrome.actions),
        ),
      );
    }
    return widgets;
  }

  void _onResultSelected(OmniboxEntry entry) {
    // Collapse first so the bar / keyboard go away cleanly, then fire
    // the action on the next frame so the destination route lands on
    // a clean shell (not on top of an open keyboard).
    bumpRecent(ref, entry.id);
    _collapse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      entry.onSelect(context, ref);
    });
  }

  /// Fire the capture action with the current query, then collapse +
  /// snackbar. The composer becomes the capture surface — typing
  /// "Owen napped well today" + return saves a capture without ever
  /// opening a separate capture sheet.
  Future<void> _saveAsCapture(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final actions = ref.read(captureActionsProvider);
    _collapse();
    await runReported(
      library: 'captures',
      messenger: messenger,
      onSuccess: 'Saved as a capture.',
      onError: 'Could not save the capture.',
      action: () => actions.start(body: body),
    );
  }

  /// Called when the user hits return on the bar's TextField. The
  /// behavior depends on the current mode:
  ///   - Capture mode → save the typed text as a capture
  ///   - Slash mode → exec the best-matching slash command
  ///   - Search mode → open the top-ranked result (if any)
  void _onComposerSubmit(String text) {
    if (_mode == OmniboxMode.capture) {
      unawaited(_saveAsCapture(text));
      return;
    }
    if (_mode == OmniboxMode.slash) {
      _execSlash(text);
      return;
    }
    final catalog = ref.read(omniboxCatalogProvider);
    final q = text.toLowerCase().trim();
    if (q.isEmpty) return;
    OmniboxEntry? best;
    var bestScore = 0;
    for (final e in catalog) {
      final s = e.score(q);
      if (s > bestScore) {
        bestScore = s;
        best = e;
      }
    }
    if (best == null) return;
    _onResultSelected(best);
  }

  /// Toggle the Deepgram voice session. Tap once → start recording
  /// + streaming; tap again → stop and keep what's transcribed.
  /// Errors surface via SnackBar.
  void _toggleVoice() {
    // The explicit type tells the analyzer the promoted result of
    // `??` is non-nullable — without it Dart's flow analysis loses
    // the promotion through the field assignment two lines down.
    // ignore: omit_local_variable_types
    final DeepgramVoiceController voice =
        _voice ?? ref.read(deepgramVoiceProvider);
    _voice = voice;
    if (_voiceActive) {
      unawaited(voice.stop());
      return;
    }
    // Capture whatever the user already typed so the dictated
    // transcript is APPENDED, not REPLACES it.
    _voicePrefix = _ctrl.text;
    setState(() => _voiceActive = true);
    _focus.requestFocus();
    _voiceSub = voice.updates.listen(_onVoiceUpdate);
    unawaited(voice.start());
  }

  void _onVoiceUpdate(VoiceUpdate update) {
    if (!mounted) return;
    if (update.state == VoiceState.error) {
      _voiceActive = false;
      unawaited(_voiceSub?.cancel());
      _voiceSub = null;
      final msg = update.errorMessage ?? 'Voice dictation failed.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(msg)),
      );
      setState(() {});
      return;
    }
    // Compose: existing typed prefix + a space + the live transcript.
    final transcript = update.transcript.trim();
    final glue = (_voicePrefix.isEmpty || transcript.isEmpty) ? '' : ' ';
    final combined = '$_voicePrefix$glue$transcript';
    _ctrl
      ..text = combined
      ..selection = TextSelection.collapsed(offset: combined.length);
    setState(() => _query = combined);

    if (update.state == VoiceState.idle) {
      // Session ended cleanly.
      _voiceActive = false;
      unawaited(_voiceSub?.cancel());
      _voiceSub = null;
      setState(() {});
    }
  }

  /// Resolve the typed slash query to a SlashCommand and run it.
  /// On exact name match, executes immediately. On ambiguous prefix
  /// match, the user must keep typing — Enter on an ambiguous prefix
  /// does nothing (so they can resolve it themselves).
  void _execSlash(String text) {
    final parsed = parseSlashQuery(text);
    final name = parsed.name;
    if (name == null || name.isEmpty) return;
    // Exact match wins; otherwise pick prefix match if unique.
    final exact = allSlashCommands.firstWhere(
      (c) => c.name == name || c.aliases.contains(name),
      orElse: () => allSlashCommands.firstWhere(
        (c) => c.matches(name),
        orElse: () => allSlashCommands.first,
      ),
    );
    // Sanity check — `firstWhere` with no match would have thrown
    // unless we caught it. Re-test exactness so we don't fire a
    // random command on a typo.
    if (exact.name != name &&
        !exact.aliases.contains(name) &&
        !exact.matches(name)) {
      return;
    }
    _collapse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      exact.exec(context, ref, parsed.args);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Detect mode on every keystroke. Cheap: single catalog pass.
    final catalog = ref.watch(omniboxCatalogProvider);
    _mode = detectMode(query: _query, catalog: catalog);

    // Kid mode strips the omnibox composer + bottom body padding so
    // the surface a kid sees has no escape hatch into staff-facing
    // routes. The route content fills the whole body. The top chrome
    // is suppressed too so a kid can't tap back into staff routes.
    final inKidMode = ref.watch(kidModeProvider);

    // Persistent top chrome — back button + per-route actions, lifted
    // into AppShell so they don't slide with the page during go_router
    // transitions. EdgeScaffold publishes the active route's chrome
    // into routeChromeProvider; we paint it here. Hidden in kid mode.
    final chrome = ref.watch(routeChromeProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    // When the omnibox is expanded, intercept system back so it
    // collapses the panel BEFORE go_router would pop the underlying
    // route. Without this, hitting back inside the omnibox pops you
    // out of the current screen entirely — surprising, and exactly
    // the "can't go back to current page" complaint.
    return PopScope(
      canPop: !_expanded,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_expanded) _collapse();
      },
      child: _buildShellScaffold(
        chrome: chrome,
        topInset: topInset,
        inKidMode: inKidMode,
      ),
    );
  }

  Widget _buildShellScaffold({
    required RouteChrome chrome,
    required double topInset,
    required bool inKidMode,
  }) {
    return Scaffold(
      // `resizeToAvoidBottomInset: true` is the load-bearing piece —
      // it shrinks the body so the keyboard occupies its own space
      // BELOW the body. The omnibox bar lives at the bottom of that
      // body (via the Stack + Positioned below), so it naturally
      // sits just above the keyboard with no extra math.
      //
      // Why not Scaffold.bottomNavigationBar? Material's bottom-nav
      // slot does NOT get pushed up by the keyboard — it stays at
      // the screen bottom and the keyboard paints over it, which is
      // exactly the bug we'd been hitting.
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // The route's content. Always mounted; visually covered by
          // the results panel when the omnibox is expanded.
          //
          // Padding-bottom = 76 reserves space for the persistent
          // omnibox bar that sits inside this Stack via the
          // Positioned widget below. Without this, the bottom 76 px
          // of every page (last list item, save button, etc.) would
          // render BEHIND the bar. In kid mode the bar is hidden, so
          // the route content fills the whole body.
          Padding(
            padding: EdgeInsets.only(bottom: inKidMode ? 0 : 76),
            child: widget.child,
          ),
          // Subtle scrim when expanded — the underlying route is
          // still visible but dimmed so the user's focus is on the
          // results.
          if (_expanded)
            Positioned.fill(
              child: GestureDetector(
                // Tap outside the results panel = dismiss / collapse.
                onTap: _collapse,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.12),
                ),
              ),
            ),
          if (_expanded)
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  // Leave room at the bottom equal to the bar so the
                  // panel never paints over it. The body's vertical
                  // extent already excludes the keyboard (see
                  // resizeToAvoidBottomInset above).
                  padding: const EdgeInsets.only(bottom: 76),
                  child: _OmniboxResultsPanel(
                    query: _query,
                    mode: _mode,
                    onSelected: _onResultSelected,
                    onSaveCapture: () => _saveAsCapture(_query),
                    onCloseTapped: _collapse,
                  ),
                ),
              ),
            ),
          // Persistent top chrome. Rendered ABOVE the route content
          // and the scrim/panel, so when the user pushes a new route
          // the page slides under static chrome — gives the app the
          // single-surface LLM feel (back + actions look anchored;
          // only the conversation/content moves).
          if (!inKidMode) ..._buildTopChrome(chrome, topInset),
          // Composer at the bottom of the body — sits flush above the
          // keyboard whenever it's up, flush above the home-indicator
          // safe area otherwise. Hidden entirely in kid mode so the
          // kid surface has no staff-facing affordance.
          if (!inKidMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomOmniboxBar(
                controller: _ctrl,
                focusNode: _focus,
                mode: _mode,
                voiceActive: _voiceActive,
                onChanged: (v) => setState(() => _query = v),
                onSubmit: _onComposerSubmit,
                onClear: _clear,
                onMicTap: _toggleVoice,
                onCollapse: _collapse,
              ),
          ),
        ],
      ),
    );
  }
}

/// The expanding results panel above the bottom bar. Reuses the
/// catalog + scoring + history infrastructure from
/// `omnibox_overlay.dart` but renders inline as a Material card
/// instead of a full-screen modal.
class _OmniboxResultsPanel extends ConsumerWidget {
  const _OmniboxResultsPanel({
    required this.query,
    required this.mode,
    required this.onSelected,
    required this.onSaveCapture,
    required this.onCloseTapped,
  });

  final String query;
  final OmniboxMode mode;
  final void Function(OmniboxEntry) onSelected;
  final VoidCallback onSaveCapture;
  final VoidCallback onCloseTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catalog = ref.watch(omniboxCatalogProvider);
    final byId = {for (final e in catalog) e.id: e};
    final recentIds =
        ref.watch(recentOmniboxIdsProvider).value ?? const <String>[];
    final pinnedIds =
        ref.watch(pinnedOmniboxIdsProvider).value ?? const <String>[];

    final q = query.trim().toLowerCase();
    final isSlash = mode == OmniboxMode.slash;
    final isCapture = mode == OmniboxMode.capture;

    // Slash mode shows the matching command list and nothing else —
    // search results would be noise once the user has committed to
    // verb-first navigation. Parsed once here so the panel + tile
    // can read it consistently.
    final parsedSlash = isSlash ? parseSlashQuery(query) : null;
    final slashMatches = isSlash
        ? matchSlashCommands(parsedSlash?.name)
        : const <SlashCommand>[];

    final nodes = (q.isEmpty || isSlash)
        ? <_Node>[]
        : _buildSearchSections(catalog: catalog, query: q);
    final idleNodes = q.isEmpty && !isSlash
        ? _buildIdleSections(
            catalog: catalog,
            byId: byId,
            recentIds: recentIds,
            pinnedIds: pinnedIds,
          )
        : const <_Node>[];

    // In capture mode, hoist a "Save as a capture" hero card to the
    // top of the panel. The user's free-form text is the preview;
    // tapping Save fires the capture without leaving the composer.
    // The catalog results (if any) still render underneath so the
    // user can pivot back to "I actually meant to search" with one
    // tap.

    // Idle mode (no query, search not slash) also surfaces the
    // user's recently saved captures — Slack-style "what did I just
    // write down?" recall. We pull the top 5 open captures from the
    // inbox stream and show them as a peek-list above the catalog
    // sections; tap routes to /captures so the user can edit /
    // promote / discard.
    final showRecentCaptures = q.isEmpty && !isCapture && !isSlash;
    final recentCaptures = showRecentCaptures
        ? (ref.watch(openCapturesProvider).value ?? const <Capture>[])
            .take(5)
            .toList()
        : const <Capture>[];

    final activeNodes = q.isEmpty ? idleNodes : nodes;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Material(
            color: scheme.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCapture)
                  _CaptureHeroCard(
                    text: query,
                    onSave: onSaveCapture,
                  ),
                if (recentCaptures.isNotEmpty)
                  _RecentCapturesStrip(
                    captures: recentCaptures,
                    onOpenInbox: () {
                      onCloseTapped();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        unawaited(context.push('/captures'));
                      });
                    },
                  ),
                if (isSlash)
                  _SlashCommandList(
                    matches: slashMatches,
                    parsedArgs: parsedSlash?.args,
                    onPick: (cmd) {
                      onCloseTapped();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        cmd.exec(context, ref, parsedSlash?.args);
                      });
                    },
                  ),
                if (activeNodes.isEmpty && !isCapture && !isSlash)
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: Text(
                        q.isEmpty
                            ? 'Type anything you want to do.'
                            : 'No matches for "$query".',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else if (activeNodes.isNotEmpty)
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: activeNodes.length,
                      itemBuilder: (_, i) {
                        final n = activeNodes[i];
                        if (n is _SectionHeader) {
                          return _SectionHeaderWidget(label: n.label);
                        }
                        if (n is _Entry) {
                          return _EntryTile(
                            entry: n.entry,
                            isPinned: pinnedIds.contains(n.entry.id),
                            onTap: () => onSelected(n.entry),
                            onTogglePin: () => ref
                                .read(pinnedOmniboxIdsProvider.notifier)
                                .toggle(n.entry.id),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // The next three methods mirror the logic in omnibox_overlay.dart's
  // _OmniboxResultsView. We deliberately keep them duplicated for now
  // — the two surfaces (full-screen modal + inline panel) need the
  // same behavior but with different chrome around them, and trying
  // to share them via a common widget would couple their lifecycles
  // unhelpfully.
  List<_Node> _buildIdleSections({
    required List<OmniboxEntry> catalog,
    required Map<String, OmniboxEntry> byId,
    required List<String> recentIds,
    required List<String> pinnedIds,
  }) {
    final nodes = <_Node>[];
    final pinnedEntries = pinnedIds
        .map((id) => byId[id])
        .whereType<OmniboxEntry>()
        .toList();
    if (pinnedEntries.isNotEmpty) {
      nodes.add(const _SectionHeader('Pinned'));
      nodes.addAll(pinnedEntries.map(_Entry.new));
    }
    final pinnedSet = pinnedEntries.map((e) => e.id).toSet();
    final recentEntries = recentIds
        .map((id) => byId[id])
        .whereType<OmniboxEntry>()
        .where((e) => !pinnedSet.contains(e.id))
        .toList();
    if (recentEntries.isNotEmpty) {
      nodes.add(const _SectionHeader('Recent'));
      nodes.addAll(recentEntries.take(6).map(_Entry.new));
    }
    final tag = currentContextTag(DateTime.now());
    final contextHits = catalog
        .where((e) => e.contextTags.contains(tag))
        .where((e) => !pinnedSet.contains(e.id))
        .where((e) => !recentEntries.map((r) => r.id).contains(e.id))
        .take(5)
        .toList();
    if (contextHits.isNotEmpty) {
      nodes.add(_SectionHeader('For you now · $tag'));
      nodes.addAll(contextHits.map(_Entry.new));
    }
    final seen = <String>{
      ...pinnedSet,
      ...recentEntries.map((r) => r.id),
      ...contextHits.map((c) => c.id),
    };
    final byCategory = <OmniboxCategory, List<OmniboxEntry>>{};
    for (final e in catalog) {
      if (seen.contains(e.id)) continue;
      byCategory.putIfAbsent(e.category, () => []).add(e);
    }
    for (final cat in OmniboxCategory.values) {
      final list = byCategory[cat];
      if (list == null || list.isEmpty) continue;
      nodes.add(_SectionHeader(_pluralLabel(cat)));
      nodes.addAll(list.take(5).map(_Entry.new));
    }
    return nodes;
  }

  List<_Node> _buildSearchSections({
    required List<OmniboxEntry> catalog,
    required String query,
  }) {
    final scored = <(OmniboxEntry, int)>[];
    for (final e in catalog) {
      final s = e.score(query);
      if (s > 0) scored.add((e, s));
    }
    final groupBoost = <String, int>{};
    for (final e in catalog) {
      if (e.groupId == null) continue;
      if (e.label.toLowerCase().contains(query)) {
        groupBoost[e.groupId!] = (groupBoost[e.groupId!] ?? 0) + 60;
      }
    }
    if (groupBoost.isNotEmpty) {
      for (final e in catalog) {
        if (e.groupId == null) continue;
        final boost = groupBoost[e.groupId!];
        if (boost == null) continue;
        final existing = scored.indexWhere((p) => p.$1.id == e.id);
        if (existing >= 0) {
          scored[existing] = (e, scored[existing].$2 + boost);
        } else {
          scored.add((e, boost));
        }
      }
    }
    if (scored.isEmpty) return const <_Node>[];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final byCategory = <OmniboxCategory, List<(OmniboxEntry, int)>>{};
    for (final p in scored) {
      byCategory.putIfAbsent(p.$1.category, () => []).add(p);
    }
    final nodes = <_Node>[];
    for (final cat in OmniboxCategory.values) {
      final list = byCategory[cat];
      if (list == null || list.isEmpty) continue;
      nodes.add(_SectionHeader(_pluralLabel(cat)));
      for (final p in list.take(8)) {
        nodes.add(_Entry(p.$1));
      }
    }
    return nodes;
  }

  static String _pluralLabel(OmniboxCategory cat) => switch (cat) {
        OmniboxCategory.action => 'Actions',
        OmniboxCategory.page => 'Pages',
        OmniboxCategory.person => 'People',
        OmniboxCategory.classroom => 'Classrooms',
        OmniboxCategory.place => 'Locations',
        OmniboxCategory.activity => 'Activities',
        OmniboxCategory.vehicle => 'Vehicles',
        OmniboxCategory.setting => 'Settings',
      };
}

sealed class _Node {
  const _Node();
}

class _SectionHeader extends _Node {
  const _SectionHeader(this.label);
  final String label;
}

class _Entry extends _Node {
  const _Entry(this.entry);
  final OmniboxEntry entry;
}

class _SectionHeaderWidget extends StatelessWidget {
  const _SectionHeaderWidget({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.isPinned,
    required this.onTogglePin,
  });
  final OmniboxEntry entry;
  final VoidCallback onTap;
  final bool isPinned;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: entry.heroColor ?? scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(entry.icon, size: 18, color: scheme.onSurface),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              entry.category.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
      subtitle: entry.subtitle == null
          ? null
          : Text(
              entry.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
      trailing: IconButton(
        tooltip: isPinned ? 'Unpin' : 'Pin',
        icon: Icon(
          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          size: 18,
          color: isPinned ? scheme.primary : scheme.onSurfaceVariant,
        ),
        onPressed: onTogglePin,
      ),
      onTap: onTap,
    );
  }
}

/// The chameleon mode's hero affordance — when the omnibox shifts
/// into capture mode (because the user's free-form text doesn't
/// match the catalog), this card surfaces at the top of the results
/// panel. It echoes the typed text back so the user sees exactly
/// what they're about to save, then offers a single primary "Save"
/// button.
///
/// The card lives ABOVE the (possibly-empty) catalog results so
/// pivoting is one tap: tap Save and the capture lands; or tap a
/// catalog row below if the user actually meant to search.
///
/// Visually keyed to primaryContainer so it reads as the same
/// surface as the capture-mode bottom bar tint — the user gets a
/// continuous "this is the capture path" feel from composer to
/// hero card to confirmation snackbar.
class _CaptureHeroCard extends StatelessWidget {
  const _CaptureHeroCard({required this.text, required this.onSave});

  /// The user's typed text, echoed verbatim. We truncate visually
  /// via maxLines but never edit the text — the capture stores
  /// exactly what they typed.
  final String text;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trimmed = text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Tap anywhere on the card saves — same intent as the
          // primary button, just with a bigger target.
          onTap: onSave,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bolt_outlined,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SAVE AS A CAPTURE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Echo the typed text. Limited to ~5 lines so a wall
                // of pasted text doesn't push the catalog results
                // entirely off-screen — the capture still records
                // the full string.
                Text(
                  trimmed.isEmpty
                      ? 'Start typing a thought…'
                      : trimmed,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Press return — or tap Save',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Recent captures" strip in the omnibox idle panel — addresses the
/// "I forgot what I noted earlier" recall problem. Renders the top N
/// most-recent open captures as horizontally-scrolling chips. Each
/// chip shows the body's first few lines; tap routes to the capture
/// inbox where the user can edit / promote / discard.
///
/// Lives only in idle mode (empty query, search mode). Once the user
/// starts typing or shifts to capture mode, this strip hides.
class _RecentCapturesStrip extends StatelessWidget {
  const _RecentCapturesStrip({
    required this.captures,
    required this.onOpenInbox,
  });

  final List<Capture> captures;
  final VoidCallback onOpenInbox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'RECENT CAPTURES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onOpenInbox,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: captures.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = captures[i];
                return _CapturePeekChip(
                  body: c.body,
                  // Always opens the inbox — that's where the user
                  // can edit. Routing to a per-capture screen would
                  // be a nice future improvement.
                  onTap: onOpenInbox,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Slash command picker — shown in the omnibox panel whenever the
/// query starts with `/`. Filters the canonical command set to
/// commands whose name (or aliases) prefix-match what the user has
/// typed so far. Tap or hit return to execute.
class _SlashCommandList extends StatelessWidget {
  const _SlashCommandList({
    required this.matches,
    required this.parsedArgs,
    required this.onPick,
  });

  final List<SlashCommand> matches;

  /// What the user typed after the command name (e.g. "robins" from
  /// "/attendance robins"). Surfaced in the tile subtitle so the
  /// user can see how their args parsed before they hit Enter.
  final String? parsedArgs;

  final void Function(SlashCommand) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            'No commands match that prefix.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: matches.length,
        itemBuilder: (_, i) {
          final c = matches[i];
          return ListTile(
            dense: true,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                c.icon,
                size: 18,
                color: scheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              c.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            subtitle: Text(
              parsedArgs == null
                  ? c.hint
                  : '${c.hint} — args: $parsedArgs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            onTap: () => onPick(c),
          );
        },
      ),
    );
  }
}

/// A single chip in the recent-captures strip. Shows the first few
/// lines of the capture body. No timestamp — recency is implicit
/// from position; adding times would clutter what's meant to read as
/// a quick recall surface.
class _CapturePeekChip extends StatelessWidget {
  const _CapturePeekChip({required this.body, required this.onTap});

  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = body.trim().isEmpty ? '(empty)' : body.trim();
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 160,
            maxWidth: 220,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Text(
              preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
