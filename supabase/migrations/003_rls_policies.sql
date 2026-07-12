-- BandMatch production RLS policies
-- Run after 001_initial_schema.sql and 002_seed_master_data.sql.
-- No table is left with RLS disabled.

begin;

alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.areas enable row level security;
alter table public.parts enable row level security;
alter table public.genres enable row level security;
alter table public.user_purposes enable row level security;
alter table public.user_parts enable row level security;
alter table public.user_genres enable row level security;
alter table public.user_target_parts enable row level security;
alter table public.user_recruiting_parts enable row level security;
alter table public.user_areas enable row level security;
alter table public.group_genres enable row level security;
alter table public.group_target_parts enable row level security;
alter table public.group_recruiting_parts enable row level security;
alter table public.group_members enable row level security;
alter table public.media_portfolios enable row level security;
alter table public.message_requests enable row level security;
alter table public.message_rooms enable row level security;
alter table public.room_participants enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;
alter table public.reviews enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.notifications enable row level security;
alter table public.legal_documents enable row level security;
alter table public.user_consents enable row level security;
alter table public.invitations enable row level security;
alter table public.admin_users enable row level security;
alter table public.admin_actions enable row level security;
alter table public.ads enable row level security;
alter table public.waitlist enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payment_history enable row level security;

-- Master data: active selections can be read by a logged-in user.
create policy areas_read_active on public.areas for select to authenticated using (is_active);
create policy parts_read_active on public.parts for select to authenticated using (is_active);
create policy genres_read_active on public.genres for select to authenticated using (is_active);
create policy master_data_admin_manage_areas on public.areas for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy master_data_admin_manage_parts on public.parts for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy master_data_admin_manage_genres on public.genres for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- users is private. Search/profile UI must query user_public_profiles, not users.
create policy users_select_self on public.users for select to authenticated using (id = public.current_user_id());
create policy users_insert_self on public.users for insert to authenticated
  with check (auth_uid = auth.uid() and account_status = 'active' and withdrawn_at is null
    and premium_boost = 1.00 and not phone_verified);
-- These two policies preserve phone verification state and prevent user-side account-status changes.
create policy users_update_self_unverified on public.users for update to authenticated
  using (id = public.current_user_id() and account_status = 'active' and not phone_verified)
  with check (id = public.current_user_id() and auth_uid = auth.uid() and account_status = 'active'
    and withdrawn_at is null and premium_boost = 1.00 and not phone_verified);
create policy users_update_self_verified on public.users for update to authenticated
  using (id = public.current_user_id() and account_status = 'active' and phone_verified)
  with check (id = public.current_user_id() and auth_uid = auth.uid() and account_status = 'active'
    and withdrawn_at is null and premium_boost = 1.00 and phone_verified);
create policy users_admin_manage on public.users for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Public group fields are safe to render on search/detail screens; suspended groups are hidden.
create policy groups_read_active_or_manage on public.groups for select to authenticated
  using (account_status = 'active' or created_by = public.current_user_id() or public.is_group_admin(id) or public.is_admin());
create policy groups_insert_creator on public.groups for insert to authenticated
  with check (created_by = public.current_user_id() and account_status = 'active' and premium_boost = 1.00);
create policy groups_update_admin on public.groups for update to authenticated
  using (public.is_group_admin(id))
  with check (public.is_group_admin(id) and account_status = 'active' and premium_boost = 1.00);
create policy groups_admin_manage on public.groups for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Profile selection join tables. Own rows are editable; active, non-blocked profiles are readable.
create policy user_purposes_read on public.user_purposes for select to authenticated
  using (user_id = public.current_user_id() or public.is_public_profile_visible(user_id));
create policy user_purposes_write on public.user_purposes for all to authenticated
  using (user_id = public.current_user_id()) with check (user_id = public.current_user_id());
create policy user_parts_read on public.user_parts for select to authenticated
  using (user_id = public.current_user_id() or public.is_public_profile_visible(user_id));
create policy user_parts_write on public.user_parts for all to authenticated
  using (user_id = public.current_user_id()) with check (user_id = public.current_user_id());
create policy user_genres_read on public.user_genres for select to authenticated
  using (user_id = public.current_user_id() or public.is_public_profile_visible(user_id));
create policy user_genres_write on public.user_genres for all to authenticated
  using (user_id = public.current_user_id()) with check (user_id = public.current_user_id());
create policy user_target_parts_read on public.user_target_parts for select to authenticated
  using (user_id = public.current_user_id() or public.is_public_profile_visible(user_id));
create policy user_target_parts_write on public.user_target_parts for all to authenticated
  using (user_id = public.current_user_id()) with check (user_id = public.current_user_id());
create policy user_recruiting_parts_read on public.user_recruiting_parts for select to authenticated
  using (user_id = public.current_user_id() or public.is_public_profile_visible(user_id));
create policy user_recruiting_parts_write on public.user_recruiting_parts for all to authenticated
  using (user_id = public.current_user_id()) with check (user_id = public.current_user_id());
