-- Allow the Flutter app to load active master data before sign-in.
-- RLS remains enabled. This changes SELECT access only; write policies stay
-- restricted to authenticated administrators as defined in 003_rls_policies.sql.
-- Run after 003_rls_policies.sql.

begin;

alter policy areas_read_active on public.areas
  to anon, authenticated;

alter policy parts_read_active on public.parts
  to anon, authenticated;

alter policy genres_read_active on public.genres
  to anon, authenticated;

commit;
