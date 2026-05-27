import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';

/// `/settings/toolkit` — the Teacher Toolkit reference screen.
///
/// Read-only browser over the [toolkitCatalog]: search-by-situation,
/// five category tabs, six tools per tab. Tapping a tool expands its
/// detail card in place (Instead of / Try this / Why this works / Quick
/// script). No data layer; the entire surface reads from a Dart const
/// list and rebuilds locally.
///
/// Wave 162 will graduate this to read from a layered provider (built-
/// ins + per-space overrides). The widget signature stays the same;
/// only the source of `_categories` changes.
class ToolkitScreen extends StatefulWidget {
  const ToolkitScreen({super.key});

  @override
  State<ToolkitScreen> createState() => _ToolkitScreenState();
}

class _ToolkitScreenState extends State<ToolkitScreen> {
  /// Index into [_categories] for the currently-shown category. When
  /// the user runs a search, the category strip is hidden and this
  /// index pauses; tapping a search result restores it to the
  /// result's category.
  int _activeCat = 0;

  /// Slug of the currently-expanded tool within [_activeCat], or null
  /// for "show the selector list, no detail." Kept as a slug (not an
  /// index) so it survives Wave 162's reordering of overrides.
  String? _activeToolSlug;

  /// When true, the detail card shows the quick-script chip beneath
  /// the why-this-works block. Off by default — the quick script is a
  /// glanceable summary, the rest is the real content.
  bool _showQuick = false;

  /// Search query, lowercased and trimmed once per keystroke.
  String _query = '';

  // Wave 161 reads from the Dart constant. Wave 162 swaps this for a
  // Riverpod provider that merges built-ins + per-space overrides.
  // The rest of the screen reads through [_categories] so the
  // promotion is a one-line change.
  List<ToolkitCategory> get _categories => toolkitCatalog;

  ToolkitCategory get _cat => _categories[_activeCat];

  ToolkitTool? get _activeTool {
    if (_activeToolSlug == null) return null;
    for (final t in _cat.tools) {
      if (t.slug == _activeToolSlug) return t;
    }
    return null;
  }

  List<_SearchHit> get _searchResults {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <_SearchHit>[];
    for (final cat in _categories) {
      for (final tool in cat.tools) {
        if (tool.searchHaystack.contains(q)) {
          out.add(_SearchHit(category: cat, tool: tool));
        }
      }
    }
    return out;
  }

