-- Skilleaze HQ v3 · payment proof "Needs changes" status, delete reasons, restore. Safe to run again.

-- 1. Who may set a payment-proof status (confirmed / rejected / changes) on an order.
create or replace function can_check_payments() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_mgmt()), false) or coalesce((select is_head()), false)
      or coalesce((select is_ops()), false) or coalesce((select is_pmgr()), false)
$$;

-- 2. Order rules (same as 03_sync.sql) + only checkers may confirm / reject / send back a payment.
--    The agent's "Update payment" keeps the status at 'changes', so it is allowed.
create or replace function guard_orders() returns trigger language plpgsql security definer set search_path = public as $$
declare ps text; pb text;
begin
  if tg_op='UPDATE' then
    if old.summary and not is_mgmt() then raise exception 'Sheet adjustment lines are read-only'; end if;
    if is_ops() and not is_head() and (new.status <> old.status or new.price <> old.price or new.paid <> old.paid or new.pay_status <> old.pay_status) then
      raise exception 'Operations can assign experts but cannot change order status or money';
    end if;
    if my_expert() is not null and (new.price <> old.price or new.paid <> old.paid or new.pay_status <> old.pay_status
        or new.agent_code is distinct from old.agent_code or new.name is distinct from old.name or new.phone is distinct from old.phone) then
      raise exception 'Experts can only update work status';
    end if;
    if not is_mgmt() and new.date <> old.date then raise exception 'Order date cannot be changed'; end if;
    ps := new.extra->>'proofStatus'; pb := new.extra->>'balanceProofStatus';
    if not can_check_payments() and (
         (ps is distinct from (old.extra->>'proofStatus') and ps in ('confirmed', 'rejected', 'changes'))
      or (pb is distinct from (old.extra->>'balanceProofStatus') and pb in ('confirmed', 'rejected', 'changes'))) then
      raise exception 'Only management, operations or the Puttur manager can check payments';
    end if;
  end if;
  if tg_op='INSERT' then
    new.created_at := now();
    new.created_by := auth.uid();
    if not is_mgmt() then new.date := (now() at time zone 'Asia/Kolkata')::date; end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_guard_orders on orders;
create trigger trg_guard_orders before insert or update on orders for each row execute function guard_orders();

-- 3. Keep proof history: every status / note change is written to activity_log with who and when.
create or replace function log_proof_change() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(old.extra->>'proofStatus', '') is distinct from coalesce(new.extra->>'proofStatus', '')
     or coalesce(old.extra->>'proofNote', '') is distinct from coalesce(new.extra->>'proofNote', '')
     or coalesce(old.extra->>'proofUpd', '') is distinct from coalesce(new.extra->>'proofUpd', '')
     or coalesce(old.extra->>'balanceProofStatus', '') is distinct from coalesce(new.extra->>'balanceProofStatus', '')
     or coalesce(old.extra->>'balanceProofUpd', '') is distinct from coalesce(new.extra->>'balanceProofUpd', '') then
    insert into activity_log (table_name, row_id, action, old_data, new_data, user_id)
    values ('orders', new.id, 'PROOF',
            jsonb_build_object('status', old.extra->>'proofStatus', 'note', old.extra->>'proofNote', 'balance', old.extra->>'balanceProofStatus'),
            jsonb_build_object('status', new.extra->>'proofStatus', 'reason', new.extra->>'proofReason', 'note', new.extra->>'proofNote',
                               'updated', new.extra->>'proofUpd', 'balance', new.extra->>'balanceProofStatus'), auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists trg_log_proof_change on orders;
create trigger trg_log_proof_change after update on orders for each row execute function log_proof_change();

-- 4. Delete reasons in the deletion log.
alter table order_delete_log add column if not exists reason text;
alter table order_delete_log add column if not exists restored_at timestamptz;
create or replace function log_order_delete() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into order_delete_log (id, agent_code, cse_id, name, phone, price, order_date, status, deleted_by, full_order, reason)
  values (old.id, old.agent_code, old.cse_id, old.name, old.phone, old.price, old.date, old.status,
          coalesce((select username from profiles where id = auth.uid()), 'system'), to_jsonb(old), old.extra->>'deleteReason')
  on conflict (id) do update set deleted_at = now(), deleted_by = excluded.deleted_by, full_order = excluded.full_order, reason = excluded.reason, restored_at = null;
  return old;
end $$;

-- 5. Restore: when a deleted order comes back, other devices must stop removing it.
create or replace function order_restored() returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from deleted_rows where tbl = 'orders' and id = new.id::text;
  update order_delete_log set restored_at = now() where id = new.id;
  return new;
end $$;
drop trigger if exists trg_order_restored on orders;
create trigger trg_order_restored after insert on orders for each row execute function order_restored();

select 'ok' as v3_payment_changes_ready;
