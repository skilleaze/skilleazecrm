-- Skilleaze HQ · complaints: experts on the order can comment and resolve
drop policy if exists ci_upd on customer_issues;
create policy ci_upd on customer_issues for update using (
  is_mgmt() or is_ops() or is_pmgr() or created_by = auth.uid()
  or my_agent() = any(agents) or my_staff() = any(cses) or my_expert() = any(experts));
select 'ok';
