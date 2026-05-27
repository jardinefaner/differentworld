import 'dart:async';

import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/features/toolkit/toolkit_recents.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/master_detail_scaffold.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:differentworld/shared/widgets/shell_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/settings/toolkit` — the Teacher Toolkit catalog surface.
///
/// **Visual contract.** Reads as the same app as Today / Schedule /
/// Captures / Settings. Tool tiles are [FeatureCard]s, category
/// sections are [SectionCard]s, the detail blocks are SectionCards
/// with semantic tones (featured / neutral / danger). Category color
/// is an accent only — a 10dp dot, a 28dp glyph chip, a tinted
/// breadcrumb on the detail screen.
///
/// **Form-factor strategy.**
///
/// - Phone (<600dp): vertical feed of category SectionCards, each
///   containing 6 FeatureCards. Recently-viewed shelf surfaces at
///   the top when non-empty. Tapping a tool card pushes
///   `/settings/toolkit/:slug` so back-stack + deep-link both work.
///
/// - Tablet / desktop (>=600dp): [MasterDetailScaffold]. Left rail
///   holds search + FilterChip row + the active category's tools.
///   Right pane shows the tool detail or a "pick a tool" placeholder.
///
/// **In-the-moment ordering.** The detail screen surfaces the
/// **Quick script** card immediately under the title — the line a
/// teacher actually pulls out mid-crisis. "Instead of" (the
/// anti-pattern) collapses to a small disclosure at the bottom of
/// the screen so a kid sitting next to the teacher doesn't see harsh
/// phrases by default.
class ToolkitScreen extends ConsumerStatefulWidget {
  const ToolkitScreen({super.key});

  @override
  ConsumerState<ToolkitScreen> createState() => _ToolkitScreenState();
}

class _ToolkitScreenState extends ConsumerState<ToolkitScreen> {
  String _query = '';
  String? _activeSlug;
  int _activeCatIndex = 0;

  // Wave 162 will swap this for a layered provider.
  List<ToolkitCategory> get _categories => toolkitCatalog;
  ToolkitCategory get _activeCat => _categories[_activeCatIndex];

  void _pickToolWide(String slug) {
    setState(() {
      _activeSlug = slug;
      for (var i = 0; i < _categories.length; i++) {
        if (_categories[i].tools.any((t) => t.slug == slug)) {
          _activeCatIndex = i;
          break;
        }
      }
    });
    // Recents bump for wide form factor too — selecting a tool in the
    // master-detail surface counts as "opening" it.
    unawaited(ref.read(toolkitRecentsProvider.notifier).touch(slug));
  }

  /// Guarded push: if we're already at this slug's route we no-op.
  /// Defends against the rapid-double-tap-double-push scenario the
  /// Red Team flagged for mid-range Android devices.
  void _pushToolPhone(String slug) {
    final current =
        GoRouterState.of(context).uri.path; // e.g. /settings/toolkit
    final target = '/settings/toolkit/$slug';
    if (current == target) return;
    unawaited(context.push(target));
  }

  @override
  Widget build(BuildContext context) {
    final form = FormFactor.of(context);
    final recents = ref.watch(toolkitRecentsProvider).value ?? const [];
    if (form == FormFactor.phone) {
      return EdgeScaffold(
        backFallbackRoute: '/settings',
        body: _MobileCatalog(
          categories: _categories,
          query: _query,
          recents: recents,
          onQueryChanged: (q) => setState(() => _query = q),
          onPickTool: _pushToolPhone,
        ),
      );
    }
    final selectedTool = _activeSlug == null
        ? null
        : findToolBySlug(_activeSlug!);
    return EdgeScaffold(
      backFallbackRoute: '/settings',
      body: MasterDetailScaffold(
        collapseAt: Breakpoints.smallTablet,
        listWidth: 380,
        list: _WideMasterPane(
          categories: _categories,
          activeCatIndex: _activeCatIndex,
          activeSlug: _activeSlug,
          query: _query,
          recents: recents,
          onQueryChanged: (q) => setState(() => _query = q),
          onPickCategory: (i) => setState(() {
            _activeCatIndex = i;
            _activeSlug = null;
          }),
          onPickTool: _pickToolWide,
        ),
        detail: selectedTool == null
            ? _WideDetailPlaceholder(category: _activeCat)
            : ToolkitToolDetailView(
                tool: selectedTool,
                category: categoryById(selectedTool.categoryId),
              ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Mobile catalog
// ───────────────────────────────────────────────────────────────────

class _MobileCatalog extends StatelessWidget {
  const _MobileCatalog({
    required this.categories,
    required this.query,
    required this.recents,
    required this.onQueryChanged,
    required this.onPickTool,
  });

  final List<ToolkitCategory> categories;
  final String query;
  final List<String> recents;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onPickTool;

  List<_SearchHit> get _hits {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <_SearchHit>[];
    for (final c in categories) {
      for (final t in c.tools) {
        if (t.searchHaystack.contains(q)) {
          out.add(_SearchHit(category: c, tool: t));
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().isNotEmpty;
    final hits = _hits;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        const ContentHeader(
          title: 'Teacher Toolkit',
          subtitle: 'Tools, not theory. In-the-moment moves you can make.',
        ),
        ToolkitSearchField(value: query, onChanged: onQueryChanged),
        const SizedBox(height: 20),
        if (searching) ...[
          if (hits.isEmpty)
            EmptyState(
              icon: Icons.search_off,
              title: 'No tools match',
              message: "Try a different word — 'angry', 'parent', "
                  "'morning', 'praise'.",
              action: TextButton(
                onPressed: () => onQueryChanged(''),
                child: const Text('Clear search'),
              ),
            )
          else
            for (final hit in hits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FeatureCard(
                  leading: _CategoryGlyphChip(category: hit.category),
                  title: hit.tool.name,
                  subtitle: '${hit.category.name} · ${hit.tool.when}',
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => onPickTool(hit.tool.slug),
                ),
              ),
        ] else ...[
          if (recents.isNotEmpty) ...[
            _RecentsShelf(slugs: recents, onPickTool: onPickTool),
            const SizedBox(height: 12),
          ],
          for (final cat in categories) ...[
            SectionCard(
              title: _CategorySectionTitle(category: cat),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
                child: Column(
                  children: [
                    for (final tool in cat.tools)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FeatureCard(
                          leading: _CategoryAccentDot(color: cat.color),
                          title: tool.name,
                          subtitle: tool.when,
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 18,
                          ),
                          onTap: () => onPickTool(tool.slug),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// "Recent" shelf — horizontal list of the last-5 tools the user
/// opened. Surfaces only when non-empty. Tapping a chip pushes the
/// per-tool route (same as a catalog tap).
class _RecentsShelf extends StatelessWidget {
  const _RecentsShelf({required this.slugs, required this.onPickTool});

  final List<String> slugs;
  final ValueChanged<String> onPickTool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = [
      for (final s in slugs)
        if (findToolBySlug(s) != null) findToolBySlug(s)!,
    ];
    if (tools.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Icon(
                Icons.history,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'RECENT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: tools.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final tool = tools[i];
              final cat = categoryById(tool.categoryId);
              return _RecentChip(
                tool: tool,
                category: cat,
                onTap: () => onPickTool(tool.slug),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.tool,
    required this.category,
    required this.onTap,
  });

  final ToolkitTool tool;
  final ToolkitCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${tool.name}, ${category.name}',
      button: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 200,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _CategoryAccentDot(color: category.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: category.color,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tool.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Wide master pane (>= 600dp)
// ───────────────────────────────────────────────────────────────────

class _WideMasterPane extends StatelessWidget {
  const _WideMasterPane({
    required this.categories,
    required this.activeCatIndex,
    required this.activeSlug,
    required this.query,
    required this.recents,
    required this.onQueryChanged,
    required this.onPickCategory,
    required this.onPickTool,
  });

  final List<ToolkitCategory> categories;
  final int activeCatIndex;
  final String? activeSlug;
  final String query;
  final List<String> recents;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onPickCategory;
  final ValueChanged<String> onPickTool;

  List<_SearchHit> get _hits {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <_SearchHit>[];
    for (final c in categories) {
      for (final t in c.tools) {
        if (t.searchHaystack.contains(q)) {
          out.add(_SearchHit(category: c, tool: t));
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searching = query.trim().isNotEmpty;
    final cat = categories[activeCatIndex];
    final hits = _hits;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const ContentHeader(
          title: 'Toolkit',
          subtitle: 'Tools, not theory.',
        ),
        ToolkitSearchField(value: query, onChanged: onQueryChanged),
        const SizedBox(height: 14),
        if (searching) ...[
          if (hits.isEmpty)
            EmptyState(
              icon: Icons.search_off,
              title: 'No tools match',
              message: 'Try a different word.',
              action: TextButton(
                onPressed: () => onQueryChanged(''),
                child: const Text('Clear search'),
              ),
            )
          else
            for (final hit in hits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FeatureCard(
                  tone: hit.tool.slug == activeSlug
                      ? FeatureCardTone.selected
                      : FeatureCardTone.neutral,
                  leading: _CategoryGlyphChip(category: hit.category),
                  title: hit.tool.name,
                  subtitle: '${hit.category.name} · ${hit.tool.when}',
                  onTap: () => onPickTool(hit.tool.slug),
                ),
              ),
        ] else ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < categories.length; i++)
                FilterChip(
                  selected: i == activeCatIndex,
                  onSelected: (_) => onPickCategory(i),
                  avatar: _CategoryGlyphSmall(category: categories[i]),
                  label: Text(categories[i].name),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              cat.tagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final tool in cat.tools)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FeatureCard(
                tone: tool.slug == activeSlug
                    ? FeatureCardTone.selected
                    : FeatureCardTone.neutral,
                leading: _CategoryAccentDot(color: cat.color),
                title: tool.name,
                subtitle: tool.when,
                onTap: () => onPickTool(tool.slug),
              ),
            ),
          if (recents.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RecentsShelf(slugs: recents, onPickTool: onPickTool),
          ],
        ],
      ],
    );
  }
}

class _WideDetailPlaceholder extends StatelessWidget {
  const _WideDetailPlaceholder({required this.category});

  final ToolkitCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ListView(
        children: [
          const ContentHeader(
            title: 'Pick a tool',
            subtitle: 'When a moment hits, pick the tool that fits.',
          ),
          SectionCard(
            title: _CategorySectionTitle(category: category),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                category.tagline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Tool detail view — script-first, anti-pattern last
// ───────────────────────────────────────────────────────────────────

/// The narrative on this screen is intentional:
///   1. Breadcrumb chip (category color tint) + tool name + when
///   2. **Quick script** — the line for the moment, with a copy
///      button. Featured tone, big type. Topmost so a stressed
///      teacher finds it without scrolling.
///   3. **Try this** — the recommended move, longer-form.
///   4. **Why this works** — the rationale.
///   5. **Instead of** — the anti-pattern. Collapsed by default so
///      a kid sitting next to the teacher doesn't see the harsh
///      phrase. Tap to expand.
class ToolkitToolDetailView extends ConsumerStatefulWidget {
  const ToolkitToolDetailView({
    required this.tool,
    required this.category,
    super.key,
  });

  final ToolkitTool tool;
  final ToolkitCategory category;

  @override
  ConsumerState<ToolkitToolDetailView> createState() =>
      _ToolkitToolDetailViewState();
}

class _ToolkitToolDetailViewState
    extends ConsumerState<ToolkitToolDetailView> {
  bool _showAntiPattern = false;
  String? _touchedSlug;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Touch recents the first time this detail comes alive for a
    // given slug. Guard with `_touchedSlug` so didChangeDependencies
    // (which can fire multiple times across MediaQuery/theme changes)
    // doesn't bump the same slug repeatedly within one mount.
    if (_touchedSlug != widget.tool.slug) {
      _touchedSlug = widget.tool.slug;
      // Avoid setState-mid-build by deferring the notifier write.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(toolkitRecentsProvider.notifier)
              .touch(widget.tool.slug),
        );
      });
    }
  }

  Future<void> _copyScript() async {
    await Clipboard.setData(ClipboardData(text: widget.tool.quick));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Quick script copied. Paste into a note or text.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tool = widget.tool;
    final category = widget.category;
    final topInset = MediaQuery.paddingOf(context).top;
    final chromeReservation =
        topInset + ShellMetrics.topChromeHeight + 8;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, chromeReservation, 16, 96),
      children: [
        // Category breadcrumb — small tinted pill. Color carries the
        // category identity; the surface tint shifts to the category
        // color so the destination is instantly readable in any
        // context (wide pane, deep link, browser tab title).
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      category.glyph,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: category.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: category.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SelectableText(
          tool.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          tool.when,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),

        // 1. QUICK SCRIPT — front and center. Featured tone, big
        // text, copy button. This is the line a teacher actually
        // pulls out.
        SectionCard(
          tone: SectionCardTone.featured,
          icon: Icons.bolt,
          title: 'Quick script',
          trailing: IconButton(
            tooltip: 'Copy script',
            icon: const Icon(Icons.copy_outlined, size: 20),
            onPressed: _copyScript,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
            child: SelectableText(
              tool.quick,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ),

        // 2. TRY THIS — neutral tone, the full move.
        SectionCard(
          icon: Icons.check_circle_outline,
          title: 'Try this',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SelectableText(
              tool.tryThis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.6,
              ),
            ),
          ),
        ),

        // 3. WHY THIS WORKS — context for the teacher (not the kid).
        SectionCard(
          icon: Icons.psychology_outlined,
          title: 'Why this works',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SelectableText(
              tool.why,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
        ),

        // 4. ANTI-PATTERN — collapsed by default. Educational
        // (teachers benefit from seeing what to avoid) but not the
        // first thing on screen since a kid sitting next to the
        // teacher could read the harsh phrase verbatim.
        _AntiPatternCard(
          tool: tool,
          expanded: _showAntiPattern,
          onToggle: () =>
              setState(() => _showAntiPattern = !_showAntiPattern),
        ),
      ],
    );
  }
}

/// Collapsible "Instead of" card. Closed by default — the bad-day
/// scenario where a kid is reading the teacher's phone over their
/// shoulder is real, and the anti-pattern phrases are sometimes
/// exactly the words the kid is trying to recover from. Teachers can
/// expand it for self-study or training; in the moment, it stays
/// closed.
class _AntiPatternCard extends StatelessWidget {
  const _AntiPatternCard({
    required this.tool,
    required this.expanded,
    required this.onToggle,
  });

  final ToolkitTool tool;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      tone: SectionCardTone.danger,
      icon: Icons.block_outlined,
      title: 'Instead of',
      trailing: IconButton(
        tooltip: expanded ? 'Hide' : 'Show',
        icon: Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          size: 22,
        ),
        onPressed: onToggle,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? SelectableText(
                  tool.instead,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    height: 1.5,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    "Tap to reveal the anti-pattern (hidden so it's "
                    'not visible to nearby kids).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer
                          .withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Search field — owns its own controller; survives parent rebuilds
// ───────────────────────────────────────────────────────────────────

class ToolkitSearchField extends StatefulWidget {
  const ToolkitSearchField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<ToolkitSearchField> createState() => _ToolkitSearchFieldState();
}

class _ToolkitSearchFieldState extends State<ToolkitSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant ToolkitSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final hadFocus =
          FocusScope.of(context).hasFocus && _controller.selection.isValid;
      final clampedOffset = hadFocus
          ? _controller.selection.baseOffset.clamp(0, widget.value.length)
          : widget.value.length;
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: clampedOffset),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.onChanged(''),
              ),
        hintText: "Search by situation… ('angry', 'parent', 'morning')",
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 1.5,
          ),
        ),
        isDense: true,
      ),
      textInputAction: TextInputAction.search,
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Small accents — the only place category color lives
// ───────────────────────────────────────────────────────────────────

class _SearchHit {
  const _SearchHit({required this.category, required this.tool});
  final ToolkitCategory category;
  final ToolkitTool tool;
}

class _CategoryAccentDot extends StatelessWidget {
  const _CategoryAccentDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _CategoryGlyphChip extends StatelessWidget {
  const _CategoryGlyphChip({required this.category});

  final ToolkitCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          category.glyph,
          style: theme.textTheme.titleMedium?.copyWith(color: category.color),
        ),
      ),
    );
  }
}

class _CategoryGlyphSmall extends StatelessWidget {
  const _CategoryGlyphSmall({required this.category});

  final ToolkitCategory category;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        category.glyph,
        style: TextStyle(color: category.color, fontSize: 14),
      ),
    );
  }
}

class _CategorySectionTitle extends StatelessWidget {
  const _CategorySectionTitle({required this.category});

  final ToolkitCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: ExcludeSemantics(
            child: Text(
              category.glyph,
              style: theme.textTheme.titleMedium?.copyWith(
                color: category.color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                category.tagline,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
