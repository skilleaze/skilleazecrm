-- Skilleaze HQ · Puttur enquiries: one saved row per enquiry (run once, safe to run again)

-- 1. Remove links that rejected saves (consultants and orders live elsewhere)
alter table enquiries drop constraint if exists enquiries_cse_id_fkey;
alter table enquiries drop constraint if exists enquiries_order_id_fkey;
alter table enquiries alter column name drop not null;
alter table enquiries alter column phone drop not null;
alter table enquiries add column if not exists extra jsonb not null default '{}';
alter table enquiries add column if not exists updated_at timestamptz not null default now();
create index if not exists enquiries_cse on enquiries(cse_id);
create index if not exists enquiries_updated on enquiries(updated_at);

-- 2. Recover every enquiry already saved in the shared Puttur record
insert into enquiries (id, cse_id, name, phone, status, source, extra)
select e->>'id', coalesce(e->>'bde', e->>'cse'), coalesce(e->>'name', ''), coalesce(e->>'phone', ''), coalesce(e->>'status', 'NEW'), e->>'source', e
from app_kv, jsonb_array_elements(coalesce(value->'enquiries', '[]'::jsonb)) e
where key = 'puttur' and e ? 'id'
on conflict (id) do nothing;

-- 3. Who can see and change enquiries
do $$ declare r record; begin
  for r in select policyname from pg_policies where schemaname = 'public' and tablename = 'enquiries' loop
    execute format('drop policy if exists %I on enquiries', r.policyname);
  end loop; end $$;
alter table enquiries enable row level security;
create policy enq_read on enquiries for select using (
  (select is_mgmt()) or (select is_ops()) or (select is_pmgr()) or cse_id = (select my_staff()));
create policy enq_insert on enquiries for insert with check (
  (select is_mgmt()) or (select is_pmgr()) or cse_id = (select my_staff()));
create policy enq_update on enquiries for update using (
  (select is_mgmt()) or (select is_pmgr()) or cse_id = (select my_staff())) with check (true);
create policy enq_delete on enquiries for delete using (
  (select is_mgmt()) or (select is_pmgr()) or cse_id = (select my_staff()));

-- 4. Live updates, last-changed time and deletions for every portal
create or replace function touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists trg_touch_enquiries on enquiries;
create trigger trg_touch_enquiries before insert or update on enquiries for each row execute function touch_updated_at();

create table if not exists deleted_rows (tbl text not null, id text not null, at timestamptz not null default now(), primary key (tbl, id));
create or replace function remember_delete() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into deleted_rows (tbl, id) values (tg_table_name, old.id::text) on conflict (tbl, id) do update set at = now(); return old; end $$;
drop trigger if exists trg_del_enquiries on enquiries;
create trigger trg_del_enquiries after delete on enquiries for each row execute function remember_delete();

alter table enquiries replica identity full;
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'enquiries') then
    alter publication supabase_realtime add table enquiries;
  end if; end $$;

-- 5. Check: each consultant login, the staff id it uses, and how many enquiries belong to it
select p.username, p.full_name, p.staff_id, p.active,
       (select count(*) from enquiries q where q.cse_id = p.staff_id) as enquiries
from profiles p where p.role = 'cse'
order by p.full_name;
