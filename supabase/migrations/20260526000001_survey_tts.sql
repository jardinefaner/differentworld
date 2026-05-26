-- Different World — Wave 120
-- Server-side TTS cache for survey question narration.
--
-- The math: survey questions are SHARED content. Every kid in the
-- program walks the same template. Without a server-side cache,
-- each (voice, question) pair would be regenerated per device,
-- multiplying Deepgram API calls by the number of kids × devices.
-- Caching the rendered audio in Supabase Storage means each
-- (voice, question) is generated exactly once across the entire
-- program — usually by the first kid to pick that voice. Every
-- subsequent kid hits the cache.
--
-- Architecture:
--   Bucket  tts-cache   PUBLIC read (audio is non-PII; the survey
--                       question text already ships in the app
--                       bundle), service-role write only via the
--                       Edge Function `tts-generate`.
--
--   Path    {voice_id}/{question_id}.mp3
--           e.g. aura-2-thalia-en/q_basecamp_2025_26_q3.mp3
--
-- The Edge Function checks for the file before calling Deepgram;
-- a cache hit returns the signed URL immediately.
--
-- Plus: track the kid's chosen voice per (subject, template) so a
-- second session restores the same reader without re-prompting.

-- 1. The TTS-cache bucket. Public read because the rendered audio
--    is shared content with no PII (and the underlying question
--    text is already in the client bundle); making it public
--    lets the audio player fetch directly without a signed-URL
--    round trip. Service role (used by the Edge Function) is the
--    only writer.
insert into storage.buckets (id, name, public)
values ('tts-cache', 'tts-cache', true)
on conflict (id) do update set public = true;

-- 2. RLS: authenticated users can read (redundant with public=true
--    but defensive); only service-role can insert/update/delete.
do $$
begin
  -- public read is via Storage's own bucket.public flag; no policy
  -- needed for SELECT. But we WANT to deny INSERT/UPDATE/DELETE
  -- from anyone but service-role, which is the default when no
  -- policy exists — RLS denies by default. So no policy creates
  -- the right state: read is open, write is closed.
  null;
end $$;

-- 3. Track the kid's chosen voice per (subject, template). When the
--    kid picks "Thalia" on first question, that's saved here so the
--    next time they open this same survey template, the picker is
--    skipped and Thalia auto-loads.
alter table public.survey_responses
  add column if not exists voice_id text;

-- No index — the column is read-by-row alongside the rest of the
-- response (existing PK lookup covers it).
