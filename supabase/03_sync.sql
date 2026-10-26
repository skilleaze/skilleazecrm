-- =====================================================================
-- Skilleaze CRM · step 3 (run once, after 02_live.sql)
-- Lets the CRM save every screen straight into Supabase.
-- =====================================================================

-- 1. Codes come from the CRM itself, so drop links to lookup tables
alter table orders        drop constraint if exists orders_agent_code_fkey;
alter table orders        drop constraint if exists orders_cse_id_fkey;
alter table order_experts drop constraint if exists order_experts_expert_code_fkey;
alter table ad_days       drop constraint if exists ad_days_agent_code_fkey;
alter table ad_days       drop constraint if exists ad_days_agent_code_date_summary_key;
alter table transfers     drop constraint if exists transfers_agent_code_fkey;
alter table transfers     drop constraint if exists transfers_account_code_fkey;
alter table expenses      drop constraint if exists expenses_paid_by_fkey;
alter table expenses      drop constraint if exists expenses_amount_check;
alter table expert_agents drop constraint if exists expert_agents_expert_code_fkey;
alter table expert_agents drop constraint if exists expert_agents_agent_code_fkey;
alter table expert_skills drop constraint if exists expert_skills_expert_code_fkey;
alter table enquiries     drop constraint if exists enquiries_cse_id_fkey;
alter table enquiries     drop constraint if exists enquiries_order_id_fkey;
alter table orders        drop constraint if exists orders_source_check;
alter table orders        drop constraint if exists orders_via_check;

-- 2. Order rules (India time; Head of operations may change status)
create or replace function guard_orders() returns trigger language plpgsql security definer as $$
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
  end if;
  if tg_op='INSERT' then
    new.created_at := now();
    new.created_by := auth.uid();
    if not is_mgmt() then new.date := (now() at time zone 'Asia/Kolkata')::date; end if;
  end if;
  return new;
end $$;

-- 3. Transfer rules (management or Head of operations verify)
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
    new.verified_by := auth.uid(); new.verified_at := now();
  end if;
  return new;
end $$;

-- 4. Experts can add comments to customer issues they are tagged on
drop policy if exists ci_upd on customer_issues;
create policy ci_upd on customer_issues for update using (
  is_mgmt() or is_ops() or is_pmgr() or created_by = auth.uid()
  or my_agent() = any(agents) or my_staff() = any(cses) or my_expert() = any(experts));

-- 5. Customer Support Executives save Puttur enquiries; anyone signed in can mark issues seen
drop policy if exists kv_write on app_kv;
create policy kv_write on app_kv for all
  using (is_mgmt() or is_ops() or is_pmgr() or (my_staff() is not null and key = 'puttur') or key = 'issueSeen')
  with check (is_mgmt() or is_ops() or is_pmgr() or (my_staff() is not null and key = 'puttur') or key = 'issueSeen');

-- 6. Agents may not read the agent master or each other's deals
drop policy if exists kv_read on app_kv;
create policy kv_read on app_kv for select using (
  auth.uid() is not null and (
    key not in ('salaryStatements','salaryStatementTotals','transferAcct','payroll')
    or is_mgmt() or is_head() or (is_pmgr() and key = 'payroll')));

-- 7. Faster lists
create index if not exists ad_days_agent_date on ad_days(agent_code, date);
create index if not exists expenses_date on expenses(date);

select 'ok' as step3;
