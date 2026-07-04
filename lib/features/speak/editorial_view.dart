import 'package:differentworld/features/speak/speak_view_base.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// The editorial one — a designed magazine pull-quote, not a kinetic effect.
/// An oversized opening quotation mark hanging in the margin, the text set as a
/// justified serif column with generous leading, and a hairline rule beneath.
/// The spoken word is marked with a quiet accent UNDERLINE (decoration is
/// paint-only, so the justified lines never re-break) — restraint over glow.
class EditorialView extends SpeakWordsView {
  const EditorialView({
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
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(40, 84, 40, 100 + viewPad),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Oversized opening quote, hanging slightly into the left margin.
              Transform.translate(
                offset: const Offset(-6, 0),
                child: Text(
                  '“',
                  style: TextStyle(
                    fontFamily: type.family,
                    fontSize: 110,
                    height: 0.72,
                    color: accent.withValues(alpha: 0.5),
                    fontVariations: type.axesAt(type.activeWeight),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    for (var i = 0; i < words.length; i++)
                      TextSpan(
                        text: i == words.length - 1
                            ? words[i].text
                            : '${words[i].text} ',
                        style: TextStyle(
                          fontFamily: type.family,
                          fontSize: 34,
                          height: 1.42,
                          letterSpacing: type.letterSpacing,
                          color: Colors.white.withValues(
                            alpha: i == active ? 1.0 : 0.5,
                          ),
                          fontVariations: type.axesAt(type.restWeight),
                          decoration: i == active
                              ? TextDecoration.underline
                              : null,
                          decorationColor: accent,
                          decorationThickness: 2,
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 30),
              // A hairline rule — the editorial sign-off.
              Container(
                height: 1.5,
                width: 72,
                color: accent.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
