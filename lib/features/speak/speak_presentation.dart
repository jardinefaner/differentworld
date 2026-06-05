import 'package:flutter/material.dart';

/// How the words are presented on the stage. One timing model (lines / words /
/// position), many looks — the user flips between them live, and picks a
/// default before speaking.
enum SpeakPresentation { stage, oneBigWord, stack, collage, spotlight, mural }

extension SpeakPresentationX on SpeakPresentation {
  String get label => switch (this) {
    SpeakPresentation.stage => 'Stage',
    SpeakPresentation.oneBigWord => 'One Big Word',
    SpeakPresentation.stack => 'Stack',
    SpeakPresentation.collage => 'Collage',
    SpeakPresentation.spotlight => 'Spotlight',
    SpeakPresentation.mural => 'Mural',
  };

  IconData get icon => switch (this) {
    SpeakPresentation.stage => Icons.notes_rounded,
    SpeakPresentation.oneBigWord => Icons.title_rounded,
    SpeakPresentation.stack => Icons.layers_rounded,
    SpeakPresentation.collage => Icons.dashboard_rounded,
    SpeakPresentation.spotlight => Icons.highlight_rounded,
    SpeakPresentation.mural => Icons.wallpaper_rounded,
  };
}

/// The modes wired so far — the picker only offers these.
const List<SpeakPresentation> implementedSpeakModes = <SpeakPresentation>[
  SpeakPresentation.stage,
  SpeakPresentation.oneBigWord,
  SpeakPresentation.stack,
  SpeakPresentation.collage,
  SpeakPresentation.spotlight,
  SpeakPresentation.mural,
];

/// The next implemented mode — drives the perform-chrome cycle button.
SpeakPresentation nextSpeakMode(SpeakPresentation mode) {
  final i = implementedSpeakModes.indexOf(mode);
  return implementedSpeakModes[(i + 1) % implementedSpeakModes.length];
}
