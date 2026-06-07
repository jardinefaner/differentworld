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
@immutable
class RoomSkin {
  const RoomSkin({
    required this.id,
    required this.emoji,
    required this.name,
    required this.color,
  });

  final String id;
  final String emoji;
  final String name;
  final Color color;
}

/// The standing room themes. Programs rename / extend; the daily + weekly
/// mechanics are skin-agnostic.
const List<RoomSkin> kRoomSkins = [
  RoomSkin(id: 'space', emoji: '🚀', name: 'Space', color: Color(0xFF6B5B95)),
  RoomSkin(
      id: 'underwater', emoji: '🌊', name: 'Underwater', color: Color(0xFF4ABED9)),
  RoomSkin(id: 'urban', emoji: '🏙️', name: 'Urban', color: Color(0xFF607D8B)),
  RoomSkin(id: 'safari', emoji: '🦁', name: 'Safari', color: Color(0xFFE0A030)),
  RoomSkin(id: 'travel', emoji: '✈️', name: 'Travel', color: Color(0xFF4A90D9)),
  RoomSkin(id: 'forest', emoji: '🌲', name: 'Forest', color: Color(0xFF51A85C)),
  RoomSkin(id: 'arctic', emoji: '❄️', name: 'Arctic', color: Color(0xFF7FC8E8)),
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
