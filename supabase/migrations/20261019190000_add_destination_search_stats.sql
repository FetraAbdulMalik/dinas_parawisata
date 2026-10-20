create table if not exists public.destination_search_stats (
  destination_id bigint primary key
    references public.destinations(id) on delete cascade,
  search_count bigint not null default 0 check (search_count >= 0),
  updated_at timestamptz not null default now()
);

alter table public.destination_search_stats enable row level security;

drop policy if exists "Anyone reads destination search stats"
  on public.destination_search_stats;
create policy "Anyone reads destination search stats"
  on public.destination_search_stats for select to anon, authenticated
  using (true);

grant select on public.destination_search_stats to anon, authenticated;
grant usage on schema public to anon, authenticated;

create or replace function public.record_destination_search(
  p_destination_id bigint
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_count bigint;
begin
  insert into public.destination_search_stats (
    destination_id,
    search_count,
    updated_at
  )
  select p_destination_id, 1, now()
  where exists (
    select 1 from public.destinations where id = p_destination_id
  )
  on conflict (destination_id) do update
  set search_count = public.destination_search_stats.search_count + 1,
      updated_at = now()
  returning search_count into updated_count;

  if updated_count is null then
    raise exception 'Destination not found';
  end if;

  return updated_count;
end;
$$;

revoke all on function public.record_destination_search(bigint) from public;
grant execute on function public.record_destination_search(bigint)
  to anon, authenticated;

notify pgrst, 'reload schema';
