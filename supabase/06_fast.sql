-- Skilleaze CRM · fix "statement timeout" on sign-in (run once)

-- 1. Give signed-in users more time per request (default is 8s)
alter role authenticated set statement_timeout = '60s';

-- 2. Check the user's role once per request, not once per row
drop policy if exists o_read on orders;
create policy o_read on orders for select using (
  (select is_mgmt()) or (select is_ops()) or can_see_order(orders));

drop policy if exists o_update on orders;
create policy o_update on orders for update
  using ((select is_mgmt()) or (select is_ops()) or can_see_order(orders))
  with check ((select is_mgmt()) or (select is_ops()) or can_see_order(orders));

drop policy if exists oe_read on order_experts;
create policy oe_read on order_experts for select using (
  (select is_mgmt()) or (select is_ops())
  or exists(select 1 from orders o where o.id = order_id and can_see_order(o)));

drop policy if exists a_read on ad_days;
create policy a_read on ad_days for select using ((select is_mgmt()) or (select is_head()) or agent_code = (select my_agent()));

drop policy if exists t_read on transfers;
create policy t_read on transfers for select using ((select is_mgmt()) or (select is_head()) or agent_code = (select my_agent()));

-- 3. Indexes for the page-by-page download
create index if not exists orders_id_idx on orders(id);
create index if not exists order_experts_order on order_experts(order_id);
create index if not exists expert_agents_agent on expert_agents(agent_code, expert_code);

notify pgrst, 'reload config';
select 'ok' as done;
