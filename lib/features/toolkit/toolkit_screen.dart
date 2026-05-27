import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/master_detail_scaffold.dart';
import 'package:differentworld/shared/widgets/shell_metrics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `/settings/toolkit` — the Teacher Toolkit catalog surface.
///
/// ## Form-factor strategy
///
/// **Phone (< 600dp)** — a vertically-scrolling feed of category
/// sections, each a colored hero followed by its 6 tool cards. The
/// section headers ARE the navigation; an additional horizontal
/// "Jump to" chip strip near the top lets the user skip categories
/// without long scrolls. Tapping a tool card pushes a real route at
/// `/settings/toolkit/:slug`, so back-stack and deep-link both work
/// naturally.
///
/// **Tablet / desktop (>= 600dp)** — collapses to a
/// `MasterDetailScaffold`. The left rail holds the search field, the
/// horizontal category chip strip (active filters the tool list), and
/// the 6-tool list for the active category. The right pane holds the
/// active tool's detail, or a "pick a tool" hero when nothing is
/// selected. Selection is local-state for now; URL bookmarking is a
/// follow-up wave.
///
/// ## Where the data lives
///
/// Wave 161 catalog is a Dart const. Wave 162 will layer per-space
/// overrides on top. This screen reads through `_categories` which
/// today returns the const list and tomorrow returns a Riverpod
/// provider value — the responsive UI stays put.
class ToolkitScreen extends StatefulWidget {
  const ToolkitScreen({super.key});

  @override
  State<ToolkitScreen> createState() => _ToolkitScreenState();
}

class _ToolkitScreenState extends State<ToolkitScreen> {
  String _query = '';

  /// Wide-pane selection. On phone this is unused — selection lives in
  /// the URL via the per-tool route.
  String? _activeSlug;

  /// Wide-pane category-strip selection. Drives which 6 tools the
  /// master list shows. When the user runs a search, this is paused;
  /// tapping a search result jumps back to the result's category.
  int _activeCatIndex = 0;

  // Wave 162 will swap this for a layered provider.
  List<ToolkitCategory> get _categories => toolkitCatalog;

  ToolkitCategory get _activeCat => _categories[_activeCatIndex];

