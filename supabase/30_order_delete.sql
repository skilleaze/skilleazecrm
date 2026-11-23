-- Skilleaze HQ · managers can delete orders; every device drops them; full copy kept in the audit log. Safe to run again.
drop policy if exists o_delete on orders;
create policy o_delete on orders for delete using ((select is_mgmt()) or (branch = 'puttur' and (select is_pmgr())));

create table if not exists deleted_rows (tbl text not null, id text not null, at timestamptz not null default now(), primary key (tbl, id));
create or replace function remember_delete() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into deleted_rows (tbl, id) values (tg_table_name, old.id::text) on conflict (tbl, id) do update set at = now(); return old; end $$;
drop trigger if exists trg_del_orders on orders;
create trigger trg_del_orders after delete on orders for each row execute function remember_delete();

select 'ok' as order_delete_ready;
