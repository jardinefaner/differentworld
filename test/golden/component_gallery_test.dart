import 'dart:convert';

// The organism plates pull in a seeded viewer + local DB + (for AppShell)
// a real GoRouter, so the full-screen layout/chrome organisms render for
// real rather than as bare plates — hence the core/ + features/ + drift +
// go_router imports below.
import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/omnibox/bottom_omnibox_bar.dart';
import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/omnibox/omnibox_mode.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/shared/widgets/accent_card_tile.dart';
import 'package:differentworld/shared/widgets/app_shell.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/cap_switch.dart';
import 'package:differentworld/shared/widgets/capability_locked_tile.dart';
import 'package:differentworld/shared/widgets/collapsible_section.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/desktop_nav_rail.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dw_wordmark.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_banner.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/floating_actions.dart';
import 'package:differentworld/shared/widgets/floating_back.dart';
import 'package:differentworld/shared/widgets/floating_hamburger.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/glass_pill.dart';
import 'package:differentworld/shared/widgets/horizon_mark.dart';
import 'package:differentworld/shared/widgets/inline_editable_text.dart';
import 'package:differentworld/shared/widgets/live_block_strip.dart';
import 'package:differentworld/shared/widgets/main_drawer.dart';
import 'package:differentworld/shared/widgets/master_detail_scaffold.dart';
import 'package:differentworld/shared/widgets/nav_destinations.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/overflow_actions.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/progress_dots.dart';
import 'package:differentworld/shared/widgets/responsive_grid.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:differentworld/shared/widgets/scale_bar.dart';
import 'package:differentworld/shared/widgets/search_bar_pill.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:differentworld/shared/widgets/skeleton.dart';
import 'package:differentworld/shared/widgets/status_dot.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '_helpers.dart';

/// THE COMPONENT BIBLE renderer (see gallery/README.md). Every catalogued
/// component is rendered — its variants, light + dark — to
/// `gallery/<tier>/<name>__<theme>.png`, so the whole vocabulary is browsable
/// and tweakable in ONE folder.
///
/// Regenerate (local, on-demand — goldens are environment-sensitive + OFF by
/// default; this is for VIEWING, not cross-machine CI):
/// ```sh
/// RUN_GOLDENS=1 flutter test --update-goldens test/golden/component_gallery_test.dart
/// open gallery/        # eyeball the PNGs
/// ```
///
/// Add a component: register a [_plate] below + add its row to
/// gallery/README.md. The `component-curator` agent reconciles the two and
/// flags anything in lib/shared/widgets/ that isn't catalogued yet.
///
/// Animated / blur components (StatusDot glow, Skeleton shimmer, GlassPill
/// BackdropFilter) are deferred — they need a fixed-pump variant so
/// `pumpAndSettle` can't hang on a forever-animation. Tracked in the README.
/// Load EVERY bundled font from FontManifest.json — the app faces (Jost,
/// Fraunces, Space Grotesk, Anton) AND `MaterialIcons`, so glyphs and icons
/// both render for real instead of as tofu boxes (the default test env ships
/// no font data).
Future<void> _loadFonts() async {
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load((font as Map)['asset'] as String));
    }
    await loader.load();
  }
}

void _noop(bool _) {}
Future<void> _noopStr(String _) async {}

/// Seeded local DB + viewer for the organism harness, built once in
/// setUpAll. The nav-bearing organisms (drawer, rail, shell) read the
/// viewer for identity + capability-gated destinations, and the DB for
/// the nav badge counts. Seeded as a director so the full nav
/// (Observations, Program, Vehicles) renders.
late final AppDatabase _organismDb;
late final Viewer _seededViewer;

/// A block "live right now" so the LiveBlockStrip + AppShell plates show
/// the strip instead of its zero-height collapsed (nothing-live) state.
LiveBlock _demoLiveBlock() => LiveBlock(
      blockId: 'blk-demo',
      groupId: 'g1',
      title: 'Outdoor free play',
      kind: 'on_site',
      isOutdoor: true,
      startAt: DateTime.now().subtract(const Duration(minutes: 12)),
      endAt: DateTime.now().add(const Duration(minutes: 23)),
    );

/// Empty-stream overrides so the nav-bearing organisms render against fixed
/// data instead of spinning up real Drift `.watch()` streams. A live watch
/// stream leaves a pending Timer when the tree is disposed (tripping
/// flutter_test's `!timersPending` invariant) and stalls `db.close()` — the
/// same reason the captures / tasks goldens override their data providers
/// rather than seeding a live DB. `_emptyMoments` is keyed to the demo
/// block id so the LiveBlockStrip + AppShell plates resolve to zero moments.
// Riverpod's Override type isn't publicly exported (see _helpers.dart), so
// these can't be annotated — same ignore the provider files use.
// ignore: specify_nonobvious_property_types
final _emptyCaptures = capturesProvider(CaptureFilter.open)
    .overrideWith((_) => Stream<List<Capture>>.value(const <Capture>[]));
// Untyped — Override isn't exported (as above).
// ignore: specify_nonobvious_property_types
final _emptyTasks = tasksProvider(TaskFilter.open)
    .overrideWith((_) => Stream<List<Task>>.value(const <Task>[]));
// Untyped — Override isn't exported (as above).
// ignore: specify_nonobvious_property_types
final _emptyMoments = momentsForBlockProvider('blk-demo')
    .overrideWith((_) => Stream<List<Entry>>.value(const <Entry>[]));

