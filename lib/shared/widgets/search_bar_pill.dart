import 'package:differentworld/shared/widgets/glass_pill.dart';
import 'package:flutter/material.dart';

/// Full-width glass-pill containing a search input. Used as the
/// `topOverlay` on EdgeScaffold when search mode is active.
///
/// Leading: search icon. Trailing: close (X) icon that exits search
/// mode. The text field auto-focuses on mount.
class SearchBarPill extends StatefulWidget {
  const SearchBarPill({
    required this.controller,
    required this.onChanged,
    required this.onClose,
    this.hintText = 'Search…',
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final String hintText;

  @override
  State<SearchBarPill> createState() => _SearchBarPillState();
}

class _SearchBarPillState extends State<SearchBarPill> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Focus once after mount so the keyboard slides up with the bar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPill(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hintText,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),
          IconButton(
            tooltip: 'Close search',
            icon: Icon(
              Icons.close,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}
