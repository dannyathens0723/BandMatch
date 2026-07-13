-- Safe, authenticated detail projection for an individual member profile.
-- member_search_profiles already limits results to active, non-blocked users
-- other than the current user. This view adds only explicitly public fields.
-- Run after 005_public_member_search_view.sql.

begin;

create or replace view public.member_public_profile_details
with (security_invoker = false)
as
select
  m.*,
  u.favorite_artists,
  u.gear,
  u.activity_frequency,
  u.activity_days
from public.member_search_profiles m
join public.users u on u.id = m.id;

revoke all on public.member_public_profile_details from public, anon;
grant select on public.member_public_profile_details to authenticated;

commit;
