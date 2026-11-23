-- 48 · Open services of combined orders reach the right experts' "Take new work"
-- Safe to run more than once. Paste into Supabase → SQL Editor → Run.
--
-- Before: an expert could only see their agents' orders that had NO expert at all
-- (order_has_expert). On a CV + LinkedIn order, once the CV expert was set, the LinkedIn
-- part was invisible to every LinkedIn expert, so nobody could pick it up.
-- After: experts also see their agents' open orders (from 1 Nov 2026) that still have a
-- service with no expert and not started. Reading only: updating still needs the expert
-- to be assigned (claim_order assigns them). On 23 Nov 2026 this unlocked 62 LinkedIn,
-- 10 job-portal, 7 portfolio and 12 CV services.

-- service name → work type (same mapping as svcType() in the app)
create or replace function public.svc_type(s text) returns text
language sql immutable set search_path to 'public' as $fn$
  select case
    when s = 'INTERVIEW TRAINING SESSION' then 'interview'
    when s = 'LINKEDIN OPTIMIZATION' then 'linkedin'
    when s = 'PORTFOLIO WEBSITE' then 'portfolio'
    when s in ('JOB PORTAL OPTIMISATION', 'NAUKRI OPTIMISATION', 'INDEED OPTIMISATION') then 'jobportal'
    else 'cv' end
$fn$;

-- true when the order has a service nobody holds yet and that has not started
create or replace function public.order_open_task(oid text) returns boolean
language sql stable security definer set search_path to 'public' as $fn$
  select exists (
    select 1
    from orders o cross join lateral unnest(coalesce(o.services, '{}'::text[])) s
    where o.id = oid
      and o.status <> 'CLOSED' and coalesce(o.pay_status, '') <> 'REFUNDED'
      and not coalesce(o.summary, false) and o.date >= '2026-11-01'
      and not exists (select 1 from order_experts oe where oe.order_id = o.id and oe.service_type = svc_type(s))
      and coalesce(o.extra->'tst'->>svc_type(s), 'PENDING') = 'PENDING')
$fn$;

grant execute on function public.svc_type(text) to authenticated;
grant execute on function public.order_open_task(text) to authenticated;

-- o_read: same as before, plus "or the order still has an open service".
-- The expert's lists are now worked out once per request instead of once per row
-- ((select …)::text[]): an expert's full order load went from ~13 s to ~2 s in the database.
alter policy o_read on public.orders using (
  (select is_mgmt()) or (select is_ops())
  or (branch = 'puttur' and ((select is_pmgr()) or cse_id = (select my_staff())))
  or (branch = 'cloud' and agent_code = (select my_agent()))
  or ((select my_expert()) is not null and (
        id = any (((select my_assigned_orders()))::text[])
        or ((agent_code = any (((select my_expert_agents()))::text[]) or ('P:' || coalesce(cse_id, '')) = any (((select my_expert_agents()))::text[]))
            and (not order_has_expert(id) or order_open_task(id)))))
);

-- o_update: who may update is UNCHANGED (no open-service clause); only the same speed-up.
alter policy o_update on public.orders using (
  (select is_mgmt()) or (select is_ops())
  or (branch = 'puttur' and ((select is_pmgr()) or cse_id = (select my_staff())))
  or (branch = 'cloud' and agent_code = (select my_agent()))
  or ((select my_expert()) is not null and (
        id = any (((select my_assigned_orders()))::text[])
        or ((agent_code = any (((select my_expert_agents()))::text[]) or ('P:' || coalesce(cse_id, '')) = any (((select my_expert_agents()))::text[]))
            and not order_has_expert(id))))
) with check (true);
