import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/curricula/session_script.dart';
import 'package:flutter/material.dart';

// The beat-kind LOOK shared by the presenter (session_run_screen.dart) and
// the kid-facing room deck (session_room_slides.dart) — one mapping so a
// beat's hue/label is consistent between the host's slide and the TV,
// without either surface depending on the other.

/// One beat kind's accent — a content-driven categorical colour (NOT a theme
/// role; these are deliberately varied for at-a-glance recognition, like the
/// activity palette). Text/icons ON this fill pick contrast via
/// [AppColors.onAccent]; small dots/borders use it raw.
///
/// Mapping (per the brief): hook/reveal/rules/closing → warm amber;
/// game → blue; cooldown → teal; partner → blue; frame → purple;
/// drawing → pink; vocab → gold; prep/doorway/after → neutral brown.
Color accentForBeatKind(BeatKind kind) => switch (kind) {
  BeatKind.hook ||
  BeatKind.reveal ||
  BeatKind.rules ||
  BeatKind.closing => ActivityPalette.amber,
  BeatKind.game => ActivityPalette.blue,
  BeatKind.cooldown => ActivityPalette.teal,
  BeatKind.partner => ActivityPalette.lightBlue,
  BeatKind.frame => ActivityPalette.purple,
  BeatKind.drawing => ActivityPalette.pink,
  BeatKind.vocab => ActivityPalette.yellow,
  BeatKind.prep || BeatKind.doorway || BeatKind.after => ActivityPalette.brown,
};

/// Short kind label for the eyebrow + timeline (lowercase, the calm voice).
String beatKindLabel(BeatKind kind) => switch (kind) {
  BeatKind.prep => 'prep',
  BeatKind.hook => 'the hook',
  BeatKind.reveal => 'the reveal',
  BeatKind.rules => 'the rules',
  BeatKind.game => 'game',
  BeatKind.cooldown => 'cool down',
  BeatKind.partner => 'partner',
  BeatKind.frame => 'frame game',
  BeatKind.drawing => 'drawing',
  BeatKind.vocab => 'vocabulary',
  BeatKind.closing => 'closing',
  BeatKind.doorway => 'doorway',
  BeatKind.after => 'after',
};
