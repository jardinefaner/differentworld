// Unit tests for the pure authorization decision in sign-photo.
//   deno test supabase/functions/sign-photo/sign-photo.test.ts
//
// These pin the security contract without a live Supabase: a fake
// PhotoAccessDb supplies the three lookups, so we assert the DECISION
// (who may read which path) in isolation.

import {
  assert,
  assertFalse,
} from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { authorizePhotoAccess, type PhotoAccessDb } from './index.ts';

// A fake world: space 'spaceA' with member 'staffA'; guardian 'guardian1'
// guards subject 'childX'; guardian 'guardian2' guards subject 'childY'.
// One attachment object lives at an `attachment/`-path but is tagged to
// childX (the photo childX took, stored under an attachment key).
function fakeDb(): PhotoAccessDb {
  const members = new Set(['staffA::spaceA']); // userId::spaceId
  const guardianSubjects: Record<string, Set<string>> = {
    guardian1: new Set(['childX']),
    guardian2: new Set(['childY']),
  };
  const attachmentTags: Record<string, string[]> = {
    'spaceA/attachment/att-1/u.jpg': ['childX'],
  };
  return {
    isSpaceMember: (uid, spaceId) =>
      Promise.resolve(members.has(`${uid}::${spaceId}`)),
    guardsAnySubject: (uid, subjectIds) => {
      const guarded = guardianSubjects[uid];
      if (!guarded) return Promise.resolve(false);
      return Promise.resolve(subjectIds.some((s) => guarded.has(s)));
    },
    taggedSubjectsForPath: (p) => Promise.resolve(attachmentTags[p] ?? []),
  };
}

Deno.test('staff member of the space may read any object in it', async () => {
  assert(
    await authorizePhotoAccess('spaceA/subject/childY/u.jpg', 'staffA', fakeDb()),
  );
});

Deno.test('staff of a DIFFERENT space is refused', async () => {
  assertFalse(
    await authorizePhotoAccess('spaceB/subject/childX/u.jpg', 'staffA', fakeDb()),
  );
});

Deno.test('guardian may read their own child (subject-pathed avatar)', async () => {
  assert(
    await authorizePhotoAccess(
      'spaceA/subject/childX/u.jpg',
      'guardian1',
      fakeDb(),
    ),
  );
});

Deno.test('guardian may read their child via an attachment-pathed object', async () => {
  assert(
    await authorizePhotoAccess(
      'spaceA/attachment/att-1/u.jpg',
      'guardian1',
      fakeDb(),
    ),
  );
});

// THE headline acceptance case: a guardian (or any non-staff) is refused a
// FOREIGN child's photo path.
Deno.test('guardian is REFUSED another family’s child', async () => {
  assertFalse(
    await authorizePhotoAccess(
      'spaceA/subject/childX/u.jpg',
      'guardian2', // guards childY, not childX
      fakeDb(),
    ),
  );
});

Deno.test('guardian is refused a foreign child via attachment path too', async () => {
  assertFalse(
    await authorizePhotoAccess(
      'spaceA/attachment/att-1/u.jpg', // tagged to childX
      'guardian2', // guards childY
      fakeDb(),
    ),
  );
});

Deno.test('a complete stranger (no member, no guardian) is refused', async () => {
  assertFalse(
    await authorizePhotoAccess(
      'spaceA/subject/childX/u.jpg',
      'nobody',
      fakeDb(),
    ),
  );
});

Deno.test('a malformed path fails closed', async () => {
  assertFalse(await authorizePhotoAccess('garbage', 'staffA', fakeDb()));
  assertFalse(await authorizePhotoAccess('', 'staffA', fakeDb()));
});
