-- Skilleaze HQ · sales agents can delete their own orders (from 2 Nov); every delete is logged with who, when and why. Safe to run again.

drop policy if exists o_delete on orders;
create policy o_delete on orders for delete using (
  (select is_mgmt())
  or (branch = 'puttur' and (select is_pmgr()))
  or (branch = 'cloud' and agent_code = (select my_agent()) and date >= '2026-11-02' and not coalesce(summary, false))
);

create table if not exists order_delete_log (
  id         text primary key,
  agent_code text,
  cse_id     text,
  name       text,
  phone      text,
  price      numeric,
  order_date date,
  status     text,
  deleted_by text,
  deleted_at timestamptz not null default now(),
  full_order jsonb
);
alter table order_delete_log enable row level security;
drop policy if exists odl_read on order_delete_log;
create policy odl_read on order_delete_log for select using ((select is_mgmt()) or (select is_head()));

create or replace function log_order_delete() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into order_delete_log (id, agent_code, cse_id, name, phone, price, order_date, status, deleted_by, full_order)
  values (old.id, old.agent_code, old.cse_id, old.name, old.phone, old.price, old.date, old.status,
          coalesce((select username from profiles where id = auth.uid()), 'system'), to_jsonb(old))
  on conflict (id) do update set deleted_at = now(), deleted_by = excluded.deleted_by, full_order = excluded.full_order;
  return old;
end $$;
drop trigger if exists trg_log_order_delete on orders;
create trigger trg_log_order_delete before delete on orders for each row execute function log_order_delete();

select 'ok' as agent_delete_ready;
