import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/activity_runtime/roles.dart';
import 'package:differentworld/features/entities/entity_match.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/prefs_bool_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Master switch for **live entities** (tap-anything + autotagging). Default
/// ON — the user asked for this behavior; the toggle is the escape hatch if
/// auto-detection ever over-matches. Mirrors `bento_everywhere_setting`.
class LiveEntitiesNotifier extends PrefsBoolNotifier {
  @override
  String get prefsKey => 'settings.live_entities';

  @override
  bool get defaultValue => true;
}

final liveEntitiesProvider = AsyncNotifierProvider<LiveEntitiesNotifier, bool>(
  LiveEntitiesNotifier.new,
);

/// Resolved ON state for a cheap sync read inside `build()`. Defaults to ON
/// even while the pref loads, so entities are live from the first frame.
bool liveEntitiesOn(WidgetRef ref) =>
    ref.watch(liveEntitiesProvider).value ?? true;

/// The on-device name → [EntityRef] index, built from the LOCAL roster the
/// viewer can already see. PII never leaves the device — this is just the
/// Drift streams the app already holds, reshaped for matching. Recomputes as
/// the streams arrive; [findEntityMatches] sorts longest-first at match time.
///
/// People are proper-noun gated, and a bare first name is indexed only when
/// it's unambiguous in the visible roster (two "Sofia"s → only the full names
/// link, never the wrong child). Verbs are intentionally excluded — words like
/// "share" / "build" are too common to light up in prose; they stay available
/// as structured `EntityLink`s only.
final entityIndexProvider = Provider<List<EntityMatchTerm>>((ref) {
  final terms = <EntityMatchTerm>[];

  // ── children ──
  final subjects =
      ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
  final subjectFirstCounts = <String, int>{};
  for (final s in subjects) {
    final fn = s.firstName.trim().toLowerCase();
    if (fn.isNotEmpty) {
      subjectFirstCounts[fn] = (subjectFirstCounts[fn] ?? 0) + 1;
    }
  }
  for (final s in subjects) {
    final first = s.firstName.trim();
    final full = [
      first,
      s.lastName.trim(),
    ].where((p) => p.isNotEmpty).join(' ');
    final ref0 = EntityRef(
      kind: EntityKind.subject,
      id: s.id,
      label: full.isEmpty ? first : full,
    );
    if (full.length >= 2) {
      terms.add(EntityMatchTerm(text: full, ref: ref0, properNounOnly: true));
    }
    if (first.length >= 2 &&
        first.toLowerCase() != full.toLowerCase() &&
        (subjectFirstCounts[first.toLowerCase()] ?? 0) == 1) {
      terms.add(EntityMatchTerm(text: first, ref: ref0, properNounOnly: true));
    }
  }

  // ── staff ──
  final members = ref.watch(membersInSpaceProvider).value ?? const <Member>[];
  final memberFirstCounts = <String, int>{};
  for (final m in members) {
    final t = m.displayName.trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (t.isNotEmpty) memberFirstCounts[t] = (memberFirstCounts[t] ?? 0) + 1;
  }
  for (final m in members) {
    final name = m.displayName.trim();
    if (name.length < 2) continue;
    final ref0 = EntityRef(kind: EntityKind.member, id: m.id, label: name);
    terms.add(EntityMatchTerm(text: name, ref: ref0, properNounOnly: true));
    final first = name.split(RegExp(r'\s+')).first;
    if (first.length >= 2 &&
        first.toLowerCase() != name.toLowerCase() &&
        (memberFirstCounts[first.toLowerCase()] ?? 0) == 1) {
      terms.add(EntityMatchTerm(text: first, ref: ref0, properNounOnly: true));
    }
  }

  // ── things (distinctive names; case-insensitive) ──
  void addThings<T>(
    List<T> xs,
    EntityKind kind,
    String Function(T) id,
    String Function(T) name,
  ) {
    for (final x in xs) {
      final n = name(x).trim();
      if (n.length >= 2) {
        terms.add(
          EntityMatchTerm(
            text: n,
            ref: EntityRef(kind: kind, id: id(x), label: n),
          ),
        );
      }
    }
  }

  addThings(
    ref.watch(groupsProvider).value ?? const <Group>[],
    EntityKind.group,
    (g) => g.id,
    (g) => g.name,
  );
  addThings(
    ref.watch(activitiesProvider).value ?? const <Activity>[],
    EntityKind.activity,
    (a) => a.id,
    (a) => a.name,
  );
  addThings(
    ref.watch(locationsProvider).value ?? const <Location>[],
    EntityKind.location,
    (l) => l.id,
    (l) => l.name,
  );
  addThings(
    ref.watch(vehiclesProvider).value ?? const <Vehicle>[],
    EntityKind.vehicle,
    (v) => v.id,
    (v) => v.name,
  );
  addThings(
    ref.watch(curriculumWorldsProvider).value ?? const <CurriculumWorld>[],
    EntityKind.world,
    (w) => w.id,
    (w) => w.name,
  );

  // ── roles (proper-noun gated: "the Builder role") ──
  for (final deck in roleDecks) {
    for (final c in deck.cards) {
      final n = c.name.trim();
      if (n.length >= 3) {
        terms.add(
          EntityMatchTerm(
            text: n,
            ref: EntityRef(kind: EntityKind.role, id: c.fingerprint, label: n),
            properNounOnly: true,
          ),
        );
      }
    }
  }

  // ── tools (the toolkit reference — distinctive names, proper-noun gated) ──
  for (final t in allToolkitTools) {
    final n = t.name.trim();
    if (n.length >= 3) {
      terms.add(
        EntityMatchTerm(
          text: n,
          ref: EntityRef(kind: EntityKind.tool, id: t.slug, label: n),
          properNounOnly: true,
        ),
      );
    }
  }

  // Verbs are intentionally EXCLUDED from the autotag index — words like
  // "share" / "build" are too common to light up in prose; they stay
  // available as structured `EntityLink`s only.

  return terms;
});
