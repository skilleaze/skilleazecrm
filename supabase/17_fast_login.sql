-- Skilleaze HQ · fast loading for agents, experts and consultants
-- Fixes: agents/experts stuck at "Loading orders… 99%" after signing in.
-- SQL Editor → New query → paste → Run   (expect: ok)

alter role authenticated set statement_timeout = '60s';

create or replace function my_expert_agents() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(agent_code), '{}') from expert_agents where expert_code = (select expert_code from profiles where id = auth.uid() and active)
$$;
create or replace function my_assigned_orders() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(order_id), '{}') from order_experts where expert_code = (select expert_code from profiles where id = auth.uid() and active)
$$;

create index if not exists orders_agent_id on orders(agent_code, id);
create index if not exists orders_cse_id_idx on orders(cse_id, id);
create index if not exists orders_branch_id on orders(branch, id);
create index if not exists order_experts_order on order_experts(order_id);
create index if not exists order_experts_expert on order_experts(expert_code);

-- One quick check per request, not a slow function per row
drop policy if exists o_read on orders;
create policy o_read on orders for select using (
  (select is_mgmt()) or (select is_ops())
  or (branch = 'puttur' and ((select is_pmgr()) or cse_id = (select my_staff())))
  or (branch = 'cloud' and agent_code = (select my_agent()))
  or ((select my_expert()) is not null and (
        id = any((select my_assigned_orders()))
     or ((agent_code = any((select my_expert_agents())) or ('P:' || coalesce(cse_id, '')) = any((select my_expert_agents())))
         and not exists (select 1 from order_experts e where e.order_id = orders.id)))));

drop policy if exists o_update on orders;
create policy o_update on orders for update
  using (
  (select is_mgmt()) or (select is_ops())
  or (branch = 'puttur' and ((select is_pmgr()) or cse_id = (select my_staff())))
  or (branch = 'cloud' and agent_code = (select my_agent()))
  or ((select my_expert()) is not null and (
        id = any((select my_assigned_orders()))
     or ((agent_code = any((select my_expert_agents())) or ('P:' || coalesce(cse_id, '')) = any((select my_expert_agents())))
         and not exists (select 1 from order_experts e where e.order_id = orders.id)))))
  with check (true);

drop policy if exists oe_read on order_experts;
create policy oe_read on order_experts for select using (
  (select is_mgmt()) or (select is_ops()) or (select is_pmgr())
  or expert_code = (select my_expert())
  or order_id in (select id from orders where agent_code = (select my_agent()))
  or order_id in (select id from orders where cse_id = (select my_staff())));

analyze orders; analyze order_experts;
select 'ok' as fast_loading_ready;
