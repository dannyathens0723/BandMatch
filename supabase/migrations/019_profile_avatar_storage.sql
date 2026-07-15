-- Basic profile avatar storage for signed-in users.
-- Creates/updates a public avatars bucket and restricts writes to each user's
-- own public.users id folder. Run after 018_my_page_profile_summary.sql.

begin;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists avatars_public_read on storage.objects;
create policy avatars_public_read on storage.objects
  for select to public
  using (bucket_id = 'avatars');

drop policy if exists avatars_insert_own_folder on storage.objects;
create policy avatars_insert_own_folder on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.current_user_id()::text
  );

drop policy if exists avatars_update_own_folder on storage.objects;
create policy avatars_update_own_folder on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.current_user_id()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.current_user_id()::text
  );

drop policy if exists avatars_delete_own_folder on storage.objects;
create policy avatars_delete_own_folder on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.current_user_id()::text
  );

create or replace function public.update_my_avatar_url(
  p_avatar_url text
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_avatar_url text := btrim(coalesce(p_avatar_url, ''));
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;
  if v_avatar_url = ''
    or char_length(v_avatar_url) > 2000
    or position('/avatars/' || v_user_id::text || '/' in v_avatar_url) = 0 then
    raise exception 'invalid avatar url';
  end if;

  update public.users
  set avatar_url = v_avatar_url
  where id = v_user_id
    and account_status = 'active';

  if not found then
    raise exception 'active profile is required';
  end if;

  return v_avatar_url;
end;
$$;

revoke all on function public.update_my_avatar_url(text) from public, anon;
grant execute on function public.update_my_avatar_url(text) to authenticated;

notify pgrst, 'reload schema';

commit;
