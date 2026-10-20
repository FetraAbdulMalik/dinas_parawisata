alter table public.destinations
  add column if not exists no_sk_bupati text not null default '';

notify pgrst, 'reload schema';