void main() {
  setUpAll(() async {
    await ensureGoldenBootstrap();
    // Real type, not the box-glyph fallback — these PNGs are a design
    // reference, so the fonts have to render.
    await _loadFonts();
    // Seed a director viewer over a real in-memory DB so the nav-bearing
    // organisms (drawer, rail, shell) render full identity + nav. Mirrors
    // the action-layer harness in test/unit (createAll materializes the
    // schema PowerSync would otherwise own).
    _organismDb = AppDatabase.forTesting(NativeDatabase.memory());
    await _organismDb.createMigrator().createAll();
    const now = '2026-06-17T08:00:00Z';
    await _organismDb.into(_organismDb.spaces).insert(
          SpacesCompanion.insert(
            id: 'sp1',
            name: 'Sunny Days Program',
            settings: '{}',
            capabilities: '{}',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _organismDb.into(_organismDb.members).insert(
          MembersCompanion.insert(
            id: 'm1',
            displayName: 'Maya Okonkwo',
            role: 'director',
            capabilities: '{}',
            createdAt: now,
            updatedAt: now,
            spaceId: const Value('sp1'),
          ),
        );
    final m = await (_organismDb.select(_organismDb.members)
          ..where((t) => t.id.equals('m1')))
        .getSingle();
    final s = await (_organismDb.select(_organismDb.spaces)
          ..where((t) => t.id.equals('sp1')))
        .getSingle();
    _seededViewer = Viewer(member: m, space: s);
  });

  tearDownAll(() async {
    // With the watch streams overridden there are no lingering Drift
    // subscriptions, so close() returns at once; the timeout is
    // belt-and-suspenders against any residual hang.
    await _organismDb
        .close()
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  });

  // ── ATOMS ──────────────────────────────────────────────────────────────
  _plate(
    'atoms/action_buttons',
    height: 220,
    (_) => Wrap(
      spacing: Insets.md,
      runSpacing: Insets.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PrimaryActionButton(tooltip: 'Add', icon: Icons.add, onPressed: () {}),
        SecondaryActionButton(
          tooltip: 'Settings',
          icon: Icons.tune,
          onPressed: () {},
        ),
        FilledButton(onPressed: () {}, child: const Text('Filled')),
        FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
        OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
        TextButton(onPressed: () {}, child: const Text('Text')),
        DestructiveButton(label: 'Delete', onPressed: () {}),
      ],
    ),
  );

  _plate(
    'atoms/person_avatar',
    height: 180,
    (_) => const Wrap(
      spacing: Insets.lg,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PersonAvatar(name: 'Maya Okonkwo'),
        PersonAvatar(name: 'Devon Lee', radius: 26),
        PersonAvatar(name: 'Sam', radius: 34),
      ],
    ),
  );

  _plate(
    'atoms/status_dot',
    height: 170,
    (_) => const Wrap(
      spacing: Insets.xl,
      runSpacing: Insets.lg,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Labeled('calm', StatusDot(kind: StatusDotKind.calm, size: 18)),
        _Labeled('progress', StatusDot(kind: StatusDotKind.progress, size: 18)),
        _Labeled(
          'attention',
          StatusDot(kind: StatusDotKind.needsAttention, size: 18),
        ),
        _Labeled('neutral', StatusDot(kind: StatusDotKind.neutral, size: 18)),
      ],
    ),
  );

  _plate(
    'atoms/progress_dots',
    height: 160,
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Labeled('step 1 of 4', ProgressDots(count: 4, current: 0)),
        SizedBox(height: Insets.lg),
        _Labeled('step 3 of 4', ProgressDots(count: 4, current: 2)),
      ],
    ),
  );

  _plate(
    'atoms/dw_wordmark',
    height: 240,
    (_) => const Center(child: DwWordmark(tagline: 'imagination, first')),
  );

  _plate(
    'atoms/scale_bar',
    height: 230,
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleBar(scale: Scale(value: 3, max: 5), label: 'Mood', trailing: '3 / 5'),
        SizedBox(height: Insets.xl),
        ScaleBar(
          scale: Scale(value: 23, max: 50, previous: 10),
          label: 'Journey',
          trailing: 'Day 23',
        ),
      ],
    ),
  );

  // Glass = BackdropFilter; render OVER a busy backdrop so the frost is visible.
  _plate(
    'atoms/glass_pill',
    height: 220,
    (_) => Stack(
      fit: StackFit.expand,
      children: [
        _glassBackdrop(),
        Center(
          child: GlassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  _plate(
    'atoms/horizon_mark',
    height: 220,
    (_) => const Center(child: HorizonMark(size: 132)),
  );

  _plate(
    'atoms/search_bar_pill',
    height: 140,
    (_) => SearchBarPill(
      controller: TextEditingController(text: 'Maya'),
      onChanged: (_) {},
      onClose: () {},
    ),
  );

  _plate(
    'atoms/nav_count_badge',
    height: 130,
    (_) => const Wrap(
      spacing: Insets.lg,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Labeled('3', NavCountBadge(count: 3)),
        _Labeled('12', NavCountBadge(count: 12)),
        _Labeled('150', NavCountBadge(count: 150)),
      ],
    ),
  );

  _plate(
    'atoms/floating_chrome',
    height: 200,
    (_) => Stack(
      fit: StackFit.expand,
      children: [
        _glassBackdrop(),
        const Align(
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingHamburger(),
              SizedBox(width: 8),
              FloatingBack(),
            ],
          ),
        ),
      ],
    ),
  );

  _plate(
    'atoms/inline_editable_text',
    height: 140,
    (_) => const InlineEditableText(value: 'Sunny Room', onCommit: _noopStr),
  );

  _platePumped(
    'atoms/skeletons',
    height: 280,
    (_) => const SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLine(widthFactor: 0.5, height: 24),
          SizedBox(height: Insets.md),
          SkeletonBox(width: 120, height: 80),
          SizedBox(height: Insets.md),
          SkeletonListTile(hasTrailing: true),
        ],
      ),
    ),
  );

  // ── MOLECULES ────────────────────────────────────────────────────────────
  _plate(
    'molecules/feature_card',
    height: 460,
    (_) => Column(
      children: [
        FeatureCard(
          leading: const Icon(Icons.person_outline),
          title: 'Maya Okonkwo',
          subtitle: 'Checked in · 8:42 AM',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        const SizedBox(height: Insets.sm),
        FeatureCard(
          tone: FeatureCardTone.selected,
          leading: const Icon(Icons.play_arrow),
          title: 'Free play',
          subtitle: 'Blocks corner · right now',
          onTap: () {},
        ),
        const SizedBox(height: Insets.sm),
        FeatureCard(
          tone: FeatureCardTone.danger,
          leading: const Icon(Icons.warning_amber_rounded),
          title: 'Allergy note needs review',
          subtitle: 'Updated by a guardian',
          onTap: () {},
        ),
        const SizedBox(height: Insets.sm),
        FeatureCard(
          tone: FeatureCardTone.success,
          leading: const Icon(Icons.check_circle_outline),
          title: 'All checked out',
          subtitle: 'Every child signed out',
          onTap: () {},
        ),
      ],
    ),
  );

  // SectionCard is an aggregator that wraps ROWS (its canonical use); the rows
  // self-align via their own gutter, so the section icon/title line up with the
  // row leadings/titles — one left edge. (A bare child must pad itself; callers
  // always do.)
  _plate(
    'molecules/section_card',
    height: 280,
    (_) => const SectionCard(
      icon: Icons.forum_outlined,
      title: '2 unread messages',
      tone: SectionCardTone.featured,
      child: Column(
        children: [
          FeatureCard(
            leading: Icon(Icons.person_outline),
            title: 'Devon’s mom',
            subtitle: '“Will pick up at 5 today.”',
          ),
          FeatureCard(
            leading: Icon(Icons.person_outline),
            title: 'Ana’s dad',
            subtitle: '“Running 10 minutes late.”',
          ),
        ],
      ),
    ),
  );

  _plate(
    'molecules/content_header',
    height: 150,
    (_) => const ContentHeader(title: 'Today', subtitle: 'Sunny Room · 12 children'),
  );

  _plate(
    'molecules/empty_state',
    height: 380,
    (_) => EmptyState(
      icon: Icons.photo_camera_outlined,
      title: 'No photos yet',
      message: 'Snap a moment to share with families.',
      action: FilledButton(onPressed: () {}, child: const Text('Add a photo')),
    ),
  );

  _plate(
    'molecules/error_state',
    height: 380,
    (_) => ErrorState(
      title: 'Couldn’t load',
      detail: 'Check your connection and try again.',
      onRetry: () {},
    ),
  );

  _plate(
    'molecules/error_banner',
    height: 150,
    (_) => ErrorBanner(
      message: 'Couldn’t sync — we’ll retry automatically.',
      onRetry: () {},
      onDismiss: () {},
    ),
  );

  _plate(
    'molecules/cap_switch',
    height: 180,
    (_) => const Column(
      children: [
        CapSwitch(label: 'Attendance', value: true, onChanged: _noop),
        CapSwitch(
          label: 'Field trips',
          subtitle: 'Off for this room',
          value: false,
          enabled: false,
          onChanged: _noop,
        ),
      ],
    ),
  );

  _plate(
    'molecules/accent_card_tile',
    height: 320,
    (_) => Wrap(
      spacing: Insets.md,
      runSpacing: Insets.md,
      children: [
        SizedBox(
          width: 190,
          height: 140,
          child: AccentCardTile(
            color: ActivityPalette.teal,
            title: 'Now & Next',
            tagline: "What's on now",
            icon: Icons.calendar_view_day_outlined,
            onTap: () {},
          ),
        ),
        SizedBox(
          width: 190,
          height: 140,
          child: AccentCardTile(
            color: ActivityPalette.pink,
            title: "What's Missing",
            tagline: 'Memory game',
            icon: Icons.visibility_off_outlined,
            onTap: () {},
          ),
        ),
        SizedBox(
          width: 190,
          height: 140,
          child: AccentCardTile(
            color: ActivityPalette.amber,
            title: 'Spotlight',
            tagline: 'Fair turns',
            icon: Icons.star_outline,
            onTap: () {},
          ),
        ),
      ],
    ),
  );

  _plate(
    'molecules/capability_locked_tile',
    height: 180,
    (_) => const CapabilityLockedTile(
      tooltip: 'Turn on Field Trips in Settings',
      child: FeatureCard(
        leading: Icon(Icons.directions_bus_outlined),
        title: 'Field trips',
        subtitle: 'Locked for this room',
      ),
    ),
  );

  _plate(
    'molecules/collapsible_section',
    height: 300,
    (_) => const Column(
      children: [
        CollapsibleSection(
          icon: Icons.family_restroom_outlined,
          title: 'Guardians',
          collapsedSummary: '3 guardians',
          child: Column(
            children: [
              FeatureCard(
                leading: Icon(Icons.person_outline),
                title: 'Ana Okonkwo',
                subtitle: 'Mother · primary',
              ),
              FeatureCard(
                leading: Icon(Icons.person_outline),
                title: 'Devon Lee',
                subtitle: 'Father',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  _plate(
    'molecules/no_access',
    (_) => const NoAccess(),
  );

  // Loading states animate forever (shimmer / spinner) → fixed-pump, not settle.
  _platePumped(
    'molecules/loading_slot',
    height: 440,
    (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('list', style: Theme.of(ctx).textTheme.labelSmall),
        const SizedBox(height: 6),
        const SizedBox(height: 160, child: LoadingSlot()),
        const SizedBox(height: Insets.lg),
        Text('cards', style: Theme.of(ctx).textTheme.labelSmall),
        const SizedBox(height: 6),
        const SizedBox(
          height: 160,
          child: LoadingSlot(variant: LoadingVariant.cards),
        ),
      ],
    ),
  );

  _plate(
    'molecules/glass_panel',
    height: 320,
    (ctx) => Stack(
      fit: StackFit.expand,
      children: [
        _glassBackdrop(),
        Align(
          alignment: Alignment.bottomCenter,
          child: GlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Glass sheet', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'A frosted surface over the page — the floating-glass chrome.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // GlassDragHandle renders ONLY on a bottom-sheet surface (it self-
  // suppresses in dialogs / side panels). Shown at the top of a glass sheet
  // — its real home — over a busy backdrop so the frost reads.
  _plate(
    'molecules/glass_drag_handle',
    height: 320,
    (ctx) => Stack(
      fit: StackFit.expand,
      children: [
        _glassBackdrop(),
        Align(
          alignment: Alignment.bottomCenter,
          child: GlassSheetScope(
            surface: GlassSheetSurface.bottomSheet,
            child: GlassPanel(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GlassDragHandle(),
                    Text('Edit room', style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Drag the handle to dismiss — the pill shows only on a '
                      'bottom sheet, never a dialog or side panel.',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  _plate(
    'molecules/form_body',
    height: 340,
    (_) => const FormBody(
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'First name',
            hintText: 'e.g. Maya',
          ),
        ),
        SizedBox(height: Insets.md),
        TextField(
          decoration: InputDecoration(
            labelText: 'Room',
            hintText: 'e.g. Sunny Room',
          ),
        ),
      ],
    ),
  );

  _plate(
    'molecules/overflow_actions',
    height: 160,
    (_) => OverflowActions([
      EdgeAction(
        icon: Icons.add,
        label: 'Add',
        onPressed: () {},
        isPrimary: true,
      ),
      EdgeAction(icon: Icons.edit_outlined, label: 'Edit', onPressed: () {}),
      EdgeAction(icon: Icons.ios_share, label: 'Share', onPressed: () {}),
      EdgeAction(
        icon: Icons.delete_outline,
        label: 'Delete',
        onPressed: () {},
        isDestructive: true,
      ),
    ]),
  );

  // ── ORGANISMS (standalone — no provider/routing harness) ─────────────────
  _plate(
    'organisms/floating_actions',
    height: 200,
    (_) => Stack(
      fit: StackFit.expand,
      children: [
        _glassBackdrop(),
        Align(
          alignment: Alignment.topRight,
          child: FloatingActions(
            children: [
              PrimaryActionButton(
                tooltip: 'Add',
                icon: Icons.add,
                onPressed: () {},
              ),
              SecondaryActionButton(
                tooltip: 'Search',
                icon: Icons.search,
                onPressed: () {},
              ),
              SecondaryActionButton(
                tooltip: 'Sync',
                icon: Icons.cloud_done_outlined,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    ),
  );

  _plate(
    'organisms/responsive_page',
    height: 420,
    (_) => const ResponsivePage(
      children: [
        ContentHeader(title: 'Today', subtitle: 'Sunny Room · 12 children'),
        FeatureCard(
          leading: Icon(Icons.person_outline),
          title: 'Maya Okonkwo',
          subtitle: 'Checked in · 8:42 AM',
        ),
        FeatureCard(
          leading: Icon(Icons.person_outline),
          title: 'Devon Lee',
          subtitle: 'Checked in · 8:50 AM',
        ),
      ],
    ),
  );

  _plate(
    'organisms/responsive_grid',
    height: 320,
    width: 1100,
    (_) => ResponsiveGrid(
      itemCount: 4,
      itemBuilder: (_, i) => AccentCardTile(
        color: const [
          ActivityPalette.teal,
          ActivityPalette.pink,
          ActivityPalette.amber,
          ActivityPalette.indigo,
        ][i],
        title: const ['Now & Next', "What's Missing", 'Spotlight', 'Memory'][i],
        tagline: 'Tap to present',
        icon: Icons.play_circle_outline,
        onTap: () {},
      ),
    ),
  );

  _plate(
    'organisms/master_detail_scaffold',
    height: 420,
    width: 1320,
    (_) => MasterDetailScaffold(
      list: ListView(
        children: const [
          FeatureCard(
            leading: Icon(Icons.person_outline),
            title: 'Maya Okonkwo',
            subtitle: 'Sunny Room',
          ),
          FeatureCard(
            leading: Icon(Icons.person_outline),
            title: 'Devon Lee',
            subtitle: 'Sunny Room',
          ),
          FeatureCard(
            tone: FeatureCardTone.selected,
            leading: Icon(Icons.person_outline),
            title: 'Ana Ruiz',
            subtitle: 'Sunny Room',
          ),
        ],
      ),
      detail: const Center(
        child: Text('Ana Ruiz', style: TextStyle(fontSize: 24)),
      ),
    ),
  );

  // ── ORGANISMS (seeded harness — ProviderScope + router) ──────────────────
  // The full-screen layout/chrome organisms. Unlike the standalone four
  // above, these need a seeded viewer, the local DB (nav badge counts), and
  // — for AppShell — a real GoRouter ancestor (GoRouterState.of). Rendered
  // full-surface (no padded Align) because they own the whole viewport.

  // SliverResponsiveGrid: the sliver flavor, composed inside a
  // CustomScrollView with a header sliver above it.
  _scenePlate(
    'organisms/sliver_responsive_grid',
    width: 1000,
    height: 560,
    tree: (theme) => ProviderScope(
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 8),
                  child: ContentHeader(
                    title: 'Activities',
                    subtitle: 'A wall of tiles — reflows by width',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverResponsiveGrid(
                  itemCount: 6,
                  itemBuilder: (_, i) => AccentCardTile(
                    color: const [
                      ActivityPalette.teal,
                      ActivityPalette.pink,
                      ActivityPalette.amber,
                      ActivityPalette.indigo,
                      ActivityPalette.teal,
                      ActivityPalette.pink,
                    ][i],
                    title: const [
                      'Now & Next',
                      "What's Missing",
                      'Spotlight',
                      'Memory',
                      'Sort It',
                      'Reveal',
                    ][i],
                    tagline: 'Tap to present',
                    icon: Icons.play_circle_outline,
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // LiveBlockStrip: pass a live block directly; over a busy backdrop so the
  // glass frost reads. Pumped (the breathing dot animates forever).
  _scenePlate(
    'organisms/live_block_strip',
    height: 200,
    pumped: true,
    tree: (theme) => ProviderScope(
      // The strip's moment-count watches the DB; seed it so the read
      // resolves to 0 instead of hitting the unmocked PowerSync DB.
      overrides: [
        appDatabaseProvider.overrideWith((ref) => _organismDb),
        _emptyMoments,
      ],
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              _glassBackdrop(),
              Align(
                alignment: Alignment.bottomCenter,
                child: LiveBlockStrip(liveBlock: _demoLiveBlock()),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // DesktopNavRail: the persistent 240dp left column at desktop widths.
  _scenePlate(
    'organisms/desktop_nav_rail',
    width: 300,
    height: 780,
    tree: (theme) => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => _organismDb),
        viewerProvider.overrideWithValue(_seededViewer),
        _emptyCaptures,
        _emptyTasks,
      ],
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              _glassBackdrop(),
              const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 240, child: DesktopNavRail()),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // MainDrawer: the mobile / tablet hamburger drawer — same nav source as
  // the rail, presented as an overlay glass sheet.
  _scenePlate(
    'organisms/main_drawer',
    width: 360,
    height: 780,
    tree: (theme) => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => _organismDb),
        viewerProvider.overrideWithValue(_seededViewer),
        _emptyCaptures,
        _emptyTasks,
      ],
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              _glassBackdrop(),
              const Align(
                alignment: Alignment.centerLeft,
                child: MainDrawer(),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // EdgeScaffold: one screen's scaffold + the floating chrome it publishes.
  // Standalone it owns the Scaffold + reserves the chrome band; the pills
  // here are the real chrome AppShell paints from its published props.
  _scenePlate(
    'organisms/edge_scaffold',
    width: 420,
    tree: (theme) => ProviderScope(
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: const _EdgeScaffoldDemo(),
      ),
    ),
  );

  // AppShell: the persistent frame — hamburger + action pills (from the
  // child EdgeScaffold's published chrome), the live-block strip, and the
  // bottom omnibox composer bar. Wrapped in a real GoRouter (the shell
  // reads GoRouterState). Pumped (live strip animates).
  _scenePlate(
    'organisms/app_shell',
    width: 420,
    height: 820,
    pumped: true,
    tree: (theme) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(path: '/', builder: (_, _) => const _ShellHomeBody()),
            ],
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => _organismDb),
          viewerProvider.overrideWithValue(_seededViewer),
          // Inject a live block so the strip shows; also avoids the 30s
          // periodic tick provider (a pending timer at teardown).
          liveBlockProvider.overrideWith((ref) => _demoLiveBlock()),
          // Override the Drift-backed watches AppShell pulls so no live
          // watch stream survives to teardown: the omnibox catalog, the
          // live strip's moments, and the nav counts (if the drawer mounts).
          omniboxCatalogProvider.overrideWithValue(const <OmniboxEntry>[]),
          _emptyMoments,
          _emptyCaptures,
          _emptyTasks,
        ],
        child: MaterialApp.router(
          theme: theme,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      );
    },
  );

  // ── SURFACES (the composed presentations a user actually interacts with) ──
  // The three responsive forms `showGlassSheet` produces (bottom sheet →
  // dialog → side panel), the destructive-confirm dialog, a snackbar, and the
  // omnibox composer in its three modes. Built from the real widgets / the
  // same GlassPanel shapes the app uses, over a dimmed scrim so they read as
  // modal over a page. The shared sheet body carries a GlassDragHandle at top
  // — it shows in the bottom sheet and self-suppresses in the dialog / side
  // panel, exactly as in the app.

  _scenePlate(
    'surfaces/bottom_sheet',
    height: 720,
    tree: (theme) => _surfaceApp(theme, const _BottomSheetSurface()),
  );
  _scenePlate(
    'surfaces/dialog',
    width: 700,
    height: 520,
    tree: (theme) => _surfaceApp(theme, const _DialogSurface()),
  );
  _scenePlate(
    'surfaces/side_panel',
    width: 1100,
    height: 680,
    tree: (theme) => _surfaceApp(theme, const _SidePanelSurface()),
  );
  _scenePlate(
    'surfaces/confirm_destructive',
    height: 520,
    tree: (theme) => _surfaceApp(theme, const _ConfirmDestructiveSurface()),
  );
  _scenePlate(
    'surfaces/snackbar',
    height: 360,
    tree: (theme) => _surfaceApp(theme, const _SnackbarSurface()),
  );
  _scenePlate(
    'surfaces/omnibox_bar',
    height: 380,
    tree: (theme) => _surfaceApp(theme, const _OmniboxBarSurface()),
  );
  _scenePlate(
    'surfaces/omnibox_overlay',
    height: 720,
    tree: (theme) => _surfaceApp(theme, const _OmniboxOverlaySurface()),
  );
}

/// Wrap a full-bleed surface widget in the standard golden tree.
Widget _surfaceApp(ThemeData theme, Widget body) => ProviderScope(
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: body),
      ),
    );

/// Themed modal scrim behind a surface.
Color _scrim(BuildContext context, {double alpha = 0.45}) =>
    Theme.of(context).colorScheme.scrim.withValues(alpha: alpha);

/// A busy backdrop (colour stripes) so the frosted-glass blur has something to
/// frost — glass over an empty surface only shows its tint.
Widget _glassBackdrop() => Container(
      color: const Color(0xFFEFEAE2),
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in const [320.0, 240.0, 300.0, 180.0, 260.0])
            Container(
              height: 13,
              width: w,
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFCFC8BB),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
        ],
      ),
    );

/// Theme-aware busy backdrop — same shape as [_glassBackdrop] but its
/// colours follow the scheme, so a surface plate's own themed text (e.g.
/// the omnibox mode labels) stays readable on it in BOTH light and dark.
Widget _themedBackdrop(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    color: scheme.surface,
    alignment: Alignment.topLeft,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in const [320.0, 240.0, 300.0, 180.0, 260.0])
          Container(
            height: 13,
            width: w,
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ],
    ),
  );
}

/// A home screen rendered inside the AppShell harness — a real
/// EdgeScaffold so the shell paints its published chrome (hamburger +
/// action pill), with a representative Today body.
class _ShellHomeBody extends StatelessWidget {
  const _ShellHomeBody();

  @override
  Widget build(BuildContext context) => EdgeScaffold(
        showBack: false,
        actions: [
          SecondaryActionButton(
            tooltip: 'Sync',
            icon: Icons.cloud_done_outlined,
            onPressed: () {},
          ),
        ],
        body: ListView(
          children: const [
            ContentHeader(
              title: 'Today',
              subtitle: 'Sunny Days Program · 18 children',
            ),
            FeatureCard(
              leading: Icon(Icons.wb_sunny_outlined),
              title: 'Morning circle',
              subtitle: 'Now · Sunny Room',
            ),
            FeatureCard(
              leading: Icon(Icons.inbox_outlined),
              title: '3 captures to triage',
              subtitle: 'From this morning',
            ),
            FeatureCard(
              leading: Icon(Icons.check_circle_outline),
              title: '2 open tasks',
              subtitle: 'Permission slips due Friday',
            ),
          ],
        ),
      );
}

/// EdgeScaffold standalone — its own Scaffold + body, with the floating
/// chrome pills (hamburger + back + actions) overlaid the way AppShell
/// paints them from the published `RouteChrome`. Shows what one screen
/// looks like; no omnibox bar (that's AppShell's).
class _EdgeScaffoldDemo extends StatelessWidget {
  const _EdgeScaffoldDemo();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        EdgeScaffold(
          actions: [
            SecondaryActionButton(
              tooltip: 'Edit',
              icon: Icons.edit_outlined,
              onPressed: () {},
            ),
            SecondaryActionButton(
              tooltip: 'Share',
              icon: Icons.ios_share,
              onPressed: () {},
            ),
          ],
          body: ListView(
            children: const [
              ContentHeader(
                title: 'Owen Mensah',
                subtitle: 'Sunny Room · age 5',
              ),
              FeatureCard(
                leading: Icon(Icons.event_available_outlined),
                title: 'Checked in',
                subtitle: '8:42 AM · by Maya',
              ),
              FeatureCard(
                leading: Icon(Icons.restaurant_outlined),
                title: 'Lunch',
                subtitle: 'Ate most · 12:05 PM',
              ),
              FeatureCard(
                leading: Icon(Icons.visibility_outlined),
                title: 'Observation',
                subtitle: 'Built a tall block tower with Ana',
              ),
            ],
          ),
        ),
        Positioned(
          top: top + 8,
          left: 8,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingHamburger(),
              SizedBox(width: 8),
              FloatingBack(),
            ],
          ),
        ),
        Positioned(
          top: top + 8,
          right: 8,
          child: FloatingActions(
            children: [
              SecondaryActionButton(
                tooltip: 'Edit',
                icon: Icons.edit_outlined,
                onPressed: () {},
              ),
              SecondaryActionButton(
                tooltip: 'Share',
                icon: Icons.ios_share,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The shared body for the three sheet presentations — a representative
/// edit form. The `GlassDragHandle` at the top shows on the bottom-sheet
/// surface and self-suppresses in the dialog / side panel, so one body
/// renders correctly in all three.
class _SheetForm extends StatelessWidget {
  const _SheetForm();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GlassDragHandle(),
          Text('Edit room', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Sunny Room · Building A',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Room name',
              hintText: 'e.g. Sunny Room',
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Capacity',
              hintText: 'e.g. 18',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              DestructiveButton(label: 'Delete', onPressed: () {}),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: () {}, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}

/// `showGlassSheet` < 840dp — a glass bottom sheet over a dimmed page.
class _BottomSheetSurface extends StatelessWidget {
  const _BottomSheetSurface();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          _glassBackdrop(),
          ColoredBox(color: _scrim(context)),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: const GlassPanel(
                child: GlassSheetScope(
                  surface: GlassSheetSurface.bottomSheet,
                  child: _SheetForm(),
                ),
              ),
            ),
          ),
        ],
      );
}

/// `showGlassSheet` 840–1200dp — a centered glass dialog (the drag handle
/// self-suppresses here).
class _DialogSurface extends StatelessWidget {
  const _DialogSurface();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          _glassBackdrop(),
          ColoredBox(color: _scrim(context)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: const GlassPanel(
                child: GlassSheetScope(
                  surface: GlassSheetSurface.dialog,
                  child: _SheetForm(),
                ),
              ),
            ),
          ),
        ],
      );
}

/// `showGlassSheet` ≥ 1200dp — the right-docked third-column side panel,
/// with the close strip the real `_SidePanelFrame` carries.
class _SidePanelSurface extends StatelessWidget {
  const _SidePanelSurface();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          _glassBackdrop(),
          ColoredBox(color: _scrim(context, alpha: 0.3)),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 420,
              height: double.infinity,
              child: GlassPanel(
                shape: GlassPanelShape.side,
                child: Material(
                  type: MaterialType.transparency,
                  child: SafeArea(
                    left: false,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 44,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        const Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: GlassSheetScope(
                              surface: GlassSheetSurface.sidePanel,
                              child: _SheetForm(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

/// The `confirmDestructive` dialog — error-tinted confirm over a scrim.
class _ConfirmDestructiveSurface extends StatelessWidget {
  const _ConfirmDestructiveSurface();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        _glassBackdrop(),
        ColoredBox(color: _scrim(context)),
        Center(
          child: AlertDialog(
            title: const Text('Delete Sunny Room?'),
            content: const Text(
              'This removes the room and unassigns its 18 children. '
              "This can't be undone.",
            ),
            actions: [
              TextButton(onPressed: () {}, child: const Text('Cancel')),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                ),
                onPressed: () {},
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Snackbars — the M3 inverse-surface toast with an action, success + error.
class _SnackbarSurface extends StatelessWidget {
  const _SnackbarSurface();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          _glassBackdrop(),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SnackbarShape(message: 'Saved as a capture.', action: 'Undo'),
                  SizedBox(height: 10),
                  _SnackbarShape(
                    message: "Couldn't sync — we'll retry automatically.",
                    action: 'Retry',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _SnackbarShape extends StatelessWidget {
  const _SnackbarShape({required this.message, required this.action});

  final String message;
  final String action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Material(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onInverseSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {},
                child: Text(
                  action,
                  style: TextStyle(color: scheme.inversePrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The omnibox composer (`BottomOmniboxBar`) in all three modes — search,
/// capture (primary tint + bolt), slash (tertiary tint + terminal).
class _OmniboxBarSurface extends StatefulWidget {
  const _OmniboxBarSurface();

  @override
  State<_OmniboxBarSurface> createState() => _OmniboxBarSurfaceState();
}

class _OmniboxBarSurfaceState extends State<_OmniboxBarSurface> {
  final _search = TextEditingController();
  final _capture = TextEditingController(text: 'Owen napped well today');
  final _slash = TextEditingController(text: '/attendance sunny room');
  final _f1 = FocusNode();
  final _f2 = FocusNode();
  final _f3 = FocusNode();

  @override
  void dispose() {
    _search.dispose();
    _capture.dispose();
    _slash.dispose();
    _f1.dispose();
    _f2.dispose();
    _f3.dispose();
    super.dispose();
  }

  Widget _bar(
    String label,
    TextEditingController c,
    FocusNode f,
    OmniboxMode mode,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 2),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
          SizedBox(
            height: 76,
            child: BottomOmniboxBar(
              controller: c,
              focusNode: f,
              mode: mode,
              onChanged: (_) {},
              onSubmit: (_) {},
              onClear: () {},
              onMicTap: () {},
              onCollapse: () {},
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          _themedBackdrop(context),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _bar('search', _search, _f1, OmniboxMode.search),
                _bar('capture', _capture, _f2, OmniboxMode.capture),
                _bar('slash', _slash, _f3, OmniboxMode.slash),
              ],
            ),
          ),
        ],
      );
}

/// The omnibox suggestion overlay — the full-bleed frosted
/// `GlassPanelShape.overlay` panel that opens above the composer when the
/// bar gains focus, with recent + suggested destinations.
class _OmniboxOverlaySurface extends StatelessWidget {
  const _OmniboxOverlaySurface();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        _themedBackdrop(context),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 76,
          child: GlassPanel(
            shape: GlassPanelShape.overlay,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
              child: ListView(
                children: [
                  label('Recent'),
                  const FeatureCard(
                    leading: Icon(Icons.history),
                    title: 'Today',
                    subtitle: 'Home',
                  ),
                  const FeatureCard(
                    leading: Icon(Icons.inbox_outlined),
                    title: 'Captures',
                    subtitle: '3 to triage',
                  ),
                  label('Suggestions'),
                  const FeatureCard(
                    leading: Icon(Icons.calendar_month_outlined),
                    title: 'Attendance · Sunny Room',
                    subtitle: 'Take attendance',
                  ),
                  const FeatureCard(
                    leading: Icon(Icons.visibility_outlined),
                    title: 'New observation',
                    subtitle: 'Log a moment',
                  ),
                  const FeatureCard(
                    leading: Icon(Icons.directions_bus_outlined),
                    title: 'Field trip',
                    subtitle: 'Start a trip',
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _OverlayComposer(),
        ),
      ],
    );
  }
}

/// The composer bar shown under the overlay (search mode).
class _OverlayComposer extends StatefulWidget {
  const _OverlayComposer();

  @override
  State<_OverlayComposer> createState() => _OverlayComposerState();
}

class _OverlayComposerState extends State<_OverlayComposer> {
  final _c = TextEditingController(text: 'sunny');
  final _f = FocusNode();

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 76,
        child: BottomOmniboxBar(
          controller: _c,
          focusNode: _f,
          mode: OmniboxMode.search,
          onChanged: (_) {},
          onSubmit: (_) {},
          onClear: () {},
          onMicTap: () {},
          onCollapse: () {},
        ),
      );
}

/// A small captioned wrapper for atom plates (the glyph + its label below).
class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

/// Render one component's plate (its variants) under light + dark, each written
/// to `gallery/<name>__<theme>.png`. [height] sizes the capture surface so the
/// plate isn't swimming in empty canvas. Skipped unless `RUN_GOLDENS=1`.
void _plate(
  String name,
  Widget Function(BuildContext) build, {
  double height = 360,
  double width = 440,
}) {
  for (final mode in const ['light', 'dark']) {
    testWidgets(
      '$name · $mode',
      (tester) async {
        await pumpAt(
          tester,
          app: ProviderScope(
            child: MaterialApp(
              theme: mode == 'dark' ? buildDarkTheme() : buildLightTheme(),
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Builder(builder: build),
                    ),
                  ),
                ),
              ),
            ),
          ),
          size: Size(width, height),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../gallery/${name}__$mode.png'),
        );
      },
      skip: !runGoldens,
    );
  }
}

/// Like [_plate] but for components with a forever-animation (shimmer, spinner):
/// pump a fixed number of frames instead of `pumpAndSettle`, which would hang
/// waiting for an animation that never settles. Captures a mid-animation frame.
void _platePumped(
  String name,
  Widget Function(BuildContext) build, {
  double height = 360,
  int frames = 5,
}) {
  for (final mode in const ['light', 'dark']) {
    testWidgets(
      '$name · $mode',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(440, height));
        tester.view.physicalSize = Size(440, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: mode == 'dark' ? buildDarkTheme() : buildLightTheme(),
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Builder(builder: build),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../gallery/${name}__$mode.png'),
        );
      },
      skip: !runGoldens,
    );
  }
}

/// Full-surface organism plate. Unlike [_plate], the caller supplies the
/// ENTIRE tree (its own `ProviderScope > MaterialApp`) so it can inject
/// Riverpod overrides + a GoRouter without threading an `Override` list
/// (which flutter_riverpod doesn't publicly export) through this helper.
/// The widget fills the whole [width]×[height] surface — these organisms
/// own the viewport, so there's no padded `Align`. [pumped] swaps
/// `pumpAndSettle` for a fixed frame count (organisms with a forever
/// animation, e.g. the live-strip's breathing dot).
void _scenePlate(
  String name, {
  required Widget Function(ThemeData theme) tree,
  double width = 440,
  double height = 760,
  bool pumped = false,
  int frames = 6,
}) {
  for (final mode in const ['light', 'dark']) {
    testWidgets(
      '$name · $mode',
      (tester) async {
        final theme = mode == 'dark' ? buildDarkTheme() : buildLightTheme();
        await tester.binding.setSurfaceSize(Size(width, height));
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(tree(theme));
        if (pumped) {
          for (var i = 0; i < frames; i++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
        } else {
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../gallery/${name}__$mode.png'),
        );
      },
      skip: !runGoldens,
    );
  }
}
