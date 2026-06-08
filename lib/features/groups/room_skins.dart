import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:flutter/material.dart';

/// A **room skin** — a physical room's PERMANENT theme (docs/VISION.md
/// 2026-06-07 "two layers of skin"). The room sets a standing vibe (Space,
/// Underwater, Urban, Safari, Travel) for whoever's in it; the WEEKLY skin
/// (the curriculum world) sits on top and changes each week. Stored as a
/// `room_skin` string cap on the group (no migration — groups already carry
/// a capabilities jsonb).
///
/// Visually each skin is a **deep-field tinted ambience** (the LivingBackground
/// idiom — "color lives in the ambience, not the ink") rendered by
/// `RoomSkinBackground`: a [bgTop]→[bgBottom] gradient + a cheap signature
/// texture (stars, light shafts, a skyline). NOT a literal illustration — that
/// keeps it legible behind content, cheap to paint, and coherent with the
/// floating-glass chrome. [color] is the accent (chips, the weekly-world tint
/// sits separately on top).
@immutable
class RoomSkin {
  const RoomSkin({
    required this.id,
    required this.emoji,
    required this.name,
    required this.color,
    required this.bgTop,
    required this.bgBottom,
  });

  final String id;
  final String emoji;
  final String name;

  /// The accent (chips, labels). Distinct from the curriculum world hexes so
  /// the two layers never merge into one (the same-biome week collision).
  final Color color;

  /// The deep-field gradient — top (toward the light) → bottom (toward dark).
  final Color bgTop;
  final Color bgBottom;
}

/// The standing room themes. Programs rename / extend; the daily + weekly
/// mechanics are skin-agnostic. The `bgTop`/`bgBottom` are deliberately deep
/// (near-dark, tinted) so white content + glass chrome read over them.
const List<RoomSkin> kRoomSkins = [
  RoomSkin(
    id: 'space',
    emoji: '🚀',
    name: 'Space',
    color: Color(0xFF8A78C0),
    bgTop: Color(0xFF1A1730),
    bgBottom: Color(0xFF07060F),
  ),
  RoomSkin(
    id: 'underwater',
    emoji: '🌊',
    name: 'Underwater',
    color: Color(0xFF3FC8E2),
    bgTop: Color(0xFF0B3A4A),
    bgBottom: Color(0xFF05161F),
  ),
  RoomSkin(
    id: 'urban',
    emoji: '🏙️',
    name: 'Urban',
    color: Color(0xFF7E9AAB),
    bgTop: Color(0xFF222A30),
    bgBottom: Color(0xFF0C0F12),
  ),
  RoomSkin(
    id: 'safari',
    emoji: '🦁',
    name: 'Safari',
    color: Color(0xFFE0A030),
    bgTop: Color(0xFF3A2A12),
    bgBottom: Color(0xFF140E06),
  ),
  RoomSkin(
    id: 'travel',
    emoji: '✈️',
    name: 'Travel',
    color: Color(0xFF5AA0E0),
    bgTop: Color(0xFF12243A),
    bgBottom: Color(0xFF070D16),
  ),
  RoomSkin(
    id: 'forest',
    emoji: '🌲',
    name: 'Forest',
    color: Color(0xFF60BE6C),
    bgTop: Color(0xFF12301A),
    bgBottom: Color(0xFF06120A),
  ),
  RoomSkin(
    id: 'arctic',
    emoji: '❄️',
    name: 'Arctic',
    color: Color(0xFF9AD4EC),
    bgTop: Color(0xFF1A2E3A),
    bgBottom: Color(0xFF0A141C),
  ),
];

RoomSkin? roomSkinById(String? id) {
  if (id == null) return null;
  for (final s in kRoomSkins) {
    if (s.id == id) return s;
  }
  return null;
}

/// The room skin set on a group (null = none chosen).
RoomSkin? roomSkinForGroup(Group group) =>
    roomSkinById(group.caps.getString(GroupCaps.roomSkin));
