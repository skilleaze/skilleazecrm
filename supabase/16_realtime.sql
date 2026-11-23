-- Skilleaze HQ · real-time sync for every module (run once, safe to re-run)

-- 1. Every synced table gets a change time, kept up to date automatically
create or replace function touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

do $$ declare t text; begin
  foreach t in array array['orders','order_experts','ad_days','transfers','expenses','customer_issues','hr_records','app_kv','expert_agents','profiles'] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table %I add column if not exists updated_at timestamptz not null default now();', t);
      execute format('drop trigger if exists trg_touch_%1$s on %1$s; create trigger trg_touch_%1$s before insert or update on %1$s for each row execute function touch_updated_at();', t);
    end if;
  end loop; end $$;

-- 2. Assigning / changing an expert also marks the order as changed,
--    so every portal picks up the new expert straight away
create or replace function touch_order_from_expert() returns trigger language plpgsql security definer set search_path = public as $$
begin
  update orders set updated_at = now() where id = coalesce(new.order_id, old.order_id);
  return coalesce(new, old);
end $$;
drop trigger if exists trg_touch_order_from_expert on order_experts;
create trigger trg_touch_order_from_expert after insert or update or delete on order_experts for each row execute function touch_order_from_expert();

-- 3. Deleted rows: remember them so other portals remove them too
create table if not exists deleted_rows (tbl text not null, id text not null, at timestamptz not null default now(), primary key (tbl, id));
alter table deleted_rows enable row level security;
drop policy if exists dr_read on deleted_rows;
create policy dr_read on deleted_rows for select using (auth.uid() is not null);
create or replace function remember_delete() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into deleted_rows (tbl, id) values (tg_table_name, old.id::text) on conflict (tbl, id) do update set at = now(); return old; end $$;
do $$ declare t text; begin
  foreach t in array array['orders','ad_days','transfers','expenses','customer_issues','hr_records'] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists trg_del_%1$s on %1$s; create trigger trg_del_%1$s after delete on %1$s for each row execute function remember_delete();', t);
    end if;
  end loop; end $$;

-- 4. Turn on live change signals for every synced table
do $$ declare t text; begin
  foreach t in array array['orders','order_experts','ad_days','transfers','expenses','customer_issues','hr_records','app_kv','expert_agents','profiles','deleted_rows'] loop
    if to_regclass('public.' || t) is not null and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table %I;', t);
    end if;
  end loop; end $$;

-- 5. Full row data on updates/deletes (lets the database check access per user)
do $$ declare t text; begin
  foreach t in array array['orders','order_experts','ad_days','transfers','expenses','customer_issues','hr_records','app_kv'] loop
    if to_regclass('public.' || t) is not null then execute format('alter table %I replica identity full;', t); end if;
  end loop; end $$;

select 'ok' as realtime_ready;
