// Many `nodes.add(...)` runs build the section list; cascades there
// hurt readability more than they help.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/omnibox/compose_draft_seed.dart';
import 'package:differentworld/features/omnibox/compose_intent.dart';
import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/omnibox/omnibox_history.dart';
import 'package:differentworld/features/omnibox/omnibox_mode.dart';
import 'package:differentworld/features/omnibox/omnibox_state.dart';
import 'package:differentworld/features/omnibox/slash_commands.dart';
import 'package:differentworld/features/voice/deepgram_voice_service.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The omnibox search surface — the app's "go anywhere" page at
/// `/search`.
///
/// **History.** Wave 17 made this a `/search` route. Wave 25 replaced
/// that with an in-shell OVERLAY because pushing the route rotated the
/// FocusScope and tore down the Android soft keyboard ("keyboard appears
/// then disappears") — the editable field lived in the shell BAR, so the
/// push moved focus away from it. The overlay then caused its own
/// problems: a left-swipe fell through the shell's PopScope to the
/// app-exit confirm, and the frosted glass over the page was hard to read.
///
/// **Wave-back-to-route (2026-06-20).** Back to a real route — but with
/// the key change that makes it work this time: the input FIELD now lives
/// **on this page**, autofocused, instead of in the shell bar. With the
/// field on the page there is no cross-route focus handoff: the page's
/// `autofocus: true` requests the IME fresh on mount, so the keyboard
/// comes up and stays up. The bottom bar is now just a tap-target that
/// pushes here.
///
/// The page is a SOLID [EdgeScaffold] (the app `surface`), not glass —
/// the search results are easy to read. It owns its own
/// [TextEditingController] + [FocusNode] and mirrors every keystroke into
/// [omniboxQueryProvider] so the existing result-building reacts exactly
/// as before. Selecting a result pops `/search` first (capturing a
/// long-lived root-navigator context so the post-pop dispatch survives the
/// page tear-down), then fires the entry's `onSelect`.
class OmniboxSearchScreen extends ConsumerStatefulWidget {
  const OmniboxSearchScreen({super.key});

  @override
  ConsumerState<OmniboxSearchScreen> createState() =>
      _OmniboxSearchScreenState();
}

class _OmniboxSearchScreenState extends ConsumerState<OmniboxSearchScreen> {
  /// The page's own composer field. Seeded from [omniboxQueryProvider]
  /// on mount (usually empty) and mirrored back into it on every change
  /// so the result-building below reacts. Autofocused — the IME raises
  /// on mount with no cross-route focus handoff.
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  /// Subscription to the Deepgram voice controller's updates. Non-null
  /// only while a session is live; torn down on stop / dispose.
  StreamSubscription<VoiceUpdate>? _voiceSub;

  /// Mic-button UI state — the "stop" affordance shows while a dictation
  /// session is active.
  bool _voiceActive = false;

  /// Which cohort a composed draft schedules into. Null = the first cohort.
  /// Sticky across queries so a director's pick persists. Only meaningful when
  /// the space has more than one group (the draft card shows a picker then).
  String? _draftGroupId;

  /// What the composer's text was BEFORE the user started dictating. We
  /// restore this prefix and append the transcript so a partial existing
  /// query isn't blown away by the voice session.
  String _voicePrefix = '';

  /// Cached voice controller so `dispose()` can cancel without touching
  /// `ref` (which is unsafe once the element is deactivated).
  DeepgramVoiceController? _voice;

  @override
  void initState() {
    super.initState();
    // Seed the field from whatever's in the query provider (usually
    // empty). Reading is safe synchronously; writing back is deferred
    // below to dodge the "modified provider while building" assertion.
    final seed = ref.read(omniboxQueryProvider);
    if (seed.isNotEmpty) {
      _ctrl
        ..text = seed
        ..selection = TextSelection.collapsed(offset: seed.length);
    }
    _ctrl.addListener(_onCtrlChanged);
    // AppShell watches omniboxQueryProvider; a synchronous write from
    // initState (which runs DURING the parent's build phase) trips the
    // "modified a provider while the widget tree was building" assertion.
    // Defer to a microtask — fires after this build phase but before the
    // next frame. Guard on `mounted` because a fast back can dispose us
    // before the microtask runs. (Only writes when the seed is non-empty;
    // an empty seed needs no clear since the provider is already empty.)
    if (seed.isNotEmpty) {
      unawaited(Future.microtask(() {
        if (!mounted) return;
        ref.read(omniboxQueryProvider.notifier).set(seed);
      }));
    }
  }