-- City/station are sensitive: only the owner reads user_areas directly. Use user_public_areas for display.
create policy user_areas_read_self on public.user_areas for select to authenticated using (user_id = public.current_user_id());
create policy user_areas_write_self on public.user_areas for all to authenticated
  using (user_id = public.current_user_id()) with check (user_id = public.current_user_id());

-- Group profile selections and membership.
create policy group_genres_read on public.group_genres for select to authenticated
  using (exists (select 1 from public.groups g where g.id = group_id and g.account_status = 'active') or public.is_group_admin(group_id));
create policy group_genres_write on public.group_genres for all to authenticated
  using (public.is_group_admin(group_id)) with check (public.is_group_admin(group_id));
create policy group_target_parts_read on public.group_target_parts for select to authenticated
  using (exists (select 1 from public.groups g where g.id = group_id and g.account_status = 'active') or public.is_group_admin(group_id));
create policy group_target_parts_write on public.group_target_parts for all to authenticated
  using (public.is_group_admin(group_id)) with check (public.is_group_admin(group_id));
create policy group_recruiting_parts_read on public.group_recruiting_parts for select to authenticated
  using (exists (select 1 from public.groups g where g.id = group_id and g.account_status = 'active') or public.is_group_admin(group_id));
create policy group_recruiting_parts_write on public.group_recruiting_parts for all to authenticated
  using (public.is_group_admin(group_id)) with check (public.is_group_admin(group_id));
create policy group_members_read on public.group_members for select to authenticated
  using (exists (select 1 from public.groups g where g.id = group_id and g.account_status = 'active') or public.is_group_admin(group_id));
-- A creator may add only themselves as the first admin before is_group_admin() can return true.
create policy group_members_insert_admin on public.group_members for insert to authenticated
  with check (public.is_group_admin(group_id)
    or public.can_initialize_group_member(group_id, user_id, role));
create policy group_members_update_admin on public.group_members for update to authenticated
  using (public.is_group_admin(group_id)) with check (public.is_group_admin(group_id));
create policy group_members_delete_member_or_admin on public.group_members for delete to authenticated
  using ((user_id = public.current_user_id() and role = 'member') or public.is_group_admin(group_id));

-- Media is public only when explicitly public and owned by an active profile/group.
create policy media_read_public_or_owner on public.media_portfolios for select to authenticated
  using (
    (is_public and user_id is not null and public.is_public_profile_visible(user_id))
    or (is_public and group_id is not null and exists (
      select 1 from public.groups g where g.id = group_id and g.account_status = 'active'
    ))
    or user_id = public.current_user_id()
    or (group_id is not null and public.is_group_admin(group_id))
  );
create policy media_insert_owner on public.media_portfolios for insert to authenticated
  with check (user_id = public.current_user_id() or (group_id is not null and public.is_group_admin(group_id)));
create policy media_update_owner on public.media_portfolios for update to authenticated
  using (user_id = public.current_user_id() or (group_id is not null and public.is_group_admin(group_id)))
  with check (user_id = public.current_user_id() or (group_id is not null and public.is_group_admin(group_id)));
create policy media_delete_owner on public.media_portfolios for delete to authenticated
  using (user_id = public.current_user_id() or (group_id is not null and public.is_group_admin(group_id)));

-- Blocks are deliberately private. They also hide profiles/media through the helper functions above.
create policy blocks_select_self on public.blocks for select to authenticated using (blocker_id = public.current_user_id());
create policy blocks_insert_self on public.blocks for insert to authenticated with check (blocker_id = public.current_user_id());
create policy blocks_delete_self on public.blocks for delete to authenticated using (blocker_id = public.current_user_id());

-- Requests are visible only to their sender/recipient party or an operator.
create policy requests_select_party on public.message_requests for select to authenticated
  using (public.can_act_for_party(sender_user_id, sender_group_id)
      or public.can_act_for_party(receiver_user_id, receiver_group_id)
      or public.is_admin());
create policy requests_insert_sender on public.message_requests for insert to authenticated
  with check (
    status = 'pending'
    and public.can_act_for_party(sender_user_id, sender_group_id)
    and public.is_party_active(sender_user_id, sender_group_id)
    and public.is_party_active(receiver_user_id, receiver_group_id)
    and (receiver_user_id is null or not public.has_block_relationship(public.current_user_id(), receiver_user_id))
  );
-- Rejection is a direct update. Acceptance must use accept_message_request(uuid) so room creation is atomic.
create policy requests_reject_recipient on public.message_requests for update to authenticated
  using (status = 'pending' and public.can_act_for_party(receiver_user_id, receiver_group_id))
  with check (status = 'rejected' and public.can_act_for_party(receiver_user_id, receiver_group_id)
    and responded_by = public.current_user_id());
create policy requests_admin_manage on public.message_requests for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- The acceptance RPC is the only client path that inserts rooms/participants.
create policy rooms_select_participant on public.message_rooms for select to authenticated
  using (public.is_room_participant(id) or public.is_admin());
create policy rooms_admin_manage on public.message_rooms for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy room_participants_select_participant on public.room_participants for select to authenticated
  using (public.is_room_participant(room_id) or public.is_admin());
