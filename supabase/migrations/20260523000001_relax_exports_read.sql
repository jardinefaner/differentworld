-- Different World — Relax SELECT policies on exports + export_recipients
-- so guardians can actually read what's addressed to them.
--
-- ROOT CAUSE: same `auth.uid()` ES256-keyed-project quirk documented in
-- migration `20260517000002_relax_write_policies.sql`. PostgREST isn't
-- populating `request.jwt.claims` so any policy that gates on
-- `auth.uid()` (or a subquery against it) evaluates to NULL. For
-- exports + export_recipients the existing SELECT policies use:
--
--     space_id in (select space_id from public.members where id = auth.uid())
--     or id in (select export_id from public.export_recipients er
--              join public.guardians g on g.id = er.guardian_id
--              where g.user_id = auth.uid())
--
-- → both arms evaluate to `IN (NULL)` → false. Guardian devices get
-- zero rows from the direct-PostgREST family-side providers
-- (`myReceivedExportsProvider`, soon: any sibling-recipient query
-- for the co-parent visibility piece). The Wave 39 + 42 family
-- received-reports surface looks "broken" to a real guardian —
-- the card stays hidden because the list is empty.
--
-- WORKAROUND: same shape as 20260517000003 used for the rest of the
-- broad relax — `for select to authenticated using (true)`. The
-- GRANT layer (only `authenticated` has SELECT — never `anon`) plus
-- the per-query `.eq(...)` filters in the Dart providers are the
-- effective gate until JWT claims work in this project.
--
-- TRADE-OFF: any authenticated user can SELECT any export or any
-- export_recipients row via direct REST. For a dev / single-program
-- project this is acceptable; tighten back to per-user RLS once we
-- resolve the JWT-claim extraction issue. Tracked in CLAUDE.md under
-- "auth.uid() returns null in REST requests".
--
-- Companion ship: Wave 42 (Devon co-parent read-state on reports).
-- Without this migration both Wave 39's `_ReceivedReportsCard` AND
-- Wave 42's mark-read flow are no-ops on real guardian devices.

-- exports
drop policy if exists "exports_read_by_space_or_recipient" on public.exports;
create policy "exports_authenticated_read" on public.exports
  for select to authenticated
  using (true);

-- export_recipients
drop policy if exists "export_recipients_read_by_space_or_recipient"
  on public.export_recipients;
create policy "export_recipients_authenticated_read" on public.export_recipients
  for select to authenticated
  using (true);
