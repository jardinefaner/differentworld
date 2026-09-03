import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart' show Value;

/// A whole pretend program, seeded into a throwaway database.
///
/// Role PREVIEW swaps capabilities but keeps your member id, so your room
/// assignments and data stay yours — which is why previewing as a counselor
/// often shows an empty room list (`seesAllClassrooms` is `isDirector`, so
/// it falls back to the rooms YOU are staffed to, and a director is usually
/// staffed to none).
///
/// A sandbox fixes that by making the membership real too. Inside it you ARE
/// Rosa the counselor, genuinely assigned to Sparrows, looking at children
/// who genuinely sit in it. The difference between the two is the difference
/// between "can this role reach their work" and "what does their Monday
/// look like".
///
/// **Nothing here can touch a real program.** The sandbox runs against an
/// in-memory database with no PowerSync connector attached, so these rows
/// have nowhere to sync TO. That is a structural guarantee, not a policy —
/// there is no code path from this data to the server, which is the only
/// version of this idea worth shipping.
const sandboxSpaceId = 'sandbox-space';

/// The pretend staff, one per role, each with real room assignments.
const sandboxStaff =
    <({String id, String name, String role, List<String> rooms})>[
      (id: 'sb-m1', name: 'Maya Okonkwo', role: 'director', rooms: []),
      (
        id: 'sb-m2',
        name: 'Priya Raman',
        role: 'lead_teacher',
        rooms: ['sb-g1'],
      ),
      (id: 'sb-m3', name: 'Rosa Delgado', role: 'teacher', rooms: ['sb-g1']),
      (id: 'sb-m4', name: 'Tom Field', role: 'specialist', rooms: ['sb-g2']),
      (id: 'sb-m5', name: 'Ash Berry', role: 'substitute', rooms: ['sb-g2']),
    ];

const _rooms = <({String id, String name, String age})>[
  (id: 'sb-g1', name: 'Sparrows', age: 'Ages 6–8'),
  (id: 'sb-g2', name: 'Herons', age: 'Ages 9–12'),
];

const _kids = <({String id, String first, String last, String room})>[
  (id: 'sb-s1', first: 'Amara', last: 'Okafor', room: 'sb-g1'),
  (id: 'sb-s2', first: 'Ben', last: 'Kaur', room: 'sb-g1'),
  (id: 'sb-s3', first: 'Chidi', last: 'Adeyemi', room: 'sb-g1'),
  (id: 'sb-s4', first: 'Dara', last: 'Mensah', room: 'sb-g1'),
  (id: 'sb-s5', first: 'Eli', last: 'Nakamura', room: 'sb-g1'),
  (id: 'sb-s6', first: 'Farah', last: 'Sultana', room: 'sb-g2'),
  (id: 'sb-s7', first: 'Grace', last: 'Thompson', room: 'sb-g2'),
  (id: 'sb-s8', first: 'Hana', last: 'Lindqvist', room: 'sb-g2'),
  (id: 'sb-s9', first: 'Idris', last: 'Bello', room: 'sb-g2'),
];

/// Fill a fresh database with the pretend program.
Future<void> seedSandbox(AppDatabase db, {required String nowIso}) async {
  await db
      .into(db.spaces)
      .insert(
        SpacesCompanion.insert(
          id: sandboxSpaceId,
          name: 'Sunny Days (sandbox)',
          createdAt: nowIso,
          updatedAt: nowIso,
          // Photo consent default ON, so the sandbox does not open with an
          // attention item that is really just an unanswered seed value.
          capabilities: '{"photo_default_consent":true}',
          settings: '{}',
        ),
      );

  for (final r in _rooms) {
    await db.groupsDao.create(
      id: r.id,
      spaceId: sandboxSpaceId,
      name: r.name,
      ageRange: r.age,
      // Real numbers so the ratio bar has something true to say.
      capabilitiesJson: '{"licensed_capacity":16,"ratio_children_per_adult":8}',
    );
  }

  for (final m in sandboxStaff) {
    await db
        .into(db.members)
        .insert(
          MembersCompanion.insert(
            id: m.id,
            displayName: m.name,
            role: m.role,
            createdAt: nowIso,
            updatedAt: nowIso,
            spaceId: const Value(sandboxSpaceId),
            capabilities: Capabilities(
              RoleBundles.defaultsFor(m.role),
            ).toJson(),
          ),
        );
    for (final g in m.rooms) {
      await db.groupMembersDao.assign(
        groupId: g,
        memberId: m.id,
        spaceId: sandboxSpaceId,
      );
    }
  }

  for (final k in _kids) {
    await db.subjectsDao.create(
      id: k.id,
      spaceId: sandboxSpaceId,
      groupId: k.room,
      firstName: k.first,
      lastName: k.last,
    );
  }
}
