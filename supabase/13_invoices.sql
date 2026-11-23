-- Skilleaze HQ · Invoices (run once)
-- Everyone signed in can save their own invoices; management, Head of operations and the Puttur manager can see and edit all.
drop policy if exists kv_read on app_kv;
create policy kv_read on app_kv for select using (
  auth.uid() is not null and (
    (key not like 'inv\_%' and (key not in ('salaryStatements','salaryStatementTotals','transferAcct','payroll','mktCloud','mktPuttur')
      or is_mgmt() or is_head() or (is_pmgr() and key in ('payroll','mktPuttur'))))
    or (key like 'inv\_%' and (key = 'inv_' || auth.uid()::text or is_mgmt() or is_head() or is_pmgr()))));

drop policy if exists kv_write on app_kv;
create policy kv_write on app_kv for all
  using (is_mgmt() or is_ops() or is_pmgr()
         or (key = 'puttur' and my_staff() is not null)
         or (key = 'issueSeen' and auth.uid() is not null)
         or (key = 'inv_' || auth.uid()::text))
  with check (is_mgmt() or is_ops() or is_pmgr()
         or (key = 'puttur' and my_staff() is not null)
         or (key = 'issueSeen' and auth.uid() is not null)
         or (key = 'inv_' || auth.uid()::text));

-- Puttur manager can assign / change experts on Puttur orders
drop policy if exists oe_write on order_experts;
create policy oe_write on order_experts for all using (is_mgmt() or is_ops()
    or exists(select 1 from orders o where o.id = order_id and (o.agent_code = my_agent() or o.cse_id = my_staff() or (o.branch = 'puttur' and is_pmgr())))
    or expert_code = my_expert())
  with check (is_mgmt() or is_ops()
    or exists(select 1 from orders o where o.id = order_id and (o.agent_code = my_agent() or o.cse_id = my_staff() or (o.branch = 'puttur' and is_pmgr())))
    or expert_code = my_expert());

select 'ok' as invoices_ready;