  void _pickToolWide(String slug) {
    setState(() {
      _activeSlug = slug;
      // Also align the category strip with the selected tool, so the
      // master list visibly highlights it.
      for (var i = 0; i < _categories.length; i++) {
        if (_categories[i].tools.any((t) => t.slug == slug)) {
          _activeCatIndex = i;
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = FormFactor.of(context);
    if (form == FormFactor.phone) {
      return EdgeScaffold(
        backFallbackRoute: '/settings',
        body: _MobileCatalog(
          categories: _categories,
          query: _query,
          onQueryChanged: (q) => setState(() => _query = q),
          onPickTool: (slug) =>
              context.push('/settings/toolkit/$slug'),
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
          onQueryChanged: (q) => setState(() => _query = q),
          onPickCategory: (i) => setState(() {
            _activeCatIndex = i;
            // Clear the detail when category changes — the previously
            // selected tool was likely in a different category.
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

/// Mobile catalog body — feed of category sections with a sticky-ish
/// search field at the top. Search results replace the feed entirely.
class _MobileCatalog extends StatelessWidget {
  const _MobileCatalog({
    required this.categories,
    required this.query,
    required this.onQueryChanged,
    required this.onPickTool,
  });

  final List<ToolkitCategory> categories;
  final String query;
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
    final theme = Theme.of(context);
    final searching = query.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const ContentHeader(
          title: 'Teacher Toolkit',
          subtitle: 'Tools, not theory. In-the-moment moves you can make.',
        ),
        const SizedBox(height: 12),
        ToolkitSearchField(
          value: query,
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 12),
        if (searching) ...[
          if (_hits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No tools match that search.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final hit in _hits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SearchResultCard(
                  hit: hit,
                  onTap: () => onPickTool(hit.tool.slug),
                ),
              ),
        ] else ...[
          // Wave 163.2: the JUMP TO chip strip was dropped after the
          // Council review confirmed it scrolled under the floating
          // chrome (by design across the app, but visually noisy on
          // a navigation element). The 5 colored category heroes are
          // the navigation — they scan well on mobile and naturally
          // signal "scroll for more." If a future user research
          // surface asks for quick category jumps, revisit as either
          // a pinned sliver (with chrome-aware delegate) or an
          // actions-slot bottom-sheet pattern.
          for (final cat in categories) ...[
            _CategoryHeader(category: cat),
            const SizedBox(height: 10),
            for (final tool in cat.tools)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ToolkitToolCard(
                  tool: tool,
                  category: cat,
                  onTap: () => onPickTool(tool.slug),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ],
      ],
    );
  }
}

/// Wide-window master pane — search + category chips + active
/// category's 6-tool list. Stacks vertically inside the 380dp left
/// rail of the master-detail scaffold.
class _WideMasterPane extends StatelessWidget {
  const _WideMasterPane({
    required this.categories,
    required this.activeCatIndex,
    required this.activeSlug,
    required this.query,
    required this.onQueryChanged,
    required this.onPickCategory,
    required this.onPickTool,
  });

  final List<ToolkitCategory> categories;
  final int activeCatIndex;
  final String? activeSlug;
  final String query;
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const ContentHeader(
          title: 'Toolkit',
          subtitle: 'Tools, not theory.',
        ),
        const SizedBox(height: 12),
        ToolkitSearchField(value: query, onChanged: onQueryChanged),
        const SizedBox(height: 12),
        if (searching) ...[
          if (_hits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No tools match.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final hit in _hits)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _SearchResultCard(
                  hit: hit,
                  selected: hit.tool.slug == activeSlug,
                  onTap: () => onPickTool(hit.tool.slug),
                ),
              ),
        ] else ...[
          _ChipStrip(
            categories: categories,
            activeIndex: activeCatIndex,
            onPick: onPickCategory,
          ),
          const SizedBox(height: 12),
          Text(
            cat.tagline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cat.color,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          for (final tool in cat.tools)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ToolkitToolCard(
                tool: tool,
                category: cat,
                onTap: () => onPickTool(tool.slug),
                selected: tool.slug == activeSlug,
                dense: true,
              ),
            ),
        ],
      ],
    );
  }
}

/// Right pane when no tool has been picked yet on wide windows. Shows
/// the active category's hero + a "pick a tool" hint. Keeps the canvas
/// from feeling empty.
class _WideDetailPlaceholder extends StatelessWidget {
  const _WideDetailPlaceholder({required this.category});

  final ToolkitCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CategoryHeader(category: category, large: true),
              const SizedBox(height: 16),
              Text(
                'Pick a tool on the left to see how to use it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Shared widgets — public so the per-tool route can render the same
// detail view. Prefix `Toolkit` to keep them findable + avoid clashes.
// ───────────────────────────────────────────────────────────────────

/// One tool tile, used by:
///   - mobile catalog feed (one card per tool, full width)
///   - wide master pane (`dense: true` for tighter rows)
///
/// Visual: a left rail painted with the category color, name on top,
/// `when` line below. Selected state (wide only) gets a deeper tint.
class ToolkitToolCard extends StatelessWidget {
  const ToolkitToolCard({
    required this.tool,
    required this.category,
    required this.onTap,
    this.selected = false,
    this.dense = false,
    super.key,
  });

  final ToolkitTool tool;
  final ToolkitCategory category;
  final VoidCallback onTap;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);
    return Semantics(
      label: tool.name,
      hint: tool.when,
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? category.color.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  color: category.color.withValues(
                    alpha: selected ? 1.0 : 0.55,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      dense ? 10 : 12,
                      12,
                      dense ? 10 : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tool.name,
                          style: (dense
                                  ? theme.textTheme.titleSmall
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tool.when,
                          maxLines: dense ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!dense)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
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

/// The full tool-detail view. Used by:
///   - the wide right pane (inside a ListView, no Scaffold around it)
///   - the per-tool route screen (wrapped in its own EdgeScaffold)
///
/// Stack: category hero header → tool name → "When you use this" →
/// Instead/Try paired card → Why-this-works rail → Quick-script
/// callout (always visible — this is the line teachers will actually
/// pull out in the moment).
class ToolkitToolDetailView extends StatelessWidget {
  const ToolkitToolDetailView({
    required this.tool,
    required this.category,
    super.key,
  });

  final ToolkitTool tool;
  final ToolkitCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Reserve the floating chrome (back-pill / action-pills layer the
    // AppShell paints over the body) so the category hero doesn't
    // tuck under it. The convention is that the FIRST item in a
    // scrollable owns this reservation — usually `ContentHeader` does
    // it; here `_CategoryHeader` is the visual title so we do it
    // inline.
    final topInset = MediaQuery.paddingOf(context).top;
    final chromeReservation = topInset + ShellMetrics.topChromeHeight + 8;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, chromeReservation, 20, 96),
      children: [
        _CategoryHeader(category: category),
        const SizedBox(height: 16),
        SelectableText(
          tool.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        _LabeledBlock(
          label: 'WHEN YOU USE THIS',
          accent: theme.colorScheme.onSurfaceVariant,
          child: SelectableText(
            tool.when,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        _InsteadTryPair(tool: tool, category: category),
        const SizedBox(height: 16),
        _WhyBlock(tool: tool, category: category),
        const SizedBox(height: 20),
        _QuickScriptCallout(tool: tool, category: category),
      ],
    );
  }
}

/// The "search by situation" field. Owns its own controller so parent
/// rebuilds (per-keystroke) don't recreate the field and drop the IME
/// connection. Reconciles via `didUpdateWidget` when the parent
/// programmatically clears the query (e.g. after a result tap).
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
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
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
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      textInputAction: TextInputAction.search,
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Private widgets
// ───────────────────────────────────────────────────────────────────

class _SearchHit {
  const _SearchHit({required this.category, required this.tool});
  final ToolkitCategory category;
  final ToolkitTool tool;
}

/// A search-result row. Compact card with a colored left rail to mark
/// which category the hit lives in, then category chip + tool name +
/// `when`.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.hit,
    required this.onTap,
    this.selected = false,
  });

  final _SearchHit hit;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${hit.tool.name}, ${hit.category.name}',
      hint: hit.tool.when,
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? hit.category.color.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: hit.category.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            '${hit.category.glyph}  '
                            '${hit.category.name.toUpperCase()}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: hit.category.color,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hit.tool.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          hit.tool.when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
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

/// Category-selector chip strip used in the WIDE master pane — gates
/// which 6 tools the list below shows. Acts as a filter, not a jump
/// (the wide pane has no long-scroll feed to jump within). Chip
/// tap-target is 48dp tall per the project's accessibility floor;
/// the visual chip is 32dp tall, centered inside a transparent 48dp
/// strip so cursor/touch hits the same target the chip suggests.
class _ChipStrip extends StatelessWidget {
  const _ChipStrip({
    required this.categories,
    required this.activeIndex,
    required this.onPick,
  });

  final List<ToolkitCategory> categories;
  final int activeIndex;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) => _FilterChip(
          category: categories[i],
          active: i == activeIndex,
          onTap: () => onPick(i),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final ToolkitCategory category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category.color;
    return Semantics(
      label: category.name,
      button: true,
      selected: active,
      child: Center(
        child: Material(
          color: active
              ? color.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? color.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      category.glyph,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: active
                            ? color
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: active
                          ? color
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero strip that opens every category section + sits atop the
/// per-tool detail. Soft wash of the category color, the glyph
/// floated in the corner, name on top, italic tagline below.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.category,
    this.large = false,
  });

  final ToolkitCategory category;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category.color;
    return Container(
      padding: EdgeInsets.fromLTRB(16, large ? 20 : 14, 16, large ? 20 : 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.7), width: 4),
        ),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Text(
              category.glyph,
              style: TextStyle(
                fontSize: large ? 36 : 28,
                color: color,
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name,
                  style: (large
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.titleLarge)
                      ?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.tagline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A generic "LABEL above body" block used for the "When you use this"
/// section + anywhere else we want all-caps eyebrow + content.
class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({
    required this.label,
    required this.child,
    required this.accent,
  });

  final String label;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: accent,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// The red-error-over-accent "Instead of / Try" paired card. Visual
/// anchor of the detail screen — the two-panel layout makes the
/// transformation read at a glance.
class _InsteadTryPair extends StatelessWidget {
  const _InsteadTryPair({required this.tool, required this.category});

  final ToolkitTool tool;
  final ToolkitCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: errorColor.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            border: Border.all(
              color: errorColor.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: _LabeledBlock(
            label: 'INSTEAD OF',
            accent: errorColor,
            child: SelectableText(
              tool.instead,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                height: 1.5,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            border: Border(
              left: BorderSide(
                color: category.color.withValues(alpha: 0.3),
              ),
              right: BorderSide(
                color: category.color.withValues(alpha: 0.3),
              ),
              bottom: BorderSide(
                color: category.color.withValues(alpha: 0.3),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: _LabeledBlock(
            label: 'TRY THIS',
            accent: category.color,
            child: SelectableText(
              tool.tryThis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Why this works" — a left-rail block with softer body text.
/// SelectableText so teachers can copy the rationale into their own
/// notes.
class _WhyBlock extends StatelessWidget {
  const _WhyBlock({required this.tool, required this.category});

  final ToolkitTool tool;
  final ToolkitCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: category.color.withValues(alpha: 0.45),
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: _LabeledBlock(
        label: 'WHY THIS WORKS',
        accent: theme.colorScheme.onSurfaceVariant,
        child: SelectableText(
          tool.why,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

/// The quick-script callout — the line teachers will actually pull
/// out in the moment. Visible by default; previously hidden behind a
/// toggle, but the script IS the artifact, so showing it makes the
/// detail screen feel finished.
class _QuickScriptCallout extends StatelessWidget {
  const _QuickScriptCallout({required this.tool, required this.category});

  final ToolkitTool tool;
  final ToolkitCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: category.color.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: category.color, size: 18),
              const SizedBox(width: 6),
              Text(
                'QUICK SCRIPT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: category.color,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            tool.quick,
            style: theme.textTheme.titleMedium?.copyWith(
              color: category.color,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
