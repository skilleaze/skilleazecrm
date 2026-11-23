-- Skilleaze HQ · complaints and orders from agents/consultants never rejected again (run once, safe to run again)

-- 1. Complaints: stamp who reported it, so the reporter can save it and keep commenting
create or replace function ci_stamp_owner() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.created_by is null then new.created_by := auth.uid(); end if;
  return new;
end $$;
drop trigger if exists trg_ci_stamp_owner on customer_issues;
create trigger trg_ci_stamp_owner before insert on customer_issues for each row execute function ci_stamp_owner();

drop policy if exists ci_read on customer_issues;
create policy ci_read on customer_issues for select using (
  auth.uid() is not null and (
    (select is_mgmt()) or (select is_ops()) or (select is_pmgr()) or created_by = auth.uid() or created_by is null
    or (select my_agent()) = any(agents) or (select my_expert()) = any(experts) or (select my_staff()) = any(cses)));

drop policy if exists ci_upd on customer_issues;
create policy ci_upd on customer_issues for update using (
  (select is_mgmt()) or (select is_ops()) or (select is_pmgr()) or created_by = auth.uid() or created_by is null
  or (select my_agent()) = any(agents) or (select my_staff()) = any(cses) or (select my_expert()) = any(experts))
  with check (true);

-- 2. Orders: an agent's / consultant's own order is always filed under their own code
create or replace function stamp_order_owner() returns trigger language plpgsql security definer set search_path = public as $$
declare a text := (select my_agent()); s text := (select my_staff());
begin
  if a is not null and coalesce(new.branch, 'cloud') = 'cloud' then new.agent_code := a; end if;
  if s is not null and new.branch = 'puttur' then new.cse_id := s; end if;
  return new;
end $$;
drop trigger if exists trg_stamp_order_owner on orders;
create trigger trg_stamp_order_owner before insert on orders for each row execute function stamp_order_owner();

-- 3. Check: consultants whose login is not linked to their staff record (orders would fail for them)
select p.username, p.full_name, p.staff_id,
       case when p.staff_id is null or p.staff_id = '' then 'NOT LINKED' else 'ok' end as link
from profiles p where p.role = 'cse' and p.active order by link desc, p.full_name;