create policy room_participants_admin_manage on public.room_participants for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy messages_select_participant on public.messages for select to authenticated
  using (public.is_room_participant(room_id) or public.is_admin());
create policy messages_insert_participant on public.messages for insert to authenticated
  with check (
    public.is_room_participant(room_id)
    and sender_user_id = public.current_user_id()
    and (acting_group_id is null or public.is_room_group_party(room_id, acting_group_id))
  );
create policy messages_admin_manage on public.messages for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- P1 records reads but never exposes them to the other participant.
create policy message_reads_select_self on public.message_reads for select to authenticated
  using (user_id = public.current_user_id() or public.is_admin());
create policy message_reads_insert_self on public.message_reads for insert to authenticated
  with check (user_id = public.current_user_id() and exists (
    select 1 from public.messages m where m.id = message_id and public.is_room_participant(m.room_id)
  ));
create policy message_reads_update_self on public.message_reads for update to authenticated
  using (user_id = public.current_user_id()) with check (user_id = public.current_user_id());
create policy message_reads_admin_manage on public.message_reads for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Reviews are allowed only for the two accepted parties in the room. Hidden reviews are private.
create policy reviews_select_published_or_party on public.reviews for select to authenticated
  using (is_published
      or public.can_act_for_party(reviewer_user_id, reviewer_group_id)
      or public.can_act_for_party(reviewee_user_id, reviewee_group_id)
      or public.is_admin());
create policy reviews_insert_valid_party on public.reviews for insert to authenticated
  with check (
    not is_published
    and public.can_act_for_party(reviewer_user_id, reviewer_group_id)
    and public.is_room_participant(room_id)
    and public.is_valid_review_parties(room_id, reviewer_user_id, reviewer_group_id, reviewee_user_id, reviewee_group_id)
  );
create policy reviews_admin_manage on public.reviews for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Safety and support data.
create policy reports_select_reporter_or_admin on public.reports for select to authenticated
  using (reporter_id = public.current_user_id() or public.is_admin());
create policy reports_insert_reporter on public.reports for insert to authenticated
  with check (reporter_id = public.current_user_id() and status = 'open');
create policy reports_admin_manage on public.reports for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy notifications_select_self on public.notifications for select to authenticated
  using (user_id = public.current_user_id() or public.is_admin());
create policy notifications_update_self on public.notifications for update to authenticated
  using (user_id = public.current_user_id()) with check (user_id = public.current_user_id());
create policy notifications_admin_manage on public.notifications for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy legal_documents_read_published on public.legal_documents for select to authenticated using (is_published);
create policy legal_documents_admin_manage on public.legal_documents for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy consents_select_self on public.user_consents for select to authenticated using (user_id = public.current_user_id() or public.is_admin());
create policy consents_insert_self on public.user_consents for insert to authenticated with check (user_id = public.current_user_id());
create policy consents_admin_manage on public.user_consents for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Invitation codes are redeemed only through redeem_invitation(text), so another user's codes stay private.
create policy invitations_select_inviter_or_admin on public.invitations for select to authenticated
  using (inviter_id = public.current_user_id() or public.is_admin());
create policy invitations_insert_inviter on public.invitations for insert to authenticated
  with check (inviter_id = public.current_user_id());
create policy invitations_delete_inviter on public.invitations for delete to authenticated
  using (inviter_id = public.current_user_id() and status = 'sent');
create policy invitations_admin_manage on public.invitations for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- admin_users is intentionally separate from users. Bootstrap the first admin in SQL Editor.
create policy admin_users_select_self on public.admin_users for select to authenticated using (auth_uid = auth.uid());
create policy admin_users_admin_manage on public.admin_users for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_actions_select_admin on public.admin_actions for select to authenticated using (public.is_admin());
create policy admin_actions_insert_admin on public.admin_actions for insert to authenticated
  with check (public.is_admin() and admin_id in (
    select id from public.admin_users where auth_uid = auth.uid() and is_active
  ));

-- Search ads are public to signed-in users only while active and within their configured schedule.
create policy ads_read_active on public.ads for select to authenticated
  using (is_active and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at >= now()));
create policy ads_admin_manage on public.ads for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- P0 waitlist: insert only; email addresses are not enumerable. Supports unauthenticated landing pages.
create policy waitlist_insert_public on public.waitlist for insert to anon, authenticated
  with check (char_length(email) between 3 and 320);
create policy waitlist_admin_manage on public.waitlist for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Phase 2 payment data remains private and is written by trusted billing/webhook code only.
create policy subscriptions_select_self_or_admin on public.subscriptions for select to authenticated
  using (user_id = public.current_user_id() or public.is_admin());
create policy subscriptions_admin_manage on public.subscriptions for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy payment_history_select_self_or_admin on public.payment_history for select to authenticated
  using (user_id = public.current_user_id() or public.is_admin());
create policy payment_history_admin_manage on public.payment_history for all to authenticated using (public.is_admin()) with check (public.is_admin());

commit;
