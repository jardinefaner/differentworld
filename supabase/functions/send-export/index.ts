// send-export Edge Function
//
// Body: { exportId: string, recipients: [{ email: string,
//          label?: string, guardianId?: string, memberId?: string,
//          kind?: 'guardian'|'member'|'external' }] }
//
// Verifies the caller has access to the export (RLS handles this),
// mints a long-lived signed URL for the file in Storage, and
// dispatches one email per recipient through Resend. On success it
// stamps `export_recipients` rows (one per address) with channel
// = 'email' and state = 'delivered' or 'failed' based on Resend's
// response.
//
// The function does NOT generate the file — that happens
// client-side, with bytes uploaded to `storage.objects` before this
// runs. We just route the existing artifact to inboxes.
//
// Required environment:
//   RESEND_API_KEY    — Resend account key
//   SEND_FROM_ADDRESS — "Different World <reports@yourdomain.com>"
//   PUBLIC_LINK_TTL_SECONDS — optional, defaults to 604800 (1 week)
//
// To deploy:
//   supabase functions deploy send-export --no-verify-jwt=false
//
// And configure the secrets:
//   supabase secrets set RESEND_API_KEY=... SEND_FROM_ADDRESS=...

// deno-lint-ignore-file no-explicit-any

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const SEND_FROM = Deno.env.get('SEND_FROM_ADDRESS') ??
  'Different World <reports@example.com>';
const LINK_TTL = parseInt(
  Deno.env.get('PUBLIC_LINK_TTL_SECONDS') ?? '604800',
  10,
);

// Fail loudly if the deploy is missing the API key. Without this
// guard, the function would fire every request through Resend with
// an empty Bearer token, get back a 4xx for each recipient, and
// return Resend's error text in the response body — leaking
// implementation details and masking the real cause (you forgot to
// run `supabase secrets set RESEND_API_KEY=...`).
function assertConfigured(): Response | null {
  if (!RESEND_API_KEY) {
    return json(500, {
      error:
        'send-export not configured: set RESEND_API_KEY via `supabase secrets set`',
    });
  }
  return null;
}

interface Recipient {
  email: string;
  label?: string;
  guardianId?: string;
  memberId?: string;
  kind?: 'guardian' | 'member' | 'external';
}

