-- 37_head_ops_control.sql · 17 Nov 2026 · Head of operations: delete wrong orders/transfers, undo verifications. Safe to run again.
-- Everything dated up to 1 Nov 2026 stays locked to the accounts sheets (35_sheet_reconcile.sql).

-- 1. Orders: Head of operations can delete orders dated 2 Nov or later (every delete is still logged in order_delete_log)
drop policy if exists o_delete on orders;
create policy o_delete on orders for delete using (
  (select is_mgmt())
  or ((select is_head()) and date >= '2026-11-02' and not coalesce(summary, false))
  or (branch = 'puttur' and (select is_pmgr()))
  or (branch = 'cloud' and agent_code = (select my_agent()) and date >= '2026-11-02' and not coalesce(summary, false))
);

-- 2. Transfers: Head of operations can edit, undo and delete transfers dated 2 Nov or later
drop policy if exists t_verify on transfers;
create policy t_verify on transfers for update
  using ((select is_mgmt()) or ((select is_head()) and date >= '2026-11-02'))
  with check ((select is_mgmt()) or ((select is_head()) and date >= '2026-11-02'));
drop policy if exists t_delete on transfers;
create policy t_delete on transfers for delete using ((select is_mgmt()) or ((select is_head()) and date >= '2026-11-02'));

-- 3. Moving a transfer back to pending clears who verified it
create or replace function guard_transfers() returns trigger language plpgsql security definer as $$
begin
  if tg_op='INSERT' then
    new.created_by := auth.uid(); new.created_at := now();
    if is_mgmt() then new.status := coalesce(new.status, 'verified');
    elsif is_head() then new.status := 'verified'; new.verified_by := auth.uid(); new.verified_at := now();
    else new.status := 'pending'; new.verified_by := null; new.verified_at := null; end if;
    if my_agent() is not null then new.agent_code := my_agent(); end if;
  end if;
  if tg_op='UPDATE' and new.status <> old.status then
    if not (is_head() or is_mgmt()) then raise exception 'Only the Head of operations can verify transfers'; end if;
    if new.status = 'pending' then new.verified_by := null; new.verified_at := null;
    else new.verified_by := auth.uid(); new.verified_at := now(); end if;
  end if;
  return new;
end $$;

-- 4. Every deleted transfer is kept with who deleted it and when
create table if not exists transfer_delete_log (
  id text primary key, agent_code text, date date, amount numeric, status text,
  deleted_by text, deleted_at timestamptz not null default now(), full_row jsonb
);
alter table transfer_delete_log enable row level security;
drop policy if exists tdl_read on transfer_delete_log;
create policy tdl_read on transfer_delete_log for select using ((select is_mgmt()) or (select is_head()));
create or replace function log_transfer_delete() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into transfer_delete_log (id, agent_code, date, amount, status, deleted_by, full_row)
  values (old.id, old.agent_code, old.date, old.amount, old.status, coalesce((select username from profiles where id = auth.uid()), 'system'), to_jsonb(old))
  on conflict (id) do update set deleted_at = now(), deleted_by = excluded.deleted_by, full_row = excluded.full_row;
  return old;
end $$;
drop trigger if exists trg_log_transfer_delete on transfers;
create trigger trg_log_transfer_delete before delete on transfers for each row execute function log_transfer_delete();
drop trigger if exists trg_del_transfers on transfers;
create trigger trg_del_transfers after delete on transfers for each row execute function remember_delete();

select 'ok' as head_ops_control_ready;
