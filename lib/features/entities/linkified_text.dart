import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_match.dart';
import 'package:differentworld/features/entities/entity_peek.dart';
import 'package:differentworld/features/entities/entity_providers.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the text is being read. STAFF sees the full autotag; FAMILY is the
/// privacy boundary — a sent-home / exported artifact must not turn other
/// children's names into live links (that would re-leak the identity
/// `scrubOtherNames` strips). The peeks + routes for a guardian audience aren't
/// built yet, so for now FAMILY renders plain text; the scope is here so family
/// surfaces opt into the guard the moment family-safe peeks exist.
enum EntityScope { staff, family }

/// Free-text that AUTOTAGS itself. Drop it in anywhere staff prose names other
/// things — an observation body, an incident narrative, a caption — and the
/// known entities in it become tappable, opening [showEntityPeek]. Detection is
/// on-device (`entityIndexProvider` + [findEntityMatches]); nothing is sent
/// anywhere. Degrades to plain [Text] when live entities are off, in family
/// scope, or when nothing matches — so it's a drop-in replacement for `Text`.
class LinkifiedText extends ConsumerStatefulWidget {
  const LinkifiedText(
    this.text, {
    this.style,
    this.scope = EntityScope.staff,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final EntityScope scope;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  ConsumerState<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends ConsumerState<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Widget _plain() => Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );

  @override
  Widget build(BuildContext context) {
    if (widget.scope == EntityScope.family ||
        !liveEntitiesOn(ref) ||
        widget.text.trim().isEmpty) {
      return _plain();
    }

    final index = ref.watch(entityIndexProvider);
    final matches = findEntityMatches(widget.text, index);
    if (matches.isEmpty) return _plain();

    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final brightness = Theme.of(context).brightness;

    // Fresh recognizers for this build; the previous batch is no longer in the
    // live render tree, so disposing it here is safe.
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      }
      final rec = TapGestureRecognizer()
        ..onTap = () => showEntityPeek(context, m.ref);
      _recognizers.add(rec);
      spans.add(
        TextSpan(
          text: widget.text.substring(m.start, m.end),
          style: entityInlineTextStyle(context, m.ref.kind, base: base).copyWith(
            background: Paint()
              ..color = entityChipFill(m.ref.kind.accent, brightness),
          ),
          recognizer: rec,
          semanticsLabel: '${widget.text.substring(m.start, m.end)}, '
              '${m.ref.kind.noun}',
        ),
      );
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
