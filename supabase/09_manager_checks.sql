-- Skilleaze HQ · Munavvir sees Cloud payment checks (safe to run again)
-- SQL Editor → New query → paste → Run.

drop policy if exists o_pmgr_pay_read on orders;
create policy o_pmgr_pay_read on orders for select using (
  (select is_pmgr()) and branch = 'cloud'
  and (coalesce(via, 'personal') <> 'personal' or coalesce(extra->>'balanceVia', 'personal') <> 'personal'));

drop policy if exists o_pmgr_pay_upd on orders;
create policy o_pmgr_pay_upd on orders for update using (
  (select is_pmgr()) and branch = 'cloud'
  and (coalesce(via, 'personal') <> 'personal' or coalesce(extra->>'balanceVia', 'personal') <> 'personal'))
  with check ((select is_pmgr()) and branch = 'cloud');

-- Munavvir's account must be a Puttur manager for this to apply
update profiles set role = 'manager', active = true where username = 'muhammed.munavvir';

-- Shows: Munavvir's role, and how many Cloud payments he should now see
select (select role::text from profiles where username = 'muhammed.munavvir') as munavvir_role,
       count(*) as cloud_payments_for_checks
from orders
where branch = 'cloud'
  and (coalesce(via, 'personal') <> 'personal' or coalesce(extra->>'balanceVia', 'personal') <> 'personal');
