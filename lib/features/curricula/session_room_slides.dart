// The ROOM FACE of a session script — the clean, KID-FACING deck the staffer
// casts to the TV. The presenter (session_run_screen.dart) shows the TEACHER's
// script ("Say this…", stage cues, the full verbatim lines); this builds the
// opposite — what the KIDS should see on the room screen: the big prompt, the
// game, the words for the wall, the call-and-response. The teacher's lines NEVER
// cross into here.
//
// This file builds DATA (a `List<PresentSlide>` for the shared present engine,
// lib/features/live_session/slide_present.dart). It is NOT a raw canvas: the
// only colour it passes is a `Color? accent` from [ActivityPalette] via the
// beat-kind map — the SlidePresentScreen (TV-dark, on the theme allowlist) is
// where those content colours render. No `Colors.*` / hex literals belong here.

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/curricula/session_script.dart';
import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:flutter/material.dart';

/// Build the KID-FACING room deck for [script] — one [PresentSlide] per CONTENT
/// beat, in order. Prep / doorway / after beats are SKIPPED (they're the host's
/// own setup + send-off, never the room's). Each slide carries the beat's hue
/// (the kind accent) and a kid-readable line; the teacher's say/cue script is
/// deliberately left behind.
///
/// The index of a slide here is NOT the index of its beat in `script.beats`
/// (prep/doorway/after are dropped) — see `roomSlideIndexForBeat` for the map a
/// caster uses to open the deck at the current beat.
List<PresentSlide> sessionRoomSlides(SessionScript script) {
  final slides = <PresentSlide>[];
  for (final beat in script.beats) {
    if (!_isRoomBeat(beat.kind)) continue;
    final subtitle = _roomSubtitle(beat);
    slides.add(
      PresentSlide(
        eyebrow: _roomEyebrow(beat),
        title: beat.title,
        // Omit an empty subtitle entirely (PresentSlide treats null as "none").
        subtitle: (subtitle != null && subtitle.isNotEmpty) ? subtitle : null,
        emoji: _roomEmoji(beat.kind),
        accent: _accentForKind(beat.kind),
      ),
    );
  }
  return slides;
}

/// The room-deck slide index for the beat at [beatIndex] in `script.beats` — the
/// count of INCLUDED (content) beats BEFORE it, since prep/doorway/after are
/// dropped from the deck. Casting from beat N opens [sessionRoomSlides] at this
/// index so the room lands on the beat the host is on. Clamped to a valid slide.
///
/// A skipped beat (prep/doorway/after) maps to the slide that FOLLOWS it (the
/// next content beat), which is the sensible "where the room would be" landing.
int roomSlideIndexForBeat(SessionScript script, int beatIndex) {
  final beats = script.beats;
  if (beats.isEmpty) return 0;
  final clampedBeat = beatIndex.clamp(0, beats.length - 1);
  var slideIndex = 0;
  for (var i = 0; i < clampedBeat; i++) {
    if (_isRoomBeat(beats[i].kind)) slideIndex++;
  }
  // Clamp into the deck (the deck length = count of content beats); a deck with
  // zero content beats yields 0, harmless since presentSlides no-ops on empty.
  final deckLength = beats.where((b) => _isRoomBeat(b.kind)).length;
  if (deckLength == 0) return 0;
  return slideIndex.clamp(0, deckLength - 1);
}

// ── Which beats reach the room ────────────────────────────────────────────

/// Whether a beat of this [kind] belongs on the room screen. Prep (host setup),
/// doorway (the leaving send-off), and after (the host's own reset) are NOT for
/// the kids — everything else is a content beat the room should see.
bool _isRoomBeat(BeatKind kind) => switch (kind) {
  BeatKind.prep || BeatKind.doorway || BeatKind.after => false,
  _ => true,
};

// ── The kid-facing essence, by kind ───────────────────────────────────────