  void _selectTool(String slug, {ToolkitCategoryId? jumpToCategory}) {
    setState(() {
      if (jumpToCategory != null) {
        _activeCat = _categories.indexWhere((c) => c.id == jumpToCategory);
      }
      _activeToolSlug = slug;
      _showQuick = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hits = _searchResults;
    final searching = _query.trim().isNotEmpty;

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const ContentHeader(
            title: 'Teacher Toolkit',
            subtitle:
                'Not theory. Tools. Sentences you can say, moves you '
                'can make, systems you can build. Search by situation.',
          ),
          const SizedBox(height: 12),
          _SearchField(
            onChanged: (q) => setState(() => _query = q),
            initialValue: _query,
          ),
          const SizedBox(height: 12),
          if (searching) ...[
            if (hits.isEmpty)
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
              for (final hit in hits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SearchResultCard(
                    hit: hit,
                    onTap: () => _selectTool(
                      hit.tool.slug,
                      jumpToCategory: hit.category.id,
                    ),
                  ),
                ),
          ] else ...[
            _CategoryStrip(
              categories: _categories,
              activeIndex: _activeCat,
              onPick: (i) => setState(() {
                _activeCat = i;
                _activeToolSlug = null;
                _showQuick = false;
              }),
            ),
            const SizedBox(height: 16),
            Text(
              _cat.tagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _cat.color,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            for (final tool in _cat.tools)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _ToolListTile(
                  tool: tool,
                  category: _cat,
                  selected: tool.slug == _activeToolSlug,
                  onTap: () => setState(() {
                    _activeToolSlug =
                        tool.slug == _activeToolSlug ? null : tool.slug;
                    _showQuick = false;
                  }),
                ),
              ),
            if (_activeTool != null) ...[
              const SizedBox(height: 16),
              _ToolDetailCard(
                tool: _activeTool!,
                category: _cat,
                showQuick: _showQuick,
                onToggleQuick: () =>
                    setState(() => _showQuick = !_showQuick),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One entry in the search-results stack — bundles the matched tool
/// with the category it came from (used to render the colored left
/// rail and the small category chip above the title).
class _SearchHit {
  const _SearchHit({required this.category, required this.tool});
  final ToolkitCategory category;
  final ToolkitTool tool;
}

/// The "Search by situation" text field. Owns its own controller so
/// parent rebuilds from each keystroke don't recreate the field and
/// jump the cursor / drop the IME connection.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged, required this.initialValue});

  final ValueChanged<String> onChanged;
  final String initialValue;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent clears `_query` to '' when the user taps a search result;
    // sync the controller so the field visually clears too. Skip if
    // text already matches (avoids cursor jumps mid-typing — every
    // keystroke triggers a parent rebuild that ends up here).
    if (widget.initialValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(
          offset: widget.initialValue.length,
        ),
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
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: "Search by situation… (e.g. 'angry', 'parent', 'morning')",
        border: OutlineInputBorder(),
        isDense: true,
      ),
      textInputAction: TextInputAction.search,
    );
  }
}

/// The horizontal scrolling strip of five category chips. The active
/// chip's underline + tint use the category's accent color; inactive
/// chips are surface-tinted with a muted glyph.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.activeIndex,
    required this.onPick,
  });

  final List<ToolkitCategory> categories;
  final int activeIndex;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i == categories.length - 1 ? 0 : 6,
              ),
              child: _CategoryChip(
                category: categories[i],
                active: i == activeIndex,
                onTap: () => onPick(i),
                textTheme: theme.textTheme,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.active,
    required this.onTap,
    required this.textTheme,
  });

  final ToolkitCategory category;
  final bool active;
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = active
        ? category.color.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerLow;
    final fg = active ? category.color : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: category.name,
      button: true,
      selected: active,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? category.color.withValues(alpha: 0.35)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(
                    category.glyph,
                    style: textTheme.titleSmall?.copyWith(color: fg),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  category.name,
                  style: textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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

/// One row in the category's tool selector. Compact two-line card:
/// title above, `when` below. Active row gets a colored left rail
/// and a deeper tint; inactive rows sit on the standard surface.
class _ToolListTile extends StatelessWidget {
  const _ToolListTile({
    required this.tool,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ToolkitTool tool;
  final ToolkitCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: tool.name,
      hint: tool.when,
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? category.color.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: selected ? category.color : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tool.when,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

/// The expanded "what to do" card for a selected tool. Three blocks
/// stacked: the Instead-of/Try-this pair (red top, accent bottom),
/// the Why-this-works rationale, and the optional Quick-script
/// callout (hidden by default — too punchy to lead with).
class _ToolDetailCard extends StatelessWidget {
  const _ToolDetailCard({
    required this.tool,
    required this.category,
    required this.showQuick,
    required this.onToggleQuick,
  });

  final ToolkitTool tool;
  final ToolkitCategory category;
  final bool showQuick;
  final VoidCallback onToggleQuick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: category.color.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tool.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tool.when.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: category.color,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _InsteadTryPair(tool: tool, category: category),
          const SizedBox(height: 14),
          _WhyBlock(tool: tool, category: category),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onToggleQuick,
            style: OutlinedButton.styleFrom(
              foregroundColor: category.color,
              side: BorderSide(
                color: category.color.withValues(alpha: 0.4),
              ),
              minimumSize: const Size.fromHeight(40),
            ),
            icon: Icon(showQuick ? Icons.visibility_off : Icons.bolt),
            label: Text(
              showQuick ? 'Hide quick script' : 'Show quick script',
            ),
          ),
          if (showQuick) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: category.color.withValues(alpha: 0.35),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SelectableText(
                tool.quick,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: category.color,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The red-over-accent "Instead of / Try" pair. Always uses
/// `Theme.colorScheme.error` for the top half so the contrast
/// reads consistently regardless of the category color.
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
              top: Radius.circular(10),
            ),
            border: Border.all(
              color: errorColor.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INSTEAD OF',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: errorColor,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                tool.instead,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(10),
            ),
            border: Border(
              left: BorderSide(
                color: category.color.withValues(alpha: 0.2),
              ),
              right: BorderSide(
                color: category.color.withValues(alpha: 0.2),
              ),
              bottom: BorderSide(
                color: category.color.withValues(alpha: 0.2),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRY THIS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: category.color,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                tool.tryThis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Why this works" sidebar — a left-rail block with the category
/// color and a softer body text color. Selectable so teachers can
/// copy the rationale into their own notes.
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
            color: category.color.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHY THIS WORKS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            tool.why,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the global search overlay. Shows the category chip
/// above the matched tool name + `when` line so teachers can scan
/// which surface a hit lives in.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.hit, required this.onTap});

  final _SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${hit.tool.name}, ${hit.category.name}',
      hint: hit.tool.when,
      button: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: hit.category.color, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hit.tool.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hit.tool.when,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