  @override
  void dispose() {
    unawaited(_voiceSub?.cancel());
    _voiceSub = null;
    unawaited(_voice?.cancel());
    _voice = null;
    _ctrl.removeListener(_onCtrlChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Mirror every field change into the query provider so the result
  /// sections re-render. The field owns the text; this provider is the
  /// canonical value the section builders read.
  void _onCtrlChanged() {
    if (kDebugMode) {
      debugPrint('[omnibox] queryChanged len=${_ctrl.text.length}');
    }
    ref.read(omniboxQueryProvider.notifier).set(_ctrl.text);
  }

  void _clearField() {
    _ctrl.clear();
    // The listener fires on clear() and mirrors the empty string into the
    // provider, so no explicit notifier.clear() is needed here. Keep the
    // field focused so the user can keep typing — and force the IME back
    // up: tapping the clear button briefly moves pointer focus off the
    // field, and `requestFocus()` ALONE is a no-op for the Android
    // keyboard when the framework treats focus as already-held (CLAUDE.md
    // interaction invariant #4), so the explicit show is load-bearing.
    _focus.requestFocus();
    unawaited(SystemChannels.textInput.invokeMethod('TextInput.show'));
  }

  /// Toggle the Deepgram voice session. Tap once → start recording +
  /// streaming; tap again → stop and keep the transcript. Errors surface
  /// via SnackBar. Moved here from AppShell — the mic now lives on the
  /// search page next to its field.
  void _toggleVoice() {
    // The explicit type tells the analyzer the promoted result of `??`
    // is non-nullable — without it Dart's flow analysis loses the
    // promotion through the field assignment two lines down.
    // ignore: omit_local_variable_types
    final DeepgramVoiceController voice =
        _voice ?? ref.read(deepgramVoiceProvider);
    _voice = voice;
    if (_voiceActive) {
      unawaited(voice.stop());
      return;
    }
    _voicePrefix = _ctrl.text;
    setState(() => _voiceActive = true);
    _focus.requestFocus();
    // Force the IME up even if Flutter thinks focus never moved.
    // `requestFocus()` alone is a no-op for the keyboard on Android if
    // the framework treats focus as already-held. The user started
    // dictation — they may also want to type alongside, so the keyboard
    // belongs on screen.
    unawaited(SystemChannels.textInput.invokeMethod('TextInput.show'));
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
    final transcript = update.transcript.trim();
    final glue = (_voicePrefix.isEmpty || transcript.isEmpty) ? '' : ' ';
    final combined = '$_voicePrefix$glue$transcript';
    // Writing to the controller fires _onCtrlChanged, which mirrors the
    // live transcript into the query provider — so the sections update as
    // the user dictates.
    _ctrl
      ..text = combined
      ..selection = TextSelection.collapsed(offset: combined.length);

    if (update.state == VoiceState.idle) {
      _voiceActive = false;
      unawaited(_voiceSub?.cancel());
      _voiceSub = null;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = ref.watch(omniboxQueryProvider);
    final catalog = ref.watch(omniboxCatalogProvider);
    final mode = detectMode(query: query, catalog: catalog);
    final byId = {for (final e in catalog) e.id: e};
    final recentIds =
        ref.watch(recentOmniboxIdsProvider).value ?? const <String>[];
    final pinnedIds =
        ref.watch(pinnedOmniboxIdsProvider).value ?? const <String>[];

    final q = query.trim().toLowerCase();
    final isSlash = mode == OmniboxMode.slash;
    final isCapture = mode == OmniboxMode.capture;

    // "Omnibox composes": in capture mode, try to read the free text as a
    // schedule intent ("field trip to the pond Friday"). When it parses AND
    // there's a cohort to schedule into, we offer a DRAFT above the note —
    // additive, never replacing the note fallback.
    final composeIntent = isCapture && q.isNotEmpty
        ? parseComposeIntent(query, now: DateTime.now())
        : null;
    final draftGroups = composeIntent == null
        ? const <Group>[]
        : (ref.watch(groupsProvider).value ?? const <Group>[]);
    // The selected cohort (sticky), falling back to the first. When there's
    // more than one, the draft card renders a picker so a director isn't
    // silently bound to whichever cohort happens to sort first.
    final draftGroup = draftGroups.isEmpty
        ? null
        : (draftGroups.where((g) => g.id == _draftGroupId).firstOrNull ??
            draftGroups.first);
    final canDraft = composeIntent != null && draftGroup != null;

    final parsedSlash = isSlash ? parseSlashQuery(query) : null;
    final viewer = ref.watch(viewerProvider);
    final slashMatches = isSlash
        ? matchSlashCommands(parsedSlash?.name, viewer: viewer)
        : const <SlashCommand>[];

    final labels = ref.watch(verticalLabelsProvider);

    final nodes = (q.isEmpty || isSlash)
        ? <_Node>[]
        : _buildSearchSections(
            catalog: catalog,
            query: q,
            labels: labels,
          );
    final idleNodes = q.isEmpty && !isSlash
        ? _buildIdleSections(
            catalog: catalog,
            byId: byId,
            recentIds: recentIds,
            pinnedIds: pinnedIds,
            labels: labels,
          )
        : const <_Node>[];

    final showRecentCaptures = q.isEmpty && !isCapture && !isSlash;
    final recentCaptures = showRecentCaptures
        ? (ref.watch(openCapturesProvider).value ?? const <Capture>[])
              .take(5)
              .toList()
        : const <Capture>[];

    final activeNodes = q.isEmpty ? idleNodes : nodes;

    // Stable dispatch context — this screen's own BuildContext
    // deactivates the instant we pop `/search`, so any post-frame
    // attempt to use it short-circuits via `mounted == false` and the
    // entry's action never fires. The root navigator's context lives for
    // the lifetime of the app, so we grab it BEFORE popping and use it
    // post-close. (CLAUDE.md interaction invariant: post-pop dispatch
    // needs a stable context.)
    final dispatchCtx = Navigator.of(context, rootNavigator: true).context;

    // Leave `/search` and return the user to the previous surface. The
    // dispatchCtx outlives this pop.
    void close() {
      if (context.canPop()) context.pop();
    }

    void selectEntry(OmniboxEntry entry) {
      bumpRecent(ref, entry.id);
      // Dismiss the IME first: the search field stays alive underneath now, so
      // without this the destination could appear with the keyboard still up.
      _focus.unfocus();
      // Keep `/search` in the back stack (do NOT pop) and keep the query (do
      // NOT clear): entries navigate via `ctx.push`, so the destination lands
      // ON TOP of the search page. A swipe-back from the destination then
      // returns to the search page exactly as the user left it — same query,
      // same results — which is the requested behaviour. (A `ctx.go` entry — a
      // top-level jump like Today — still resets the stack, the right thing for
      // a section switch, not a result.) Navigates from THIS page's live
      // context since we no longer pop it out from under the call.
      entry.onSelect(context, ref);
    }

    Future<void> saveAsCapture() async {
      final body = query.trim();
      if (body.isEmpty) return;
      // Read the messenger from the LONG-LIVED root-navigator context,
      // NOT this page's context: we pop `/search` immediately below, which
      // deactivates the page context, so a messenger captured from it
      // would be dead by the time `runReported` shows the success/error
      // snackbar (it'd silently no-op). `dispatchCtx` outlives the pop.
      final messenger = ScaffoldMessenger.maybeOf(dispatchCtx);
      final actions = ref.read(captureActionsProvider);
      ref.read(omniboxQueryProvider.notifier).clear();
      close();
      await runReported(
        library: 'captures',
        messenger: messenger,
        onSuccess: 'Saved as a capture.',
        onError: 'Could not save the capture.',
        action: () => actions.start(body: body),
      );
    }

    // Turn the parsed intent into a DRAFT block: stash the kind+note seed,
    // then open the block editor at the parsed day/time. Nothing is saved until
    // the user confirms in the editor (the middle-UI promise: structure out,
    // you confirm). Mirrors saveAsCapture's post-pop dispatch discipline.
    void draftBlock() {
      final intent = composeIntent;
      final group = draftGroup;
      if (intent == null || group == null) return;
      // In-flight guard: the card's InkWell, its "Draft it" button, AND the
      // Return key can each call this in the same frame. The first clears the
      // live query; any second call sees it empty and bails — no double push.
      if (ref.read(omniboxQueryProvider).trim().isEmpty) return;
      final drafts = ref.read(pendingBlockDraftProvider.notifier);
      drafts.draft = BlockDraftSeed(kind: intent.kind, title: intent.title);
      ref.read(omniboxQueryProvider.notifier).clear();
      close();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!dispatchCtx.mounted) {
          // Navigation aborted — don't leave the seed set to poison the next
          // organic "new block" create.
          drafts.draft = null;
          return;
        }
        unawaited(
          dispatchCtx.push<void>(
            '/schedule/block',
            extra: (
              groupId: group.id,
              defaultStart: intent.start,
              existing: null,
              prefillCurriculumSlug: null,
            ),
          ),
        );
      });
    }

    void runSlash(SlashCommand cmd) {
      ref.read(omniboxQueryProvider.notifier).clear();
      close();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!dispatchCtx.mounted) return;
        cmd.exec(dispatchCtx, ref, parsedSlash?.args);
      });
    }

    // What hitting return does — mirrors the old shell composer logic so
    // the field's submit feels identical: capture saves, slash runs the
    // command, search opens the top-ranked result. Never a dead key.
    void onSubmit(String text) {
      if (isCapture) {
        // Return runs the PRIMARY action: draft the block when the phrase
        // parsed as a schedule intent, otherwise save the note.
        if (canDraft) {
          draftBlock();
        } else {
          unawaited(saveAsCapture());
        }
        return;
      }
      if (isSlash) {
        if (slashMatches.isEmpty) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('No slash commands match that prefix.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        runSlash(slashMatches.first);
        return;
      }
      if (q.isEmpty) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Type something first, or tap a suggestion.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      // The first node in the (score-sorted, category-grouped) active list
      // is the best match. Skip headers to find it.
      final firstEntry = activeNodes.whereType<_Entry>().firstOrNull;
      if (firstEntry == null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('No match for "$text". Try fewer words.'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      selectEntry(firstEntry.entry);
    }

    final hasText = _ctrl.text.isNotEmpty;
    final searchField = _SearchFieldRow(
      controller: _ctrl,
      focusNode: _focus,
      mode: mode,
      hasText: hasText,
      voiceActive: _voiceActive,
      onSubmit: onSubmit,
      onClear: _clearField,
      onMicTap: _toggleVoice,
    );

    // SOLID page (the app `surface` via EdgeScaffold) — no glass / blur.
    // The search results are easy to read against the surface. The field
    // row is PINNED at the top of the body; the results scroll below it.
    // EdgeScaffold publishes the top-chrome band into MediaQuery.padding
    // .top, so the SafeArea here clears the floating back pill with no
    // per-screen topChromeHeight math.
    final body = SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          // Same max width the bar uses — keeps line lengths readable on
          // tablet / desktop.
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              if (composeIntent != null && draftGroup != null)
                _ComposeDraftCard(
                  intent: composeIntent,
                  groups: draftGroups,
                  selectedGroup: draftGroup,
                  onPickGroup: (id) => setState(() => _draftGroupId = id),
                  onDraft: draftBlock,
                ),
              if (isCapture)
                _CaptureHeroCard(
                  text: query,
                  onSave: saveAsCapture,
                  // When a draft is on offer, the note is the fallback — demote
                  // it so the draft reads as the primary action.
                  muted: canDraft,
                ),
              if (recentCaptures.isNotEmpty)
                _RecentCapturesStrip(
                  captures: recentCaptures,
                  onOpenInbox: () {
                    ref.read(omniboxQueryProvider.notifier).clear();
                    close();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!dispatchCtx.mounted) return;
                      unawaited(dispatchCtx.push('/captures'));
                    });
                  },
                ),
              if (isSlash)
                Expanded(
                  child: _SlashCommandList(
                    matches: slashMatches,
                    parsedArgs: parsedSlash?.args,
                    onPick: runSlash,
                  ),
                )
              else if (activeNodes.isEmpty && !isCapture)
                Expanded(
                  child: Padding(
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
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
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
                          onTap: () => selectEntry(n.entry),
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
    );

    return EdgeScaffold(body: body);
  }
}