/// The kid-facing ESSENCE of a beat — the one line under the title on the TV.
/// NEVER a say/cue line or "Say this": those are the teacher's. The source per
/// kind:
///   • game     → "{game.name} — {game.prompt}" (or just the name if no prompt),
///                falling back to the first keyLine when the beat carries no game
///                (e.g. an outdoor-hunt PREP beat that only sets up the rounds).
///   • vocab    → the vocab cards joined " · " (the words for the wall).
///   • rules    → the call-and-response (e.g. "CLICK! / FREEZE! / ASK").
///   • closing  → the call-and-response (e.g. "PHOTOGRAPHERS → SEE").
///   • everything else (hook / reveal / cooldown / partner / frame / drawing)
///                → the FIRST keyLine, trimmed (the calm headline, kid-readable).
/// Returns null/empty when there's nothing clean to show; the caller omits it.
String? _roomSubtitle(SessionBeat beat) {
  switch (beat.kind) {
    case BeatKind.game:
      final game = beat.game;
      if (game != null) {
        final name = game.name.trim();
        final prompt = game.prompt?.trim();
        if (prompt != null && prompt.isNotEmpty) {
          return name.isEmpty ? prompt : '$name — $prompt';
        }
        if (name.isNotEmpty) return name;
      }
      // No game payload (a hunt prep beat) → the calm headline.
      return _firstKeyLine(beat);
    case BeatKind.vocab:
      final cards = beat.vocabCards
          .map((w) => w.trim())
          .where((w) => w.isNotEmpty)
          .toList();
      if (cards.isNotEmpty) return cards.join(' · ');
      return _firstKeyLine(beat);
    case BeatKind.rules:
    case BeatKind.closing:
      final cr = beat.callResponse?.trim();
      if (cr != null && cr.isNotEmpty) return cr;
      return _firstKeyLine(beat);
    // hook / reveal / cooldown / partner / frame / drawing — the first keyLine.
    // (prep/doorway/after never reach here: _isRoomBeat drops them upstream.)
    case BeatKind.hook:
    case BeatKind.reveal:
    case BeatKind.cooldown:
    case BeatKind.partner:
    case BeatKind.frame:
    case BeatKind.drawing:
    case BeatKind.prep:
    case BeatKind.doorway:
    case BeatKind.after:
      return _firstKeyLine(beat);
  }
}

/// The beat's first keyLine, trimmed — the calm, kid-facing headline (keyLines
/// are the host's at-a-glance lines, but the FIRST is consistently the framing
/// statement, never a stage cue). Null when the beat has none.
String? _firstKeyLine(SessionBeat beat) {
  for (final line in beat.keyLines) {
    final t = line.trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

/// The eyebrow — a short phase label. The beat's [SessionBeat.time] when it
/// looks like a clock range (`"0:08–0:15"`), else a friendly kind label (used
/// for the bookend-shaped `"prep"` / `"after"` strings, though those beats are
/// dropped from the room deck anyway).
String _roomEyebrow(SessionBeat beat) {
  final time = beat.time.trim();
  // A clock-shaped time carries its own meaning; show it. Otherwise fall back
  // to the friendly kind word so the eyebrow is never a raw "prep"/"after".
  if (_looksLikeClock(time)) return time;
  return _kindLabel(beat.kind);
}

/// True when the time string reads like a clock (`"0:00"` / `"0:08–0:15"`) — a
/// digit followed eventually by a colon. The bookend labels (`"prep"`/`"after"`)
/// return false so they resolve to a friendly kind word instead.
bool _looksLikeClock(String time) => RegExp(r'^\d+:').hasMatch(time);

/// A single kid-friendly glyph per beat kind — leads the slide. Decorative; the
/// title carries the meaning. Skipped kinds (prep/doorway/after) still get one
/// for completeness, but they never reach a slide.
String _roomEmoji(BeatKind kind) => switch (kind) {
  BeatKind.hook => '✨',
  BeatKind.reveal => '📸',
  BeatKind.rules => '✋',
  BeatKind.game => '🎯',
  BeatKind.cooldown => '🔍',
  BeatKind.partner => '🤝',
  BeatKind.frame => '🖼️',
  BeatKind.drawing => '✏️',
  BeatKind.vocab => '📝',
  BeatKind.closing => '🎬',
  BeatKind.prep => '📦',
  BeatKind.doorway => '🚪',
  BeatKind.after => '🌙',
};

// ── Shared kind mappings (room deck + presenter agree) ─────────────────────

/// One beat kind's accent — the SAME content-driven categorical colour the
/// presenter uses ([ActivityPalette], not a theme role) so a beat's hue is
/// consistent between the host's slide and the room deck. Mirrors
/// `session_run_screen._accentForKind`; kept here so the room-deck builder
/// doesn't depend on the presenter screen.
Color _accentForKind(BeatKind kind) => switch (kind) {
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

/// Short kind label for the eyebrow fallback (lowercase, the calm voice).
/// Mirrors `session_run_screen._kindLabel`.
String _kindLabel(BeatKind kind) => switch (kind) {
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
