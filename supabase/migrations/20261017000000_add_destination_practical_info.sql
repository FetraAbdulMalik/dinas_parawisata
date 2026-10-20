alter table public.destinations
  add column if not exists opening_hours text not null default '',
  add column if not exists ticket_price text not null default '',
  add column if not exists facilities text not null default '',
  add column if not exists contact text not null default '',
  add column if not exists practical_info_updated_at timestamptz;