/// The pinned search-field row at the top of the `/search` page —
/// leading mode glyph, the autofocused field, a clear (X) when non-empty,
/// and the voice mic. Mode (search / capture / slash) drives the leading
/// icon + hint, mirroring the old bottom-bar morphing so the surface
/// reads the same.
class _SearchFieldRow extends StatelessWidget {
  const _SearchFieldRow({
    required this.controller,
    required this.focusNode,
    required this.mode,
    required this.hasText,
    required this.voiceActive,
    required this.onSubmit,
    required this.onClear,
    required this.onMicTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final OmniboxMode mode;
  final bool hasText;
  final bool voiceActive;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCapture = mode == OmniboxMode.capture;
    final isSlash = mode == OmniboxMode.slash;

    // Three-way visual: search (default), capture (bolt + primary),
    // slash (terminal + tertiary). Each mode gets a distinct hint so the
    // user always knows what return will do.
    final IconData leadingIcon;
    final Color leadingTint;
    final String hint;
    final Color borderColor;
    if (isCapture) {
      leadingIcon = Icons.bolt;
      leadingTint = scheme.primary;
      hint = 'Save a quick note — press return';
      borderColor = scheme.primary;
    } else if (isSlash) {
      leadingIcon = Icons.terminal;
      leadingTint = scheme.tertiary;
      hint = 'Slash command — type /today, /log, /attendance…';
      borderColor = scheme.tertiary;
    } else {
      leadingIcon = Icons.search;
      leadingTint = scheme.onSurfaceVariant;
      hint = 'Search anything — pages, actions, kids…';
      borderColor = scheme.outlineVariant;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    leadingIcon,
                    key: ValueKey(leadingIcon),
                    color: leadingTint,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                // The whole point: the page's field raises the IME on
                // mount with no cross-route focus handoff. autofocus
                // requests the keyboard fresh (no manual TextInput.show).
                autofocus: true,
                onSubmitted: onSubmit,
                autocorrect: false,
                textInputAction: isCapture
                    ? TextInputAction.done
                    : TextInputAction.search,
                textCapitalization: isCapture
                    ? TextCapitalization.sentences
                    : TextCapitalization.none,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: hint,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                style: theme.textTheme.bodyLarge,
              ),
            ),
            if (hasText && !voiceActive)
              IconButton(
                tooltip: 'Clear',
                icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                onPressed: onClear,
              ),
            // Voice mic — toggles a live Deepgram dictation session. While
            // listening, the icon flips to a filled "stop" + tinted error
            // colour so the user knows the mic is open. Tap again to commit.
            IconButton(
              tooltip: voiceActive ? 'Stop dictation' : 'Dictate by voice',
              icon: Icon(
                voiceActive ? Icons.stop_circle : Icons.mic,
                color: voiceActive ? scheme.error : null,
              ),
              onPressed: onMicTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section builders — moved here verbatim from app_shell.dart's
// `_OmniboxResultsPanel`. Same algorithm: idle (pinned + recent +
// for-you-now + by-category) and matched (sorted by score, grouped
// by category with group-id boost). Lives here so the search screen
// is self-contained.
// ---------------------------------------------------------------------------

List<_Node> _buildIdleSections({
  required List<OmniboxEntry> catalog,
  required Map<String, OmniboxEntry> byId,
  required List<String> recentIds,
  required List<String> pinnedIds,
  required VerticalLabels labels,
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
    nodes.add(_SectionHeader(cat.pluralLabel(labels)));
    nodes.addAll(list.take(5).map(_Entry.new));
  }
  return nodes;
}

List<_Node> _buildSearchSections({
  required List<OmniboxEntry> catalog,
  required String query,
  required VerticalLabels labels,
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
    nodes.add(_SectionHeader(cat.pluralLabel(labels)));
    for (final p in list.take(8)) {
      nodes.add(_Entry(p.$1));
    }
  }
  return nodes;
}

// ---------------------------------------------------------------------------
// Visual building blocks — moved here from the old `_OmniboxResultsPanel`.
// ---------------------------------------------------------------------------

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

class _CaptureHeroCard extends StatelessWidget {
  const _CaptureHeroCard({
    required this.text,
    required this.onSave,
    this.muted = false,
  });

  final String text;
  final Future<void> Function() onSave;

  /// When a compose draft is on offer above, the note is the fallback — render
  /// it quieter (neutral surface, outlined button, no "press return" hint,
  /// since Return now drafts the block).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trimmed = text.trim();
    final bg = muted ? scheme.surfaceContainerHigh : scheme.primaryContainer;
    final fg = muted ? scheme.onSurface : scheme.onPrimaryContainer;
    final fgSoft = muted ? scheme.onSurfaceVariant : fg;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, muted ? 8 : 12, 12, 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(onSave()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      muted ? Icons.sticky_note_2_outlined : Icons.bolt_outlined,
                      size: muted ? 16 : 18,
                      color: fgSoft,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      muted ? 'OR SAVE AS A NOTE' : 'SAVE AS A CAPTURE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fgSoft,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: muted ? 4 : 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trimmed.isEmpty ? 'Start typing a thought…' : trimmed,
                        maxLines: muted ? 2 : 5,
                        overflow: TextOverflow.ellipsis,
                        style: (muted
                                ? theme.textTheme.bodyMedium
                                : theme.textTheme.bodyLarge)
                            ?.copyWith(color: fg, height: 1.3),
                      ),
                    ),
                    if (muted) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => unawaited(onSave()),
                        child: const Text('Save note'),
                      ),
                    ],
                  ],
                ),
                if (!muted) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Press return — or tap Save',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => unawaited(onSave()),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "omnibox composes" draft card — shown above the note when a captured
