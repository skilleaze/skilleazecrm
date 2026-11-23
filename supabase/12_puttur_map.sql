-- Skilleaze HQ · let the Puttur manager link experts to career consultants (run once)
drop policy if exists w_map on expert_agents;
create policy w_map on expert_agents for all
  using (is_mgmt() or is_ops() or is_pmgr())
  with check (is_mgmt() or is_ops() or is_pmgr());
select 'ok' as puttur_map_ready;
