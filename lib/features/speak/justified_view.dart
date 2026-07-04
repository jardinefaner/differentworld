import 'package:differentworld/features/speak/speak_view_base.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// The whole text as one fully-justified block — edges flush like a magazine
/// pull-quote. Uniform size + weight, so the layout is fixed; the spoken word
/// just brightens + glows in place (colour + shadow are paint-only, so the
/// justified lines never re-break).
class JustifiedView extends SpeakWordsView {
  const JustifiedView({
    required super.words,
    required super.position,
    required super.type,
    required super.accent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();
    final active = currentWordIndex(words, position);
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    final base = TextStyle(
      fontFamily: type.family,
      fontSize: 40,
      height: 1.16,
      letterSpacing: type.letterSpacing,
      fontVariations: type.axesAt(type.restWeight),
    );
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 96, 28, 100 + viewPad),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text.rich(
            TextSpan(
              children: [
                for (var i = 0; i < words.length; i++)
                  TextSpan(
                    text: i == words.length - 1
                        ? words[i].text
                        : '${words[i].text} ',
                    style: base.copyWith(
                      color: Colors.white.withValues(
                        alpha: i == active
                            ? 1.0
                            : i < active
                            ? 0.55
                            : 0.45,
                      ),
                      shadows: i == active
                          ? [
                              Shadow(
                                color: accent.withValues(alpha: 0.6),
                                blurRadius: 26,
                              ),
                            ]
                          : null,
                    ),
                  ),
              ],
            ),
            textAlign: TextAlign.justify,
          ),
        ),
      ),
    );
  }
}
