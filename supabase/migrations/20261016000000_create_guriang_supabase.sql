create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  last_sign_in_at timestamptz
);

create table if not exists public.user_activity_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  event text not null check (
    event in (
      'register',
      'login',
      'logout',
      'legacy_account_migrated',
      'profile_updated'
    )
  ),
  created_at timestamptz not null default now()
);

create table if not exists public.destinations (
  id bigint primary key,
  name text not null,
  category text not null,
  location text not null,
  description text not null,
  history text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  image_url text not null default '',
  image_asset text not null default '',
  audio_asset text not null default '',
  video_asset text not null default '',
  video_url text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.is_guriang_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and is_admin
  );
$$;

create or replace function public.create_guriang_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_guriang_user_created on auth.users;
create trigger on_guriang_user_created
  after insert on auth.users
  for each row execute procedure public.create_guriang_profile();

create or replace function public.protect_guriang_admin_flag()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_admin is distinct from old.is_admin
     and (select auth.uid()) is not null
     and not public.is_guriang_admin() then
    raise exception 'Only an administrator can change the admin role';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_guriang_profile_admin on public.profiles;
create trigger protect_guriang_profile_admin
  before update on public.profiles
  for each row execute procedure public.protect_guriang_admin_flag();

alter table public.profiles enable row level security;
alter table public.user_activity_logs enable row level security;
alter table public.destinations enable row level security;

drop policy if exists "Users read own profile" on public.profiles;
create policy "Users read own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id or (select public.is_guriang_admin()));

drop policy if exists "Users create own profile" on public.profiles;
create policy "Users create own profile"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id and not is_admin);

drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "Users delete own profile" on public.profiles;
create policy "Users delete own profile"
  on public.profiles for delete to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "Users read own activity" on public.user_activity_logs;
create policy "Users read own activity"
  on public.user_activity_logs for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.is_guriang_admin())
  );

drop policy if exists "Users create own activity" on public.user_activity_logs;
create policy "Users create own activity"
  on public.user_activity_logs for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and event in ('register', 'login', 'logout', 'legacy_account_migrated', 'profile_updated')
  );

drop policy if exists "Anyone reads destinations" on public.destinations;
create policy "Anyone reads destinations"
  on public.destinations for select to anon, authenticated
  using (true);

drop policy if exists "Admins insert destinations" on public.destinations;
create policy "Admins insert destinations"
  on public.destinations for insert to authenticated
  with check ((select public.is_guriang_admin()));

drop policy if exists "Admins update destinations" on public.destinations;
create policy "Admins update destinations"
  on public.destinations for update to authenticated
  using ((select public.is_guriang_admin()))
  with check ((select public.is_guriang_admin()));

drop policy if exists "Admins delete destinations" on public.destinations;
create policy "Admins delete destinations"
  on public.destinations for delete to authenticated
  using ((select public.is_guriang_admin()));

grant select on public.destinations to anon, authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert on public.user_activity_logs to authenticated;
grant insert, update, delete on public.destinations to authenticated;
grant usage, select on sequence public.user_activity_logs_id_seq to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'destination-images',
    'destination-images',
    true,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'destination-videos',
    'destination-videos',
    true,
    52428800,
    array['video/mp4']
  )
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public reads destination media" on storage.objects;
create policy "Public reads destination media"
  on storage.objects for select to anon, authenticated
  using (bucket_id in ('destination-images', 'destination-videos'));

drop policy if exists "Admins upload destination media" on storage.objects;
create policy "Admins upload destination media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('destination-images', 'destination-videos')
    and (select public.is_guriang_admin())
  );

drop policy if exists "Admins update destination media" on storage.objects;
create policy "Admins update destination media"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('destination-images', 'destination-videos')
    and (select public.is_guriang_admin())
  )
  with check (
    bucket_id in ('destination-images', 'destination-videos')
    and (select public.is_guriang_admin())
  );

drop policy if exists "Admins delete destination media" on storage.objects;
create policy "Admins delete destination media"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('destination-images', 'destination-videos')
    and (select public.is_guriang_admin())
  );
