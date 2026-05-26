// voice-token Edge Function
//
// Mints a SHORT-LIVED Deepgram token (≤30s by default) for a signed-in
// user. The master Deepgram key stays here in the function's secrets;
// the client never sees it. The token returned is scoped to a single
// streaming session and is worthless after expiry — leaked tokens
// have a 30-second blast radius instead of "drain the bank account."
//
// Body: {} (auth carried in the Authorization header)
// Response 200: { access_token: string, expires_in: number }
//
// Required environment (set via `supabase secrets set`):
//   DEEPGRAM_API_KEY    — the master Deepgram project key
//
// To deploy:
//   supabase functions deploy voice-token
//
// And configure the secret:
//   supabase secrets set DEEPGRAM_API_KEY=<your-master-key>
//
// Implements the broker pattern described in docs/SECRETS.md
// "Deepgram broker (streaming WebSocket)".

// deno-lint-ignore-file no-explicit-any

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const DEEPGRAM_API_KEY = Deno.env.get('DEEPGRAM_API_KEY') ?? '';

// 30 seconds — long enough for the client to open the WS connection
// + handshake. The token's lifetime is the entire scope of harm if
// it leaks; smaller is better. Deepgram caps at 30s for /v1/auth/grant.
const TTL_SECONDS = 30;

function assertConfigured(): Response | null {
  if (!DEEPGRAM_API_KEY) {
    return json(500, {
      error:
        'voice-token not configured: set DEEPGRAM_API_KEY via `supabase secrets set`',
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

  // The function runs with the caller's JWT — only authenticated
  // users can mint tokens. Anonymous callers get rejected here, so
  // a leaked /voice-token URL alone gives nothing without a user
  // session.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json(401, { error: 'no auth' });

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );

  // Explicit JWT-validity probe — same pattern as send-export.
  // Surfaces a structured 401 the client can react to (sign out +
  // re-auth) instead of an opaque generic failure during a Supabase
  // JWT-key rotation window.
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userData?.user) {
    return json(401, {
      error: 'auth invalid; please sign out and sign back in',
      code: 'JWT_INVALID',
      detail: userErr?.message ?? 'no user from token',
    });
  }

  // Future hook: gate on per-user voice quota here (e.g. N seconds
  // per day). Read the user's space + count today's voice sessions,
  // reject if over the cap. Skipped in v1 because vendor-side spending
  // cap on the master key bounds the total exposure anyway.

  // Ask Deepgram for a temp token. The master key is the
  // Authorization header here, scoped to this single HTTPS call —
  // never sent to the client.
  let dgResp: Response;
  try {
    dgResp = await fetch('https://api.deepgram.com/v1/auth/grant', {
      method: 'POST',
      headers: {
        Authorization: `Token ${DEEPGRAM_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ ttl_seconds: TTL_SECONDS }),
    });
  } catch (err) {
    return json(502, {
      error: 'could not reach Deepgram',
      detail: String(err),
    });
  }

  if (!dgResp.ok) {
    const text = await dgResp.text().catch(() => '');
    return json(dgResp.status, {
      error: 'Deepgram rejected the grant request',
      detail: text,
    });
  }

  const body = await dgResp.json().catch(() => null) as
    | { access_token?: string; expires_in?: number }
    | null;
  const accessToken = body?.access_token ?? '';
  const expiresIn = body?.expires_in ?? TTL_SECONDS;
  if (!accessToken) {
    return json(502, { error: 'Deepgram grant returned no token' });
  }

  return json(200, {
    access_token: accessToken,
    expires_in: expiresIn,
  });
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, body: any): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}
