-- 49 · Stop endless refused saves (found by the 23 Nov 2026 health sweep)
-- Safe to run more than once. Paste into Supabase → SQL Editor → Run.
--
-- 1. HR: a person's own punch / leave / fix / profile / seen record is always filed under
--    that login's own key (profiles.person_key). Apps that built the key from an old or
--    renamed name (e.g. haseena → SAUDATH HASEENA) had every punch refused since 5 Nov
--    (17,699 refused saves). HR admins (management, head of operations, Puttur manager)
--    are untouched, and nobody can write anyone else's records (policies unchanged).
-- 2. claim_order: the order's `expert` field is the CV expert only when it is not just a
--    copy of another service's expert (same rule as sync_order_experts in 47). Before, an
--    expert taking the open CV part of a CV + LinkedIn order was told "Already taken by
--    <LinkedIn expert>" and their app retried an impossible save forever (MUNEEBA).

-- 1 ── HR records: own records always use the login's own key ─────────────────────────────
create or replace function public.hr_own_key() returns trigger
language plpgsql security definer set search_path to 'public' as $fn$
declare k text;
begin
  if auth.uid() is null or hr_admin(coalesce(new.branch, 'all')) then return new; end if;
  if new.kind in ('punch', 'leave', 'fix', 'profile', 'seen') then
    select person_key into k from profiles where id = auth.uid() and active;
    if coalesce(k, '') <> '' then
      new.person_key := k;
      if new.extra is not null and jsonb_typeof(new.extra) = 'object' and (new.extra->'key') is not null then
        new.extra := jsonb_set(new.extra, '{key}', to_jsonb(k));
      end if;
    end if;
    new.user_id := auth.uid();
  end if;
  return new;
end $fn$;

drop trigger if exists trg_hr_own_key on public.hr_records;
create trigger trg_hr_own_key before insert on public.hr_records
  for each row execute function public.hr_own_key();

-- 2 ── claim_order: don't mistake a copied LinkedIn/portfolio expert for the CV expert ───────
create or replace function public.claim_order(p_id text, p_type text default 'cv')
returns text language plpgsql security definer set search_path to 'public' as $fn$
declare me text := my_expert(); cur text; ex jsonb; copied boolean;
begin
  if me is null then raise exception 'Only experts can pick up orders'; end if;
  perform 1 from orders where id = p_id for update;
  if not found then raise exception 'Order not found'; end if;
  if not exists (select 1 from orders o where o.id = p_id and (o.agent_code = any(my_expert_agents()) or ('P:' || coalesce(o.cse_id, '')) = any(my_expert_agents()))) then
    raise exception 'This order is not from one of your agents';
  end if;
  select expert_code into cur from order_experts where order_id = p_id and service_type = p_type;
  if coalesce(cur, '') = '' then
    select extra into ex from orders where id = p_id;
    cur := nullif(trim(coalesce(ex->'wx'->>p_type, '')), '');
    if cur is null and p_type = 'cv' and (ex->'wx'->'cv') is null and coalesce(trim(ex->>'expert'), '') <> '' then
      copied := exists (select 1 from jsonb_each_text(case when jsonb_typeof(ex->'wx') = 'object' then ex->'wx' else '{}'::jsonb end) w
                        where w.key <> 'cv' and upper(regexp_replace(trim(w.value), '\s+', ' ', 'g')) = upper(regexp_replace(trim(ex->>'expert'), '\s+', ' ', 'g')));
      if not copied then cur := ex->>'expert'; end if;
    end if;
  end if;
  if coalesce(cur, '') <> '' then return cur; end if;
  insert into order_experts (order_id, service_type, expert_code) values (p_id, p_type, me)
    on conflict (order_id, service_type) do nothing;
  select expert_code into cur from order_experts where order_id = p_id and service_type = p_type;
  return cur;
end $fn$;
