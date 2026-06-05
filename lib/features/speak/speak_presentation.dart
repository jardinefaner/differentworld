import 'package:flutter/material.dart';

/// How the words are presented on the stage. One timing model (lines / words /
/// position), many looks — the user flips between them live, and picks a
/// default before speaking.
enum SpeakPresentation {
  editorial,
  stage,
  packed,
  oneBigWord,
  stack,
  collage,
  spotlight,
  mural,
  grid,
  justified,
  contents,
  shape,
}

extension SpeakPresentationX on SpeakPresentation {
  String get label => switch (this) {
    SpeakPresentation.editorial => 'Editorial',
    SpeakPresentation.stage => 'Stage',
    SpeakPresentation.packed => 'Packed',
    SpeakPresentation.oneBigWord => 'One Big Word',
    SpeakPresentation.stack => 'Stack',
    SpeakPresentation.collage => 'Collage',
    SpeakPresentation.spotlight => 'Spotlight',
    SpeakPresentation.mural => 'Mural',
    SpeakPresentation.grid => 'Grid',
    SpeakPresentation.justified => 'Justified',
    SpeakPresentation.contents => 'Index',
    SpeakPresentation.shape => 'Shape',
  };

  IconData get icon => switch (this) {
    SpeakPresentation.editorial => Icons.format_quote_rounded,
    SpeakPresentation.stage => Icons.notes_rounded,
    SpeakPresentation.packed => Icons.view_agenda_rounded,
    SpeakPresentation.oneBigWord => Icons.title_rounded,
    SpeakPresentation.stack => Icons.layers_rounded,
    SpeakPresentation.collage => Icons.dashboard_rounded,
    SpeakPresentation.spotlight => Icons.highlight_rounded,
    SpeakPresentation.mural => Icons.wallpaper_rounded,
    SpeakPresentation.grid => Icons.grid_view_rounded,
    SpeakPresentation.justified => Icons.format_align_justify_rounded,
    SpeakPresentation.contents => Icons.format_list_numbered_rounded,
    SpeakPresentation.shape => Icons.blur_circular_rounded,
  };
}

/// The modes wired so far — the picker only offers these. Editorial leads (it's
/// the calm, designed pull-quote — the most editorial of the set).
const List<SpeakPresentation> implementedSpeakModes = <SpeakPresentation>[
  SpeakPresentation.editorial,
  SpeakPresentation.stage,
  SpeakPresentation.packed,
  SpeakPresentation.oneBigWord,
  SpeakPresentation.stack,
  SpeakPresentation.collage,
  SpeakPresentation.spotlight,
  SpeakPresentation.mural,
  SpeakPresentation.grid,
  SpeakPresentation.justified,
  SpeakPresentation.contents,
  SpeakPresentation.shape,
];

/// The next implemented mode — drives the perform-chrome cycle button.
SpeakPresentation nextSpeakMode(SpeakPresentation mode) {
  final i = implementedSpeakModes.indexOf(mode);
  return implementedSpeakModes[(i + 1) % implementedSpeakModes.length];
}