/// phrase parsed as a schedule intent. Tapping drafts the block in the editor
/// (nothing saved until the user confirms). See [parseComposeIntent].
class _ComposeDraftCard extends StatelessWidget {
  const _ComposeDraftCard({
    required this.intent,
    required this.groups,
    required this.selectedGroup,
    required this.onPickGroup,
    required this.onDraft,
  });

  final ComposeIntent intent;
  final List<Group> groups;
  final Group selectedGroup;
  final ValueChanged<String> onPickGroup;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = intent.title == intent.kindLabel
        ? intent.kindLabel
        : '${intent.kindLabel} — ${intent.title}';
    final dayLabel = DateFormat('EEE, MMM d').format(intent.start);
    final timeLabel = DateFormat.jm().format(intent.start);
    // One cohort → a static chip. Multiple → a tappable picker so the draft
    // never silently binds to whichever cohort sorts first.
    final groupChip = groups.length <= 1
        ? _DraftChip(icon: Icons.groups_outlined, label: selectedGroup.name)
        : PopupMenuButton<String>(
            onSelected: onPickGroup,
            tooltip: 'Choose the cohort',
            itemBuilder: (_) => [
              for (final g in groups)
                PopupMenuItem<String>(value: g.id, child: Text(g.name)),
            ],
            child: _DraftChip(
              icon: Icons.groups_outlined,
              label: selectedGroup.name,
              trailingIcon: Icons.arrow_drop_down,
            ),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onDraft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 16,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DRAFT A BLOCK',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _DraftChip(emoji: intent.emoji, label: intent.kindLabel),
                    _DraftChip(icon: Icons.event_outlined, label: dayLabel),
                    _DraftChip(
                      icon: Icons.schedule_outlined,
                      label: timeLabel,
                    ),
                    groupChip,
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Opens the editor — nothing's saved yet.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.82,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onDraft,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: const Text('Draft it'),
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

/// A small pill inside the draft card — an emoji OR a Material icon + label,
/// with an optional trailing icon (e.g. a dropdown caret when it's a picker).
class _DraftChip extends StatelessWidget {
  const _DraftChip({
    required this.label,
    this.icon,
    this.emoji,
    this.trailingIcon,
  });

  final String label;
  final IconData? icon;
  final String? emoji;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(9, 5, trailingIcon == null ? 11 : 6, 5),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 14))
          else if (icon != null)
            Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
          if (trailingIcon != null)
            Icon(trailingIcon, size: 16, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

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

class _SlashCommandList extends StatelessWidget {
  const _SlashCommandList({
    required this.matches,
    required this.parsedArgs,
    required this.onPick,
  });

  final List<SlashCommand> matches;
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
    return ListView.builder(
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
            parsedArgs == null ? c.hint : '${c.hint} — args: $parsedArgs',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          onTap: () => onPick(c),
        );
      },
    );
  }
}

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
