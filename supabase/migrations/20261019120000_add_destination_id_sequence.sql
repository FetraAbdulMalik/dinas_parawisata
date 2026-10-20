create sequence if not exists public.destinations_id_seq;

select setval(
  'public.destinations_id_seq',
  greatest(coalesce((select max(id) + 1 from public.destinations), 1), 1000000),
  false
);

alter table public.destinations
  alter column id
  set default nextval('public.destinations_id_seq'::regclass);

alter sequence public.destinations_id_seq
  owned by public.destinations.id;

grant usage, select on sequence public.destinations_id_seq to authenticated;
