-- 50 · Experts can no longer overwrite who is assigned (found by the 23 Nov 2026 21:20 IST health check)
-- STATUS: NOT RUN YET. Written and checked by the 23 Nov 21:20 IST health check, but the Supabase connector
-- asked for an approval nobody was there to give, so it was neither tested nor applied. Test it in begin … rollback
-- (as an expert, an agent and management), then run it and move it to supabase/50_expert_keep_assignments.sql.
-- Safe to run more than once. Paste into Supabase → SQL Editor → Run.
--
-- What happened: an expert's app holding an old copy of an order kept re-sending it. As soon as
-- the agent assigned that expert to the order, the old copy went through and replaced the
-- assignment (ALPHA-1795272437380: agent ALPHA set CV = HAFSATH MUYEENA, LinkedIn = THOIBA;
-- twice the expert's app wrote it back to CV = THOIBA, LinkedIn = none).
--
-- Rule (experts only; management, operations, Puttur manager, agents and consultants unchanged):
--  * an expert may set a service's expert only to what the server already holds for it
--    (order_experts), to themself when the server already lists them (after Take new work),
--    or to empty when it is their own part (Give back);
--  * any other change to someone's assignment is refused with a clear message;
--  * the order's `expert` field (a copy of the CV expert) keeps its server value when an
--    expert's app tries to change it in a way the rule above does not allow;
--  * order_experts: an expert can no longer re-point their own row to another expert.
-- Server functions (claim_order, set_task_status, the sync triggers) are not affected.

create or replace function public.expert_keep_assign() returns trigger
language plpgsql security definer set search_path to 'public' as $fn$
declare me text; ow jsonb; nw jsonb; k text; o text; n text; srv text; mine boolean;
begin
  if pg_trigger_depth() > 1 then return new; end if;            -- inside server functions / sync triggers
  me := my_expert();
  if me is null then return new; end if;                         -- not an expert login (or SQL editor)
  me := upper(regexp_replace(trim(me), '\s+', ' ', 'g'));
  ow := case when jsonb_typeof(old.extra->'wx') = 'object' then old.extra->'wx' else '{}'::jsonb end;
  nw := case when jsonb_typeof(new.extra->'wx') = 'object' then new.extra->'wx' else '{}'::jsonb end;
  for k in select key from jsonb_each(ow) union select key from jsonb_each(nw) loop
    o := upper(regexp_replace(trim(coalesce(ow->>k, '')), '\s+', ' ', 'g'));
    n := upper(regexp_replace(trim(coalesce(nw->>k, '')), '\s+', ' ', 'g'));
    if o = n then continue; end if;
    select upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) into srv
      from order_experts where order_id = new.id and service_type = k;
    if n <> '' and n = coalesce(srv, '') then continue; end if;   -- matches the server
    if n = '' and o = me then continue; end if;                   -- giving back own part
    raise exception 'Experts can only change their own work, not who is assigned (order %, %)', new.id, k
      using errcode = '42501';
  end loop;
  o := upper(regexp_replace(trim(coalesce(old.extra->>'expert', '')), '\s+', ' ', 'g'));
  n := upper(regexp_replace(trim(coalesce(new.extra->>'expert', '')), '\s+', ' ', 'g'));
  if o <> n then
    select upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) into srv
      from order_experts where order_id = new.id and service_type = 'cv';
    mine := exists (select 1 from order_experts where order_id = new.id
                    and upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) = me);
    if not ((n <> '' and n = coalesce(srv, '')) or (n = '' and o = me) or (n = me and mine and coalesce(srv, me) = me)) then
      new.extra := jsonb_set(new.extra, '{expert}', coalesce(old.extra->'expert', to_jsonb(''::text)), true);
    end if;
  end if;
  return new;
end $fn$;

drop trigger if exists trg_expert_keep_assign on orders;
create trigger trg_expert_keep_assign before update on orders
  for each row when (old.extra is distinct from new.extra) execute function expert_keep_assign();

drop policy if exists oe_update on order_experts;
create policy oe_update on order_experts for update
  using ((select is_mgmt()) or (select is_ops()) or (select is_pmgr()) or expert_code = (select my_expert())
         or order_id = any (my_agent_order_ids()) or order_id = any (my_staff_order_ids()))
  with check ((select is_mgmt()) or (select is_ops()) or (select is_pmgr()) or expert_code = (select my_expert())
         or order_id = any (my_agent_order_ids()) or order_id = any (my_staff_order_ids()));
