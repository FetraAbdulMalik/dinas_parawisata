create table if not exists public.destination_reviews (
  id bigint generated always as identity primary key,
  destination_id bigint not null
    references public.destinations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  review text not null default '' check (char_length(review) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (destination_id, user_id)
);

alter table public.destination_reviews enable row level security;

drop policy if exists "Anyone reads destination reviews"
  on public.destination_reviews;
create policy "Anyone reads destination reviews"
  on public.destination_reviews for select to anon, authenticated
  using (true);

drop policy if exists "Users create own destination reviews"
  on public.destination_reviews;
create policy "Users create own destination reviews"
  on public.destination_reviews for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users update own destination reviews"
  on public.destination_reviews;
create policy "Users update own destination reviews"
  on public.destination_reviews for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users delete own destination reviews"
  on public.destination_reviews;
create policy "Users delete own destination reviews"
  on public.destination_reviews for delete to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.destination_reviews to anon, authenticated;
grant insert, update, delete on public.destination_reviews to authenticated;
grant usage, select on sequence public.destination_reviews_id_seq
  to authenticated;

create or replace view public.destination_rating_stats
with (security_invoker = true)
as
select
  destination_id,
  avg(rating)::numeric(3, 2) as average_rating,
  count(*)::bigint as review_count
from public.destination_reviews
group by destination_id;

grant select on public.destination_rating_stats to anon, authenticated;

notify pgrst, 'reload schema';
