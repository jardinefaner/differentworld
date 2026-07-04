import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// Shared preamble for the Speak layout views that read the WORD timeline.
/// Every mode consumes the same four inputs — the timed words, the playback
/// position, the type face, and the voice's accent hue — so the constructor
/// and fields live here once; subclasses keep only their unique layout logic
/// in [build].
abstract class SpeakWordsView extends StatelessWidget {
  const SpeakWordsView({
    required this.words,
    required this.position,
    required this.type,
    required this.accent,
    super.key,
  });

  final List<SpokenWord> words;
  final Duration position;
  final SpeakType type;
  final Color accent;
}

/// Same contract for the views that read the LINE (phrase) timeline.
abstract class SpeakLinesView extends StatelessWidget {
  const SpeakLinesView({
    required this.lines,
    required this.position,
    required this.type,
    required this.accent,
    super.key,
  });

  final List<SpokenLine> lines;
  final Duration position;
  final SpeakType type;
  final Color accent;
}
