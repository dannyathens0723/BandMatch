-- Keep the existing message request RLS policies intact while preventing
-- duplicate pending requests for the same direct user-to-user pair.
-- Run after 006_member_public_profile_details.sql.

begin;

create unique index message_requests_one_pending_direct_user_pair
  on public.message_requests (sender_user_id, receiver_user_id)
  where status = 'pending'
    and sender_user_id is not null
    and receiver_user_id is not null
    and sender_group_id is null
    and receiver_group_id is null;

commit;
