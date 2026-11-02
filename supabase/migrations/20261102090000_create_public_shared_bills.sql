-- One shared GM Tailors bill list. This table intentionally permits public
-- anonymous CRUD because the app has no sign-in and every install shares data.
-- Do not place service-role or secret API keys in the mobile app.
create table if not exists public.gm_shared_bills (
  id text primary key check (char_length(id) between 1 and 100),
  bill jsonb not null check (
    jsonb_typeof(bill) = 'object'
    and bill ? 'id'
    and bill->>'id' = id
  ),
  issued_at timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table public.gm_shared_bills enable row level security;

grant select, insert, update, delete on public.gm_shared_bills to anon;

drop policy if exists "Anyone can read shared bills" on public.gm_shared_bills;
create policy "Anyone can read shared bills"
  on public.gm_shared_bills for select to anon using (true);

drop policy if exists "Anyone can add shared bills" on public.gm_shared_bills;
create policy "Anyone can add shared bills"
  on public.gm_shared_bills for insert to anon
  with check (
    jsonb_typeof(bill) = 'object'
    and bill ? 'id'
    and bill->>'id' = id
  );

drop policy if exists "Anyone can update shared bills" on public.gm_shared_bills;
create policy "Anyone can update shared bills"
  on public.gm_shared_bills for update to anon
  using (true)
  with check (
    jsonb_typeof(bill) = 'object'
    and bill ? 'id'
    and bill->>'id' = id
  );

drop policy if exists "Anyone can delete shared bills" on public.gm_shared_bills;
create policy "Anyone can delete shared bills"
  on public.gm_shared_bills for delete to anon using (true);

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'gm_shared_bills'
  ) then
    alter publication supabase_realtime add table public.gm_shared_bills;
  end if;
end;
$$;
