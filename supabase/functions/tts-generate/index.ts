// tts-generate Edge Function
//
// Server-side cache + generator for Deepgram Aura 2 TTS audio used
// to read survey questions aloud to kids. The Wave 84 voice-token
// function brokers STT tokens; this one brokers TTS GENERATION,
// because TTS doesn't have the same "short-lived token" model and
// because we want one-write-many-read caching across the program.
//
// Body:
//   {
//     voice: string,      // e.g. "aura-2-thalia-en"
//     text: string,       // the question text
//     cache_key: string   // stable id e.g. "basecamp_2025_26_q3"
//   }
//
// Response 200:
//   {
//     url: string,        // public URL to the cached mp3
//     cached: boolean,    // true = cache hit, false = freshly generated
//   }
//
// Flow:
//   1. Compute path: `{voice}/{cache_key}.mp3` in bucket `tts-cache`.
//   2. Probe the bucket — does it already exist? If yes, return the URL.
//   3. Otherwise call Deepgram /v1/speak with the master key, stream
//      the MP3 bytes, upload to Storage, return URL.
//
// Auth: requires a valid Supabase JWT (any authenticated user). The
// underlying audio is non-PII (it's a stock question being read in a
// stock voice), so we don't restrict by program — caching globally
// across the platform's tenants is by design.
//
// Required environment:
//   DEEPGRAM_API_KEY     — same master key the voice-token function uses
//   SUPABASE_URL         — provided by Supabase runtime
//   SUPABASE_SERVICE_ROLE_KEY — used to write to the bucket (not anon)
//
// To deploy:
//   supabase functions deploy tts-generate
//
// And configure the secret (already set if voice-token works):
//   supabase secrets set DEEPGRAM_API_KEY=<your-master-key>

// deno-lint-ignore-file no-explicit-any

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const DEEPGRAM_API_KEY = Deno.env.get('DEEPGRAM_API_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

// Whitelist of voices we'll generate audio for. Bounds the cache size
// (5 voices × N templates × M questions) and prevents an attacker from
// using us as a free Deepgram-TTS proxy by spamming arbitrary voice
// IDs. If we add a new voice to the cast, this list grows with it.
const ALLOWED_VOICES = new Set<string>([
  // English (Wave 120)
  'aura-2-thalia-en',
  'aura-2-hera-en',
  'aura-2-atlas-en',
  'aura-2-apollo-en',
  'aura-2-andromeda-en',
  // Spanish — Latin American (Wave 149).
  // Drift this list with `lib/features/voice/aura_voices.dart`.
  'aura-2-celeste-es',
  'aura-2-estrella-es',
  'aura-2-nestor-es',
  'aura-2-javier-es',
  'aura-2-sirio-es',
]);

const BUCKET = 'tts-cache';

// Cap on the question-text size we'll send to Deepgram. Surveys are
// short (a sentence or two per question); this stops abuse where
// someone crafts a 10K-word "question" to generate a long audiobook
// on our dime. 2000 chars ≈ 2 minutes of speech, more than enough.
const MAX_TEXT_LEN = 2000;

function assertConfigured(): Response | null {
  if (!DEEPGRAM_API_KEY) {
    return json(500, {
      error:
        'tts-generate not configured: set DEEPGRAM_API_KEY via `supabase secrets set`',
    });
  }
  if (!SUPABASE_SERVICE_ROLE_KEY) {
    return json(500, {
      error:
        'tts-generate not configured: SUPABASE_SERVICE_ROLE_KEY missing',
    });
  }
  return null;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json(405, { error: 'POST only' });
  }

  const configError = assertConfigured();
  if (configError) return configError;

  // Auth check: authenticated users only (same shape as voice-token).
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json(401, { error: 'no auth' });

  const userClient = createClient(
    SUPABASE_URL,
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

  // Parse + validate body.
  let body: { voice?: string; text?: string; cache_key?: string };
  try {
    body = await req.json();
  } catch (_) {
    return json(400, { error: 'invalid JSON body' });
  }
  const voice = (body.voice ?? '').trim();
  const text = (body.text ?? '').trim();
  const cacheKey = (body.cache_key ?? '').trim();

  if (!ALLOWED_VOICES.has(voice)) {
    return json(400, {
      error: 'voice not in whitelist',
      allowed: Array.from(ALLOWED_VOICES),
    });
  }
  if (!text || text.length > MAX_TEXT_LEN) {
    return json(400, {
      error: `text must be 1..${MAX_TEXT_LEN} chars`,
    });
  }
  if (!cacheKey || cacheKey.length > 200 ||
      !/^[a-zA-Z0-9_\-.]+$/.test(cacheKey)) {
    return json(400, {
      error: 'cache_key must be alphanumeric / dash / dot / underscore, ≤200',
    });
  }

  const path = `${voice}/${cacheKey}.mp3`;
  const publicUrl =
    `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${path}`;

  // Service client for writes to the bucket.
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // CACHE PROBE: does the file already exist? HEAD via the public
  // URL is fastest because the bucket is public-read; no signed-URL
  // dance required.
  try {
    const head = await fetch(publicUrl, { method: 'HEAD' });
    if (head.ok) {
      return json(200, { url: publicUrl, cached: true });
    }
  } catch (_) {
    // Network blip on the HEAD probe — fall through to generation.
  }

  // CACHE MISS: call Deepgram /v1/speak. Aura 2 supports both
  // streaming and one-shot modes; we use the one-shot REST call here
  // and stream the response as MP3 bytes.
  let dgResp: Response;
  try {
    dgResp = await fetch(
      `https://api.deepgram.com/v1/speak?model=${encodeURIComponent(voice)}&encoding=mp3`,
      {
        method: 'POST',
        headers: {
          Authorization: `Token ${DEEPGRAM_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text }),
      },
    );
  } catch (err) {
    return json(502, {
      error: 'could not reach Deepgram',
      detail: String(err),
    });
  }
  if (!dgResp.ok) {
    const errText = await dgResp.text().catch(() => '');
    return json(dgResp.status, {
      error: 'Deepgram rejected the speak request',
      detail: errText,
    });
  }

  const audioBytes = new Uint8Array(await dgResp.arrayBuffer());
  if (audioBytes.length === 0) {
    return json(502, { error: 'Deepgram returned empty audio' });
  }

  // UPLOAD. upsert: true so concurrent callers for the same (voice,
  // key) don't fight — both produce identical bytes anyway (TTS is
  // deterministic for a given text + voice + model version).
  const { error: uploadErr } = await admin.storage
    .from(BUCKET)
    .upload(path, audioBytes, {
      contentType: 'audio/mpeg',
      upsert: true,
    });

  if (uploadErr) {
    return json(500, {
      error: 'could not upload TTS audio to Storage',
      detail: uploadErr.message,
    });
  }

  return json(200, { url: publicUrl, cached: false });
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  // Wave 147: `apikey` is added automatically by the supabase-js
  // client on every functions.invoke() — without it in the
  // Access-Control-Allow-Headers list, browsers reject the preflight
  // and the call never reaches the function. That's the
  // "no audio on web" report. Mobile bypassed CORS entirely so it
  // worked there.
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
