// sign-photo Edge Function
//
// Mints a short-lived signed URL for a person-photo ONLY after authorizing
// the caller server-side. This closes the ES256 read hole: the
// `person-photos` bucket's RLS read policy was effectively permissive for
// every signed-in user (the `auth.uid() is null` arm fires on this
// ES256-keyed project — see CLAUDE.md), so a client could mint a signed URL
// for ANY path it knew. We move signing here, behind an explicit
// authorization check, and lock the bucket read policy down (migration
// 20260622000002) so direct client createSignedUrl no longer works.
//
// Body: { path: "<space_id>/<entity>/<entityId>/<uuid>.jpg" }  (auth in the
//        Authorization header)
// Response 200: { signedUrl: string, expires_in: number }
//          401: not signed in / JWT invalid
//          403: signed in, but not authorized for this object
//          404: authorized, but the object couldn't be signed (missing)
//
// Authorization (see `authorizePhotoAccess`):
//   STAFF    — the caller is a member of the photo's space (the path's first
//              segment). `members.id == auth user id` on this project.
//   GUARDIAN — (a) a subject-pathed object (`subject/<id>`, e.g. an avatar)
//              whose subject the caller guards, OR (b) an attachment-pathed
//              object whose attachment row is tagged (subject_id /
//              captured_by_subject_id) to a subject the caller guards. Case
//              (b) is required because photos upload under varied entity
//              paths (`attachment/<id>`, `observation/<id>`, …), not always
//              `subject/<id>`.
//
// Required environment (auto-injected by Supabase; no secrets to set):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
//
// To deploy:  supabase functions deploy sign-photo
// Pattern: docs/SECRETS.md (mirrors voice-token / send-export).

// deno-lint-ignore-file no-explicit-any

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const BUCKET = 'person-photos';
const TTL_SECONDS = 60 * 60; // 1 hour — matches the old client TTL.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  // supabase-js auto-adds `apikey` on every functions.invoke; it must be in
  // the allow-list or web browsers reject the CORS preflight (the same fix
  // voice-token / tts-generate carry).
  'Access-Control-Allow-Headers':
    'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, body: any): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

// The lookups `authorizePhotoAccess` needs, injected so the decision is a
// PURE function that unit-tests without a live Supabase (see
// sign-photo.test.ts).
export interface PhotoAccessDb {
  // Is `userId` a member of `spaceId`? (members.id == auth uid on this project)
  isSpaceMember(userId: string, spaceId: string): Promise<boolean>;
  // Does `userId` (as a guardian) guard ANY of `subjectIds`?
  guardsAnySubject(userId: string, subjectIds: string[]): Promise<boolean>;
  // The subject ids tagged on the attachment row(s) owning this exact storage
  // object (subject_id + captured_by_subject_id). Empty if no such row.
  taggedSubjectsForPath(path: string): Promise<string[]>;
}

/// Returns true iff `userId` may read the object at `path`. Pure given `db`.
/// Fails CLOSED (returns false) on a malformed path — a broken path can't be
/// authorized, which denies (safe) rather than leaks.
export async function authorizePhotoAccess(
  path: string,
  userId: string,
  db: PhotoAccessDb,
): Promise<boolean> {
  const segs = path.split('/');
  if (segs.length < 3) return false;
  const spaceId = segs[0];
  const entity = segs[1];
  const entityId = segs[2];
  if (!spaceId || !entity || !entityId) return false;

  // STAFF: a member of the photo's space sees everything in that space
  // (matches the original space-scoped read intent).
  if (await db.isSpaceMember(userId, spaceId)) return true;

  // GUARDIAN, case (a): a subject-pathed object (avatar, or a photo uploaded
  // directly under the subject) — guard that subject.
  if (entity === 'subject' && (await db.guardsAnySubject(userId, [entityId]))) {
    return true;
  }

  // GUARDIAN, case (b): an attachment/observation/… -pathed object — resolve
  // the owning row's tagged subjects and guard any of them.
  const tagged = await db.taggedSubjectsForPath(path);
  if (tagged.length > 0 && (await db.guardsAnySubject(userId, tagged))) {
    return true;
  }

  return false;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') return json(405, { error: 'POST only' });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json(401, { error: 'no auth' });

  // 1) Validate the JWT → the caller's user id. getUser() validates the token
  // and returns the user even on ES256 (it doesn't depend on the RLS
  // auth.uid() GUC that's null on this project).
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return json(401, {
      error: 'auth invalid; please sign out and sign back in',
      code: 'JWT_INVALID',
      detail: userErr?.message ?? 'no user from token',
    });
  }
  const userId = userData.user.id;

  // 2) Parse + sanitize the requested path.
  const body = (await req.json().catch(() => null)) as { path?: string } | null;
  const path = (body?.path ?? '').trim();
  // Reject traversal / absolute / empty — a path must be a plain
  // bucket-relative object key.
  if (!path || path.startsWith('/') || path.includes('..')) {
    return json(400, { error: 'bad path' });
  }

  // 3) Authorize via the service role (bypasses RLS; this function is the
  // trusted gate). All queries hit public tables.
  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  const db: PhotoAccessDb = {
    isSpaceMember: async (uid, spaceId) => {
      const { data } = await admin
        .from('members')
        .select('id')
        .eq('id', uid)
        .eq('space_id', spaceId)
        .limit(1);
      return (data?.length ?? 0) > 0;
    },
    guardsAnySubject: async (uid, subjectIds) => {
      if (subjectIds.length === 0) return false;
      // The caller's guardian record(s) (a guardian is keyed by user_id).
      const { data: gs } = await admin
        .from('guardians')
        .select('id')
        .eq('user_id', uid);
      const guardianIds = (gs ?? []).map((g: any) => g.id);
      if (guardianIds.length === 0) return false;
      const { data } = await admin
        .from('subject_guardians')
        .select('subject_id')
        .in('guardian_id', guardianIds)
        .in('subject_id', subjectIds)
        .limit(1);
      return (data?.length ?? 0) > 0;
    },
    taggedSubjectsForPath: async (p) => {
      const { data } = await admin
        .from('attachments')
        .select('subject_id, captured_by_subject_id')
        .eq('url', p);
      const ids = new Set<string>();
      for (const a of data ?? []) {
        if (a.subject_id) ids.add(a.subject_id as string);
        if (a.captured_by_subject_id) {
          ids.add(a.captured_by_subject_id as string);
        }
      }
      return [...ids];
    },
  };

  let authorized = false;
  try {
    authorized = await authorizePhotoAccess(path, userId, db);
  } catch (err) {
    // A lookup failure denies (fail closed) rather than leaks.
    return json(500, { error: 'authorization check failed', detail: String(err) });
  }
  if (!authorized) return json(403, { error: 'not authorized for this photo' });

  // 4) Sign with the service role and return the URL.
  const { data: signed, error: signErr } = await admin.storage
    .from(BUCKET)
    .createSignedUrl(path, TTL_SECONDS);
  if (signErr || !signed?.signedUrl) {
    return json(404, {
      error: 'could not sign object',
      detail: signErr?.message ?? 'no url',
    });
  }
  return json(200, { signedUrl: signed.signedUrl, expires_in: TTL_SECONDS });
});
