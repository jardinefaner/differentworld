import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// One PAGE at a time (pages come from the author's own line breaks), packed
/// tight: words sized by importance (ALL-CAPS / long / "!" run big, fillers
/// run small — content-aware, not random like Mural), stacked with almost no
/// leading so the rows touch. A Wrap with varied sizes naturally falls into
/// rows of one / two / three words. The spoken word lights up in place; sizes
/// are fixed, so the pack never reflows.
class PackedView extends StatelessWidget {
  const PackedView({
    required this.pages,
    required this.position,
    required this.type,
    required this.accent,
    super.key,
  });

  /// Each "line" here is a PAGE — a group of words from one input line.
  final List<SpokenLine> pages;
  final Duration position;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final idx = lineIndexAt(pages, position);
    final child = (idx < 0 || pages.isEmpty)
        ? const SizedBox.shrink(key: ValueKey('packed-lead-in'))
        : _PackedPage(
            key: ValueKey('packed-$idx'),
            page: pages[idx],
            activeWord: currentWordIndex(pages[idx].words, position),
            type: type,
            accent: accent,
          );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(anim),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _PackedPage extends StatelessWidget {
  const _PackedPage({
    required this.page,
    required this.activeWord,
    required this.type,
    required this.accent,
    super.key,
  });

  final SpokenLine page;
  final int activeWord;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 80, 18, 100 + viewPad),
        child: FittedBox(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              // No run spacing — the tight line-height makes rows touch.
              children: [
                for (var i = 0; i < page.words.length; i++)
                  _PackedWord(
                    text: page.words[i].text,
                    active: i == activeWord,
                    type: type,
                    accent: accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackedWord extends StatelessWidget {
  const _PackedWord({
    required this.text,
    required this.active,
    required this.type,
    required this.accent,
  });

  final String text;
  final bool active;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Content-aware: size scales with importance (26 → ~120). Fixed per word
    // (no change on active), so the pack never shifts. Heavier too when big.
    final emph = wordEmphasis(text);
    final size = 26 + emph * 94;
    final weight = emph > 0.45 ? type.activeWeight : type.restWeight;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutQuart,
      style: TextStyle(
        fontFamily: type.family,
        fontSize: size,
        height: 0.82, // tight — rows touch
        letterSpacing: type.letterSpacing,
        color: Colors.white.withValues(alpha: active ? 1 : 0.62),
        fontVariations: type.axesAt(weight),
        shadows: active
            ? [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 30)]
            : null,
      ),
      child: Text(text),
    );
  }
}
