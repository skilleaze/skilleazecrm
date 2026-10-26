-- Skilleaze HQ · Munavvir payment checks (both branches) + Marketing planner
-- SQL Editor → New query → paste → Run. It should end with "ok".

-- 1. Munavvir (Puttur manager) can see and confirm Cloud payments made to the UAE account or a gateway
drop policy if exists o_pmgr_pay_read on orders;
create policy o_pmgr_pay_read on orders for select using (
  (select is_pmgr()) and branch = 'cloud'
  and (coalesce(via, 'personal') <> 'personal' or coalesce(extra->>'balanceVia', 'personal') <> 'personal'));
drop policy if exists o_pmgr_pay_upd on orders;
create policy o_pmgr_pay_upd on orders for update using (
  (select is_pmgr()) and branch = 'cloud'
  and (coalesce(via, 'personal') <> 'personal' or coalesce(extra->>'balanceVia', 'personal') <> 'personal'))
  with check ((select is_pmgr()) and branch = 'cloud');

-- 2. Marketing plans: Cloud plan for management + Head of operations; Puttur plan also for Munavvir
drop policy if exists kv_read on app_kv;
create policy kv_read on app_kv for select using (
  auth.uid() is not null and (
    key not in ('salaryStatements','salaryStatementTotals','transferAcct','payroll','mktCloud','mktPuttur')
    or is_mgmt() or is_head() or (is_pmgr() and key in ('payroll','mktPuttur'))));

select 'ok';
