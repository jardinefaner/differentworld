import 'package:differentworld/features/activity_runtime/activity_deck.dart';
import 'package:differentworld/features/games/cards/castable_card_games.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:flutter/material.dart';

/// One thing a card can tell you before you tap it.
@immutable
class CardSignal {
  const CardSignal(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// **What this activity needs, and what it is like** — read off the game
/// itself, never hand-typed.
///
/// Fifty cards, a substitute teacher, and four minutes before the room comes
/// back in: the question is not "what is this called", it is *can I run this,
/// right now, with what is in front of me*. The deck answered neither — every
/// card was a title and a tagline, so "Scattergories" and "Photo Studio"
/// looked equally runnable when one needs ninety seconds and a person who can
/// type and the other needs a camera.
///
/// **Everything here is DERIVED.** A hand-authored `needs:` field on fifty
/// cards is fifty things to keep true, and the first one to go stale teaches a
/// teacher to stop believing the rest — the `CaptureSpec` trap (CLAUDE.md, "a
/// documented type is not a working feature"). So a new game gets its chips
/// the moment it is registered, and a game that stops alternating stops
/// claiming to need teams, with nobody remembering to do either.
///
/// It is also deliberately INCOMPLETE. Only what a game actually declares
/// appears; a card with no chips is one the app knows nothing special about,
/// which is honest. Inventing "5-10 min" for forty games would read as signal
/// and be fiction.
List<CardSignal> signalsFor(String route) {
  final def = gameForRoute(route);
  final out = <CardSignal>[];
  // Ordered by what a person would be STOPPED by. What you must go and fetch
  // beats how the round feels, and the list is capped, so the first two lines
  // are the ones that survive a narrow tile.
  if (_cameraRoutes.contains(route)) {
    out.add(const CardSignal('camera', Icons.photo_camera_outlined));
  }
  if (def == null) return out;
  final Object game = def; // typed as Object so `is GridGame` promotes
  if (game is GridGame) {
    if (game.alternates) {
      out.add(CardSignal('${game.sides.length} teams', Icons.groups_outlined));
    }
    if (game.entryHint != null) {
      out.add(const CardSignal('someone types', Icons.keyboard_outlined));
    }
  }
  // A duration when the game knows one; otherwise the fact that the board
  // does something without being tapped.
  //
  // These are two different promises and the chip used to make one of them
  // for both. "On a clock" on Whack-a-Mole tells a teacher to expect a
  // countdown, and what the game has is a mole that moves on its own — the
  // chip was accurate about `ticks` and wrong about the room's experience.
  final secs = _secondsOf(def);
  if (secs != null) {
    out.add(CardSignal('${secs}s', Icons.timer_outlined));
  } else if (def.ticks) {
    out.add(const CardSignal('moves on its own', Icons.autorenew_rounded));
  }
  if (_rounds(def) case final n?) {
    out.add(CardSignal('$n rounds', Icons.repeat_rounded));
  }
  // Pictures, not words — the single most useful thing to know about a game
  // when the room in front of you cannot read yet.
  if (castableCardGames.any((g) => g.$1.id == def.id)) {
    out.add(const CardSignal('pictures', Icons.image_outlined));
  }
  return out;
}

/// The routes that only appear on a device with a camera — DERIVED, by asking
/// the deck for both of its shapes, so the chip says what the card needs
/// rather than the deck silently hiding it.
///
/// It was a hand-written one-element set, which is the one thing this file
/// says it does not do: a second camera activity would have joined the deck
/// and never acquired its chip.
final Set<String> _cameraRoutes = {
  for (final c in breakDeck(camera: true)) c.route,
}..removeAll({for (final c in breakDeck(camera: false)) c.route});

int? _secondsOf(GameDefinition<dynamic> def) {
  for (final s in def.settings) {
    if (s.id == secondsId && s is IntSetting) return s.initial;
  }
  return null;
}

int? _rounds(GameDefinition<dynamic> def) {
  for (final s in def.settings) {
    if (s.id == roundLengthId && s is IntSetting) return s.initial;
  }
  return null;
}
