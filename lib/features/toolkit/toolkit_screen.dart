import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/master_detail_scaffold.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:differentworld/shared/widgets/shell_metrics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `/settings/toolkit` — the Teacher Toolkit catalog surface.
///
/// **Visual contract.** This screen MUST read as the same app as
/// Today / Schedule / Captures / Settings. Concretely:
///
///   - Tool tiles are [FeatureCard]s. Same primitive every other
///     drill-in row uses across the app.
///   - Category sections are [SectionCard]s. The hide-when-empty
///     primitive for grouped content, used by Today / Family /
///     Schedule.
///   - The Instead-of / Try-this / Why blocks on the detail screen
///     are also `SectionCard`s with the appropriate tones (danger,
///     featured, neutral).
///   - Category COLOR is a small accent — the leading dot of a tool
///     card, the leading chip of a section header — not a full
///     surface wash. Background surfaces use the standard Material 3
///     `surfaceContainer*` palette so a Maya-or-Jordan scrolling
///     between Today and Toolkit doesn't feel like they entered a
///     different app.
///
/// **Form-factor strategy.**
///
/// - Phone (<600dp): vertical feed of category SectionCards, each
///   containing 6 FeatureCards. Tapping a tool card pushes
///   `/settings/toolkit/:slug` so back-stack + deep-link work.
///
/// - Tablet / desktop (>=600dp): [MasterDetailScaffold]. Left rail
///   holds search + Material `FilterChip` row + 6-tool list for the
///   active category. Right pane shows the tool detail or a
///   "pick a tool" SectionCard.
class ToolkitScreen extends StatefulWidget {
  const ToolkitScreen({super.key});

  @override
  State<ToolkitScreen> createState() => _ToolkitScreenState();
}

class _ToolkitScreenState extends State<ToolkitScreen> {
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
          onPickTool: (slug) => context.push('/settings/toolkit/$slug'),
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
        const SizedBox(height: 16),
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
                padding: const EdgeInsets.only(bottom: 8),
                child: FeatureCard(
                  leading: _CategoryGlyphChip(category: hit.category),
                  title: hit.tool.name,
                  subtitle: '${hit.category.name} · ${hit.tool.when}',
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => onPickTool(hit.tool.slug),
                ),
              ),
        ] else ...[
          for (final cat in categories)
            SectionCard(

              title: _CategorySectionTitle(category: cat),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Column(
                  children: [
                    for (final tool in cat.tools)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
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
    final hits = _hits;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const ContentHeader(
          title: 'Toolkit',
          subtitle: 'Tools, not theory.',
        ),
        ToolkitSearchField(value: query, onChanged: onQueryChanged),
        const SizedBox(height: 12),
        if (searching) ...[
          if (hits.isEmpty)
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
            for (final hit in hits)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
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
          // Material FilterChip row — same widget the rest of the
          // app uses (e.g. captures inbox, surveys table). Use of
          // the official chip means cursor + keyboard + selection
          // semantics come for free.
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
          const SizedBox(height: 12),
          // Inline italic tagline — keeps the editorial voice without
          // any background washes.
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
          const SizedBox(height: 8),
          for (final tool in cat.tools)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
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
            subtitle: 'Choose one on the left to see how to use it.',
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
// Tool detail view — shared between phone screen and wide pane
// ───────────────────────────────────────────────────────────────────

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
    // Reserve chrome inset for the wide-pane case (no ContentHeader)
    // AND for the phone screen wrapping this in an EdgeScaffold —
    // both contexts need the floating chrome to not overlap the
    // first section header.
    final topInset = MediaQuery.paddingOf(context).top;
    final chromeReservation = topInset + ShellMetrics.topChromeHeight + 8;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, chromeReservation, 16, 96),
      children: [
        // Category chip — same shape as a filter chip elsewhere in
        // the app, makes the tool's home category readable at a
        // glance and ties this surface to the toolkit visual system.
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CategoryAccentDot(color: category.color),
                  const SizedBox(width: 8),
                  Text(
                    category.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          tool.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          tool.when,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          tone: SectionCardTone.danger,
          icon: Icons.block_outlined,
          title: 'Instead of',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SelectableText(
              tool.instead,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                height: 1.5,
              ),
            ),
          ),
        ),
        SectionCard(
          tone: SectionCardTone.featured,
          icon: Icons.check_circle_outline,
          title: 'Try this',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SelectableText(
              tool.tryThis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                height: 1.6,
              ),
            ),
          ),
        ),
        SectionCard(
          icon: Icons.psychology_outlined,
          title: 'Why this works',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SelectableText(
              tool.why,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.6,
              ),
            ),
          ),
        ),
        SectionCard(
          tone: SectionCardTone.featured,
          icon: Icons.bolt,
          title: 'Quick script',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
      ],
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
// Small accents — the only place category color lives
// ───────────────────────────────────────────────────────────────────

class _SearchHit {
  const _SearchHit({required this.category, required this.tool});
  final ToolkitCategory category;
  final ToolkitTool tool;
}

/// A 10-dp circle in the category color. Sits in the leading slot of
/// each tool's FeatureCard. The smallest possible category signal —
/// just enough to ride alongside the other tools in the same
/// category without dominating the surface.
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
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Category-color glyph in a small chip — used in search-result rows
/// where the row needs to identify its category at a glance (the user
/// could be looking at tools from multiple categories at once).
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

/// Smaller glyph for the FilterChip's avatar slot (Material limits
/// the avatar to 24dp).
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

/// Category section title row: glyph + name + small "6 tools" chip.
/// Used as the `title:` slot of a SectionCard. Keeps the category
/// identity visible while letting the SectionCard own the
/// background/typography conventions the rest of the app uses.
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
