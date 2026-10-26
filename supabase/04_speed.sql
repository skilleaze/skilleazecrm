-- =====================================================================
-- Skilleaze CRM · step 4 · speed up loading (fixes "statement timeout")
-- SQL Editor → New query → paste → Run   (expect: ok)
-- =====================================================================

-- More time per request for signed-in users
alter role authenticated set statement_timeout = '60s';

-- Who am I, worked out once per request instead of once per row
create or replace function my_ctx() returns table(role app_role, scope text, agent text, expert text, staff text)
language sql stable security definer set search_path = public as $$
  select p.role, p.ops_scope, p.agent_code, p.expert_code, p.staff_id from profiles p where p.id = auth.uid() and p.active
$$;

create or replace function my_expert_agents() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(agent_code), '{}') from expert_agents where expert_code = (select expert_code from profiles where id = auth.uid() and active)
$$;

create or replace function my_assigned_orders() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(order_id), '{}') from order_experts where expert_code = (select expert_code from profiles where id = auth.uid() and active)
$$;

create or replace function orders_with_expert() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(distinct order_id), '{}') from order_experts
  where (select role from profiles where id = auth.uid()) = 'expert'
$$;

-- ---------- orders ----------
drop policy if exists o_read on orders;
create policy o_read on orders for select using (
  (select is_mgmt()) or (select is_ops())
  or (branch = 'puttur' and ((select is_pmgr()) or cse_id = (select my_staff())))
  or (branch = 'cloud' and agent_code = (select my_agent()))
  or ((select my_expert()) is not null and (
        id = any((select my_assigned_orders()))
     or (agent_code = any((select my_expert_agents())) and not (id = any((select orders_with_expert())))))));

drop policy if exists o_update on orders;
create policy o_update on orders for update using (
  (select is_mgmt()) or (select is_ops())
  or (branch = 'puttur' and ((select is_pmgr()) or cse_id = (select my_staff())))
  or (branch = 'cloud' and agent_code = (select my_agent()))
  or ((select my_expert()) is not null and (id = any((select my_assigned_orders())) or agent_code = any((select my_expert_agents())))));

-- ---------- order_experts ----------
drop policy if exists oe_read on order_experts;
create policy oe_read on order_experts for select using (
  (select is_mgmt()) or (select is_ops()) or (select is_pmgr())
  or expert_code = (select my_expert())
  or order_id in (select id from orders where agent_code = (select my_agent()) or cse_id = (select my_staff())));

-- ---------- ads / transfers / expenses ----------
drop policy if exists a_read on ad_days;
create policy a_read on ad_days for select using ((select is_mgmt()) or (select is_head()) or agent_code = (select my_agent()));
drop policy if exists t_read on transfers;
create policy t_read on transfers for select using ((select is_mgmt()) or (select is_head()) or agent_code = (select my_agent()));
drop policy if exists e_cloud on expenses;
create policy e_cloud on expenses for all using (branch = 'cloud' and ((select is_mgmt()) or (select is_head()))) with check (branch = 'cloud' and ((select is_mgmt()) or (select is_head())));
drop policy if exists e_puttur on expenses;
create policy e_puttur on expenses for all using (branch = 'puttur' and ((select is_mgmt()) or (select is_pmgr()))) with check (branch = 'puttur' and ((select is_mgmt()) or (select is_pmgr())));

-- ---------- customer issues ----------
drop policy if exists ci_read on customer_issues;
create policy ci_read on customer_issues for select using (
  (select is_mgmt()) or (select is_ops()) or (select is_pmgr()) or created_by = auth.uid()
  or (select my_agent()) = any(agents) or (select my_expert()) = any(experts) or (select my_staff()) = any(cses));

-- ---------- indexes ----------
create index if not exists orders_agent on orders(agent_code);
create index if not exists orders_cse on orders(cse_id);
create index if not exists order_experts_order on order_experts(order_id);
create index if not exists expert_agents_expert on expert_agents(expert_code);
create index if not exists profiles_id_active on profiles(id) where active;

analyze orders; analyze order_experts; analyze transfers; analyze ad_days; analyze expenses;

select 'ok' as step4;