interface Body {
  exportId: string;
  recipients: Recipient[];
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders,
    });
  }
  if (req.method !== 'POST') {
    return json(405, { error: 'POST only' });
  }

  // Early-out if the deploy is missing required secrets — better
  // to surface a 500 with a clear error than to silently fail every
  // recipient and return Resend's response body to the caller.
  const configError = assertConfigured();
  if (configError) return configError;

  // The function runs with the caller's JWT — RLS will reject any
  // export they shouldn't see.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json(401, { error: 'no auth' });

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );

  // Explicit JWT-validity probe before doing real work. The function
  // is deployed with `verify_jwt: true`, but during a Supabase project
  // JWT-key rotation there's a window where the standby key hasn't
  // fully propagated and `verify_jwt` rejects opaquely. We do a
  // cheap `auth.getUser()` ourselves so we can return a STRUCTURED
  // 401 ({ code: 'JWT_INVALID' }) the client can react to — signing
  // the user out + prompting re-auth — instead of bubbling a generic
  // failure.
  //
  // This also catches the case where an old (pre-rotation) token is
  // still in the client and the OLD key has already been revoked —
  // those tokens fail signature verification + we tell the client to
  // re-auth.
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userData?.user) {
    return json(401, {
      error: 'auth invalid; please sign out and sign back in',
      code: 'JWT_INVALID',
      detail: userErr?.message ?? 'no user from token',
    });
  }

  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch (_) {
    return json(400, { error: 'invalid body' });
  }
  if (!body.exportId || !body.recipients?.length) {
    return json(400, { error: 'exportId + recipients required' });
  }

  // Look up the export. RLS gates this.
  const { data: exp, error: lookupErr } = await supabase
    .from('exports')
    .select('id, space_id, template_id, format, storage_path, subject_id')
    .eq('id', body.exportId)
    .single();
  if (lookupErr || !exp) {
    return json(404, { error: 'export not found' });
  }
  if (!exp.storage_path) {
    return json(400, { error: 'export has no stored file' });
  }

  // Mint one signed URL — every recipient gets the same long link.
  // The link itself is the auth (token in URL) so no per-recipient
  // signing is needed.
  const { data: signed, error: signErr } = await supabase.storage
    .from('exports')
    .createSignedUrl(exp.storage_path, LINK_TTL);
  if (signErr || !signed?.signedUrl) {
    return json(500, { error: 'could not sign url' });
  }
  const linkUrl = signed.signedUrl;

  // Optional human subject in the email (the subject_id ↔ name
  // lookup is one extra query so we can put a name in the subject
  // line; failure silently degrades to a generic subject).
  let kidName = '';
  if (exp.subject_id) {
    const { data: sub } = await supabase
      .from('subjects')
      .select('first_name, last_name')
      .eq('id', exp.subject_id)
      .single();
    if (sub) {
      kidName = `${sub.first_name ?? ''} ${sub.last_name ?? ''}`.trim();
    }
  }

  // Fan out to Resend, one POST per recipient. Resend supports
  // batch-send via a different endpoint; we keep it simple here.
  const results = [] as Array<{
    recipient: Recipient;
    ok: boolean;
    detail?: string;
  }>;
  for (const r of body.recipients) {
    try {
      const resp = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: SEND_FROM,
          to: r.email,
          subject: kidName
            ? `${kidName} — report from your child's program`
            : 'A report from your child\'s program',
          html: renderEmailHtml({
            kidName,
            linkUrl,
            templateId: exp.template_id,
          }),
        }),
      });
      results.push({
        recipient: r,
        ok: resp.ok,
        detail: resp.ok ? undefined : await resp.text(),
      });
    } catch (err) {
      results.push({
        recipient: r,
        ok: false,
        detail: String(err),
      });
    }
  }

  // Stamp recipient rows for the audit trail. We insert here from
  // the function rather than from the client because we want the
  // server-known state (delivered vs failed) authoritative.
  const now = new Date().toISOString();
  const recipientRows = results.map((r) => ({
    export_id: body.exportId,
    space_id: exp.space_id,
    kind: r.recipient.kind ?? 'external',
    guardian_id: r.recipient.guardianId ?? null,
    member_id: r.recipient.memberId ?? null,
    external_label: r.recipient.label ?? r.recipient.email,
    external_email: r.recipient.email,
    channel: 'email',
    state: r.ok ? 'delivered' : 'failed',
    state_detail: r.detail ?? null,
    sent_at: now,
    created_at: now,
  }));
  await supabase.from('export_recipients').insert(recipientRows);
  // Mark the export sent.
  await supabase
    .from('exports')
    .update({ status: 'sent', sent_at: now, updated_at: now })
    .eq('id', body.exportId);

  return json(200, { results });
});

function renderEmailHtml({
  kidName,
  linkUrl,
  templateId,
}: {
  kidName: string;
  linkUrl: string;
  templateId: string;
}): string {
  const heading = kidName
    ? `A report about ${escapeHtml(kidName)}`
    : 'A report from your child\'s program';
  const blurb = templateId === 'progress_report'
    ? "Your child's teacher has prepared a progress report. " +
      'Tap below to view it — the link is valid for the next week.'
    : 'A report has been shared with you. Tap below to view it.';
  return `<!doctype html><html><body style="font-family: -apple-system, sans-serif; max-width: 540px; margin: 0 auto; padding: 24px;">
<h2 style="margin: 0 0 12px;">${escapeHtml(heading)}</h2>
<p style="color: #333; line-height: 1.5;">${escapeHtml(blurb)}</p>
<p style="margin: 24px 0;">
  <a href="${escapeHtml(linkUrl)}" style="background: #4F46E5; color: white; padding: 12px 18px; border-radius: 8px; text-decoration: none; font-weight: 600;">View the report</a>
</p>
<p style="color: #666; font-size: 12px;">
  If the button doesn't work, paste this link in your browser:<br>
  <a href="${escapeHtml(linkUrl)}" style="color: #4F46E5; word-break: break-all;">${escapeHtml(linkUrl)}</a>
</p>
</body></html>`;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

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
